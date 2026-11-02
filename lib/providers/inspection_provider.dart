import 'package:flutter/foundation.dart';

import '../models/inspection_data.dart';
import '../utils/obd_commands.dart';
import 'obd_provider.dart';

/// Runs the one-shot inspection checks: VIN, adapter battery voltage,
/// readiness monitors and freeze frame.
///
/// Each check runs independently, so a car that doesn't support one of
/// them (common on older cars) still gets results for the others.
class InspectionProvider extends ChangeNotifier {
  final OBDProvider _obd;

  InspectionProvider(this._obd);

  String? _vin;
  double? _voltage;
  ReadinessStatus? _readiness;
  FreezeFrame? _freezeFrame;
  bool _freezeFrameChecked = false;
  bool _running = false;
  String _step = '';
  String? _lastError;
  DateTime? _lastRun;

  // Mileage check data.
  double? _ecuOdometerKm;
  double? _distanceSinceClearedKm;
  double? _distanceWithMilKm;
  int? _permanentCodeCount;
  double? _dashboardKm;

  String? get vin => _vin;
  double? get batteryVoltage => _voltage;
  ReadinessStatus? get readiness => _readiness;
  FreezeFrame? get freezeFrame => _freezeFrame;

  /// `true` once a freeze frame check ran (so "none stored" can be shown).
  bool get freezeFrameChecked => _freezeFrameChecked;
  bool get isRunning => _running;

  /// Human-readable description of the check currently running.
  String get currentStep => _step;
  String? get lastError => _lastError;
  DateTime? get lastRun => _lastRun;
  bool get hasResults => _lastRun != null;

  /// Total distance stored by the ECU (PID 0xA6), or `null` when the car
  /// doesn't report it.
  double? get ecuOdometerKm => _ecuOdometerKm;
  double? get distanceSinceClearedKm => _distanceSinceClearedKm;
  double? get distanceWithMilKm => _distanceWithMilKm;

  /// Number of permanent DTCs, or `null` when the car didn't answer.
  int? get permanentCodeCount => _permanentCodeCount;

  /// Odometer reading the user typed in from the instrument cluster (km).
  double? get dashboardKm => _dashboardKm;

  void setDashboardKm(double? km) {
    _dashboardKm = km;
    notifyListeners();
  }

  /// Reads a distance PID directly (independent of auto-detection).
  Future<double?> _readDistance(int pid) async {
    final info = ObdCommands.findPid(pid);
    if (info == null) return null;
    try {
      final resp = await _obd.rawService.requestPid(pid);
      if (!resp.hasData || resp.dataBytes!.length < info.requiredBytes) {
        return null;
      }
      return info.formula(resp.dataBytes!);
    } catch (_) {
      return null;
    }
  }

  /// PIDs read from the freeze frame when the car hasn't been auto-detected.
  static const List<int> _defaultFreezeFramePids = [
    ObdCommands.pidRpm,
    ObdCommands.pidSpeed,
    ObdCommands.pidCoolantTemp,
    ObdCommands.pidEngineLoad,
    ObdCommands.pidThrottlePosition,
    ObdCommands.pidIntakeAirTemp,
    ObdCommands.pidIntakeManifoldPressure,
    ObdCommands.pidShortTermFuelTrim,
    ObdCommands.pidLongTermFuelTrim,
  ];

  void _setStep(String s) {
    _step = s;
    notifyListeners();
  }

  Future<void> run() async {
    if (_running) return;
    if (!_obd.isConnected) {
      _lastError = 'Not connected to ELM327.';
      notifyListeners();
      return;
    }
    _running = true;
    _lastError = null;
    _vin = null;
    _voltage = null;
    _readiness = null;
    _freezeFrame = null;
    _freezeFrameChecked = false;
    _ecuOdometerKm = null;
    _distanceSinceClearedKm = null;
    _distanceWithMilKm = null;
    _permanentCodeCount = null;
    notifyListeners();

    try {
      if (_obd.isDemoMode) {
        await _runDemo();
      } else {
        await _runLive();
      }
      _lastRun = DateTime.now();
    } catch (e) {
      _lastError = 'Inspection failed: $e';
    } finally {
      _running = false;
      _step = '';
      notifyListeners();
    }
  }

  Future<void> _runLive() async {
    final svc = _obd.rawService;

    _setStep('Reading battery voltage…');
    try {
      _voltage = await svc.readAdapterVoltage();
    } catch (_) {}

    _setStep('Reading VIN…');
    try {
      _vin = await svc.requestVin();
    } catch (_) {}

    _setStep('Reading mileage counters…');
    _ecuOdometerKm = await _readDistance(ObdCommands.pidOdometer);
    _distanceSinceClearedKm =
        await _readDistance(ObdCommands.pidDistanceSinceCleared);
    _distanceWithMilKm = await _readDistance(ObdCommands.pidDistanceWithMil);

    _setStep('Checking permanent codes…');
    try {
      _permanentCodeCount = (await svc.requestPermanentDtcs()).length;
    } catch (_) {}

    _setStep('Checking readiness monitors…');
    try {
      final resp = await svc.requestPid(0x01);
      if (resp.hasData) {
        _readiness = ReadinessStatus.parse(resp.dataBytes!);
      }
    } catch (_) {}

    _setStep('Reading freeze frame…');
    try {
      final dtc = await svc.requestFreezeFrameDtc();
      if (dtc != null) {
        final pids = _freezeFramePids();
        final values = <int, double>{};
        for (final pid in pids) {
          final info = ObdCommands.findPid(pid);
          if (info == null) continue;
          try {
            final bytes = await svc.requestFreezeFramePid(pid);
            if (bytes == null || bytes.length < info.requiredBytes) {
              continue;
            }
            values[pid] = info.formula(bytes);
          } catch (_) {}
        }
        _freezeFrame = FreezeFrame(dtc: dtc, values: values);
      }
    } catch (_) {}
    _freezeFrameChecked = true;
  }

  /// Freeze frame PIDs: the car's detected live PIDs (minus slow distance
  /// counters), else a common default set. Sorted in display order.
  List<int> _freezeFramePids() {
    final detected = _obd.detectedPids
        .where((p) => !ObdCommands.distancePids.contains(p))
        .toList();
    final pids = detected.isNotEmpty
        ? detected
        : List<int>.from(_defaultFreezeFramePids);
    pids.sort(ObdCommands.comparePidPriority);
    return pids;
  }

  Future<void> _runDemo() async {
    _setStep('Running demo inspection…');
    await Future.delayed(const Duration(milliseconds: 900));
    _voltage = 14.1;
    _vin = 'ML32A3HJ0LH012345';
    _readiness = ReadinessStatus.parse(const [0x00, 0x07, 0x65, 0x04]);
    _freezeFrame = const FreezeFrame(
      dtc: 'P0171',
      values: {
        ObdCommands.pidRpm: 2150,
        ObdCommands.pidSpeed: 62,
        ObdCommands.pidCoolantTemp: 89,
        ObdCommands.pidEngineLoad: 41.2,
        ObdCommands.pidShortTermFuelTrim: 12.5,
        ObdCommands.pidLongTermFuelTrim: 18.0,
      },
    );
    _freezeFrameChecked = true;
    _ecuOdometerKm = 45210.3;
    _distanceSinceClearedKm = 1280;
    _distanceWithMilKm = 0;
    _permanentCodeCount = 0;
  }
}
