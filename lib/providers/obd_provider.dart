import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/obd_data.dart';
import '../models/pid_info.dart';
import '../models/vehicle_profile.dart';
import '../services/obd_service.dart';
import '../utils/obd_commands.dart';

class PidHistory {
  final Queue<PidValue> _values = Queue<PidValue>();
  static const int retentionSeconds = 60;

  void add(PidValue v) {
    _values.addLast(v);
    final cutoff =
        DateTime.now().subtract(const Duration(seconds: retentionSeconds));
    while (_values.isNotEmpty &&
        _values.first.timestamp.isBefore(cutoff)) {
      _values.removeFirst();
    }
  }

  List<PidValue> get values => _values.toList(growable: false);
}

class OBDProvider extends ChangeNotifier {
  final ObdService _service = ObdService();

  ObdSettings _settings = const ObdSettings();
  ObdConnectionState _connectionState = ObdConnectionState.disconnected;
  String? _lastError;

  final Map<int, PidStats> _stats = {};
  final Map<int, PidHistory> _history = {};
  final Set<int> _enabledPids = {};
  final Set<int> _unsupportedPids = {};
  final Map<int, int> _pidErrorCount = {};
  static const int _unsupportedThreshold = 3;

  /// Manufacturer-specific parameter names from the active vehicle profile.
  List<String> _manufacturerParams = const [];
  VehicleProfile? _activeProfile;

  /// PIDs the connected vehicle reported as supported via OBD-II auto-detect.
  List<int> _detectedPids = [];
  bool _pidDetectionDone = false;
  bool _isDetectingPids = false;

  bool _isDemoMode = false;
  Timer? _demoTimer;
  int _demoTick = 0;

  Timer? _pollTimer;
  bool _polling = false;
  late final StreamSubscription<ObdConnectionState> _stateSub;

  static const String _prefsIp = 'obd.ip';
  static const String _prefsPort = 'obd.port';
  static const String _prefsInterval = 'obd.interval';
  static const String _prefsProtocol = 'obd.protocol';
  static const String _prefsEnabledPids = 'obd.enabledPids';
  static const String _prefsDetectedPids = 'obd.detectedPids';
  // Mirror of VehicleProvider's storage key — used so loadSettings does not
  // clobber the PID set that applyVehicleProfile will install.
  static const String _prefsVehicleProfile = 'vehicle.profile';

  OBDProvider() {
    _stateSub = _service.connectionStream.listen((s) {
      _connectionState = s;
      notifyListeners();
      if (s == ObdConnectionState.connected) {
        // Ask the car which PIDs it actually supports before polling.
        _detectAndApplyPids().then((_) => _startPolling());
      } else {
        _stopPolling();
      }
    });
    for (final p in ObdCommands.supportedPids) {
      _stats[p.pid] = PidStats();
      _history[p.pid] = PidHistory();
      _enabledPids.add(p.pid);
    }
  }

  ObdSettings get settings => _settings;
  ObdConnectionState get connectionState => _connectionState;
  String? get lastError => _lastError;
  bool get isConnected =>
      _connectionState == ObdConnectionState.connected;

  /// `true` while simulated demo data is being generated.
  bool get isDemoMode => _isDemoMode;

  PidStats statsFor(int pid) => _stats[pid] ?? (PidStats()..reset());
  PidHistory historyFor(int pid) => _history[pid] ?? PidHistory();
  bool isPidEnabled(int pid) => _enabledPids.contains(pid);
  bool isPidUnsupported(int pid) => _unsupportedPids.contains(pid);

  /// Manufacturer-specific parameters of the active vehicle profile, shown
  /// for information only (they cannot be polled over generic OBD-II).
  List<String> get manufacturerParams => _manufacturerParams;

  /// The vehicle profile currently driving the PID set, if any.
  VehicleProfile? get activeProfile => _activeProfile;

  /// PIDs the connected vehicle reported as supported via OBD-II auto-detect.
  List<int> get detectedPids => List.unmodifiable(_detectedPids);

  /// `true` once a successful auto-detection has replaced the database PIDs.
  bool get pidDetectionDone => _pidDetectionDone;

  /// `true` while a supported-PID scan is in progress.
  bool get isDetectingPids => _isDetectingPids;

  /// Applies a [VehicleProfile]: replaces the enabled PID set with the
  /// vehicle's supported PIDs and resets all collected diagnostics.
  void applyVehicleProfile(VehicleProfile profile) {
    // Switching to a genuinely different vehicle invalidates any PID
    // auto-detection performed for the previous one.
    final isDifferentVehicle = _activeProfile != null &&
        (_activeProfile!.brandName != profile.brandName ||
            _activeProfile!.modelName != profile.modelName ||
            _activeProfile!.selectedYear != profile.selectedYear);
    if (isDifferentVehicle) {
      _clearDetectedPids();
    }

    _activeProfile = profile;
    _manufacturerParams = List<String>.from(profile.manufacturerParams);

    _enabledPids.clear();
    if (_pidDetectionDone && _detectedPids.isNotEmpty) {
      // A valid auto-detection exists for this vehicle (detected this
      // session, or restored from storage on launch) — keep it.
      _enabledPids.addAll(_detectedPids);
    } else {
      // No detection yet — fall back to the vehicle database PID set.
      _enabledPids.addAll(profile.supportedPidCodes);
    }
    _unsupportedPids.clear();
    _pidErrorCount.clear();
    for (final s in _stats.values) {
      s.reset();
    }
    notifyListeners();
  }

  /// Starts Demo Mode: marks the provider as connected and begins emitting
  /// simulated, realistic vehicle data on a periodic timer.
  void startDemoMode() {
    _isDemoMode = true;
    _connectionState = ObdConnectionState.connected;
    _lastError = null;
    _demoTick = 0;
    _unsupportedPids.clear();
    _pidErrorCount.clear();
    for (final s in _stats.values) {
      s.reset();
    }
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _generateDemoData(),
    );
    notifyListeners();
  }

  /// Stops Demo Mode and returns the provider to a disconnected state.
  void stopDemoMode() {
    _isDemoMode = false;
    _demoTimer?.cancel();
    _demoTimer = null;
    _connectionState = ObdConnectionState.disconnected;
    for (final s in _stats.values) {
      s.reset();
    }
    notifyListeners();
  }

  /// Produces one frame of simulated data — a realistic idling engine that
  /// periodically revs up — and feeds it into the stats / history maps.
  void _generateDemoData() {
    final t = _demoTick;
    final rand = Random();
    final idling = t % 40 < 30;

    // RPM: idle at ~800, occasionally revs to 2500-4000.
    double rpm;
    if (idling) {
      rpm = 800 + (sin(t * 0.3) * 50) + (rand.nextDouble() * 30);
    } else {
      rpm = 1500 + (sin(t * 0.15) * 1200) + (rand.nextDouble() * 100);
    }

    // Speed: 0 when idling, increases during rev.
    double speed = 0;
    if (!idling) {
      speed = 20 + (sin(t * 0.1) * 15);
    }

    // Coolant temp: gradually warms from 60 to 90 over time.
    final coolant =
        60 + min(30, t * 0.05) + (sin(t * 0.1) * 1.5);

    // Engine load: correlates with RPM.
    final load = 15 + (rpm / 8000 * 60) + (sin(t * 0.2) * 5);

    // Intake air temp: stable around 35-45.
    final intakeTemp = 40 + (sin(t * 0.05) * 5);

    // Throttle: low at idle, spikes during rev.
    final throttle = idling
        ? 8 + (sin(t * 0.2) * 3)
        : 25 + (sin(t * 0.3) * 15);

    // MAP: vacuum at idle (~30kPa), higher under load (~80kPa).
    final map = idling
        ? 30 + (sin(t * 0.2) * 3)
        : 65 + (sin(t * 0.2) * 10);

    // Timing advance: 8-15 degrees.
    final timing = 10 + (sin(t * 0.15) * 3);

    // Battery voltage: 13.8-14.4V when running.
    final battery = 14.1 + (sin(t * 0.08) * 0.2);

    // O2 upstream: oscillates 0.1-0.9V (normal closed loop).
    final o2up = 0.45 + (sin(t * 0.8) * 0.35);

    // O2 downstream: more stable, catalytic converter smoothed.
    final o2down = 0.65 + (sin(t * 0.2) * 0.06);

    // Barometric: stable ~101 kPa.
    final baro = 101.0 + (sin(t * 0.01) * 0.5);

    // Engine runtime: increments each tick.
    final runtime = t * 0.8;

    // Fuel level: stable ~65%.
    final fuel = 65 + (sin(t * 0.02) * 1);

    // Short term fuel trim: small oscillation +/-5%.
    final stft = sin(t * 0.4) * 4;

    // Long term fuel trim: very stable +/-2%.
    final ltft = sin(t * 0.02) * 1.5;

    // Fuel pressure: stable rail pressure with light variation.
    final fuelPressure = 320 + (sin(t * 0.1) * 12);

    // Ambient air temp: stable around 30-35°C.
    final ambient = 33.0 + (sin(_demoTick * 0.02) * 2.0);

    // MAF air flow: low at idle, rises with engine speed / load.
    final maf = idling
        ? 3.0 + (sin(t * 0.3) * 0.8)
        : 9.0 + (rpm / 8000 * 22) + (sin(t * 0.2) * 1.5);

    // Accelerator pedal position: tracks throttle input.
    final accelPedal =
        (throttle + (sin(t * 0.25) * 1.5)).clamp(0.0, 100.0).toDouble();

    final values = <int, double>{
      ObdCommands.pidRpm: rpm,
      ObdCommands.pidSpeed: speed,
      ObdCommands.pidCoolantTemp: coolant,
      ObdCommands.pidEngineLoad: load,
      ObdCommands.pidIntakeAirTemp: intakeTemp,
      ObdCommands.pidThrottlePosition: throttle,
      ObdCommands.pidIntakeManifoldPressure: map,
      ObdCommands.pidTimingAdvance: timing,
      ObdCommands.pidControlModuleVoltage: battery,
      ObdCommands.pidO2Sensor1Voltage: o2up,
      ObdCommands.pidO2Sensor2Voltage: o2down,
      ObdCommands.pidBarometricPressure: baro,
      ObdCommands.pidEngineRunTime: runtime,
      ObdCommands.pidFuelLevel: fuel,
      ObdCommands.pidShortTermFuelTrim: stft,
      ObdCommands.pidLongTermFuelTrim: ltft,
      ObdCommands.pidFuelPressure: fuelPressure,
      ObdCommands.pidAmbientAirTemp: ambient,
      ObdCommands.pidMafAirFlow: maf,
      ObdCommands.pidAcceleratorPedal: accelPedal,
    };

    for (final pid in ObdCommands.supportedPids) {
      if (!_enabledPids.contains(pid.pid)) continue;
      final value = values[pid.pid];
      if (value == null) continue;
      _stats[pid.pid]?.update(value);
      _history[pid.pid]?.add(PidValue(
        pid: pid.pid,
        value: value,
        timestamp: DateTime.now(),
      ));
    }

    _demoTick++;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = ObdSettings(
      ipAddress: prefs.getString(_prefsIp) ?? '192.168.0.10',
      port: prefs.getInt(_prefsPort) ?? 35000,
      pollingIntervalMs: prefs.getInt(_prefsInterval) ?? 500,
      protocol: prefs.getString(_prefsProtocol) ?? 'Auto',
    );
    // If a vehicle has been chosen, its profile is the source of truth for
    // the PID set (applied via applyVehicleProfile); skip the saved list so
    // we don't race with / override it.
    final hasVehicleProfile =
        prefs.getString(_prefsVehicleProfile) != null;
    final enabled = prefs.getStringList(_prefsEnabledPids);
    if (enabled != null && !hasVehicleProfile) {
      _enabledPids
        ..clear()
        ..addAll(enabled.map(int.tryParse).whereType<int>());
    }
    // Restore a previous OBD-II auto-detection so it survives app restarts.
    // It is only meaningful when a vehicle profile is selected.
    final detectedSaved = prefs.getStringList(_prefsDetectedPids);
    if (detectedSaved != null && hasVehicleProfile) {
      final restored = detectedSaved
          .map((s) => int.tryParse(s, radix: 16))
          .whereType<int>()
          .toList();
      if (restored.isNotEmpty) {
        _detectedPids = restored;
        _pidDetectionDone = true;
        _enabledPids
          ..clear()
          ..addAll(restored);
      }
    }
    notifyListeners();
  }

  Future<void> updateSettings(ObdSettings newSettings) async {
    _settings = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsIp, newSettings.ipAddress);
    await prefs.setInt(_prefsPort, newSettings.port);
    await prefs.setInt(_prefsInterval, newSettings.pollingIntervalMs);
    await prefs.setString(_prefsProtocol, newSettings.protocol);
    notifyListeners();
  }

  Future<void> setPidEnabled(int pid, bool enabled) async {
    if (enabled) {
      _enabledPids.add(pid);
    } else {
      _enabledPids.remove(pid);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsEnabledPids, _enabledPids.map((e) => e.toString()).toList());
    notifyListeners();
  }

  Future<bool> connect() async {
    // In Demo Mode the simulated data is already flowing — no real adapter.
    if (_isDemoMode) {
      return true;
    }
    _lastError = null;
    _unsupportedPids.clear();
    _pidErrorCount.clear();
    for (final s in _stats.values) {
      s.reset();
    }
    notifyListeners();
    final ok = await _service.connect(_settings);
    if (!ok) {
      _lastError =
          'Could not reach ELM327 at ${_settings.ipAddress}:${_settings.port}';
      notifyListeners();
    }
    return ok;
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    // A disconnection invalidates the auto-detection; the next connection
    // re-scans from scratch.
    _clearDetectedPids();
    notifyListeners();
  }

  /// Queries the connected vehicle for its real supported-PID set and, on
  /// success, replaces the database-guessed PID set with it. Runs after a
  /// successful connection, before polling starts. A no-op in Demo Mode.
  Future<void> _detectAndApplyPids() async {
    if (_isDemoMode) {
      // Skip real detection in demo mode — demo uses all standard PIDs.
      _pidDetectionDone = false;
      _isDetectingPids = false;
      return;
    }
    if (!_service.isConnected) return;
    _isDetectingPids = true;
    notifyListeners();

    try {
      final detected = await _service.detectSupportedPids();

      if (detected.isNotEmpty) {
        _detectedPids = detected;
        _pidDetectionDone = true;

        // Override the enabled PIDs with what the car actually reported
        // as supported.
        _enabledPids
          ..clear()
          ..addAll(detected);

        // We now know exactly what is supported — clear stale state.
        _unsupportedPids.clear();
        _pidErrorCount.clear();

        await _saveDetectedPids(detected);
      }
    } catch (e) {
      // Detection failed — keep using the database PIDs.
      _pidDetectionDone = false;
    } finally {
      _isDetectingPids = false;
      notifyListeners();
    }
  }

  /// Manually re-runs supported-PID detection (e.g. from Settings).
  Future<void> rescanSupportedPids() async {
    _pidDetectionDone = false;
    _stopPolling();
    await _detectAndApplyPids();
    _startPolling();
  }

  /// Persists the detected PID set as hex strings so it survives restarts.
  Future<void> _saveDetectedPids(List<int> pids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsDetectedPids,
      pids.map((p) => p.toRadixString(16)).toList(),
    );
  }

  /// Drops the current detection and removes it from storage.
  void _clearDetectedPids() {
    _detectedPids = [];
    _pidDetectionDone = false;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.remove(_prefsDetectedPids));
  }

  void resetMinMax() {
    for (final s in _stats.values) {
      s.reset();
    }
    notifyListeners();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _settings.pollingIntervalMs),
      (_) => _pollOnce(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce() async {
    if (_polling) return;
    if (!_service.isConnected) return;
    _polling = true;
    try {
      final pidsToPoll = ObdCommands.supportedPids
          .where((p) =>
              _enabledPids.contains(p.pid) &&
              !_unsupportedPids.contains(p.pid))
          .toList(growable: false);

      bool changed = false;
      for (final pid in pidsToPoll) {
        if (!_service.isConnected) break;
        final resp = await _service.requestPid(pid.pid);
        if (resp.isNoData) {
          final newCount = (_pidErrorCount[pid.pid] ?? 0) + 1;
          _pidErrorCount[pid.pid] = newCount;
          if (newCount >= _unsupportedThreshold) {
            _unsupportedPids.add(pid.pid);
            changed = true;
          }
          continue;
        }
        if (resp.isError || !resp.hasData) {
          continue;
        }
        if (resp.dataBytes!.length < pid.requiredBytes) {
          continue;
        }
        try {
          final value = pid.formula(resp.dataBytes!);
          final stats = _stats[pid.pid]!;
          stats.update(value);
          _history[pid.pid]!.add(PidValue(
            pid: pid.pid,
            value: value,
            timestamp: DateTime.now(),
          ));
          _pidErrorCount[pid.pid] = 0;
          changed = true;
        } catch (_) {}
      }
      if (changed) notifyListeners();
    } finally {
      _polling = false;
    }
  }

  ObdService get rawService => _service;

  @override
  void dispose() {
    _stopPolling();
    _demoTimer?.cancel();
    _stateSub.cancel();
    _service.dispose();
    super.dispose();
  }
}
