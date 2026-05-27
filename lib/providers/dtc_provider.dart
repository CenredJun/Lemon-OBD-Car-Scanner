import 'package:flutter/foundation.dart';

import '../models/dtc_model.dart';
import '../utils/dtc_descriptions.dart';
import 'obd_provider.dart';

class DTCProvider extends ChangeNotifier {
  final OBDProvider _obd;

  List<Dtc> _stored = [];
  List<Dtc> _pending = [];
  bool _scanning = false;
  bool _clearing = false;
  String? _lastError;
  DateTime? _lastScan;

  DTCProvider(this._obd);

  List<Dtc> get storedCodes => List.unmodifiable(_stored);
  List<Dtc> get pendingCodes => List.unmodifiable(_pending);
  bool get isScanning => _scanning;
  bool get isClearing => _clearing;
  String? get lastError => _lastError;
  DateTime? get lastScanTime => _lastScan;

  Future<void> scan() async {
    if (_scanning) return;
    if (!_obd.isConnected) {
      _lastError = 'Not connected to ELM327.';
      notifyListeners();
      return;
    }
    _scanning = true;
    _lastError = null;
    notifyListeners();
    try {
      final stored = await _obd.rawService.requestDtcs();
      final pending = await _obd.rawService.requestPendingDtcs();
      _stored = stored
          .map((c) => Dtc(
                code: c,
                description: DtcDescriptions.lookup(c),
                status: DtcStatus.stored,
              ))
          .toList();
      _pending = pending
          .map((c) => Dtc(
                code: c,
                description: DtcDescriptions.lookup(c),
                status: DtcStatus.pending,
              ))
          .toList();
      _lastScan = DateTime.now();
    } catch (e) {
      _lastError = 'Scan failed: $e';
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<bool> clearAll() async {
    if (_clearing) return false;
    if (!_obd.isConnected) {
      _lastError = 'Not connected to ELM327.';
      notifyListeners();
      return false;
    }
    _clearing = true;
    _lastError = null;
    notifyListeners();
    try {
      final ok = await _obd.rawService.clearDtcs();
      if (ok) {
        _stored = [];
        _pending = [];
      } else {
        _lastError = 'Adapter did not confirm clear.';
      }
      return ok;
    } catch (e) {
      _lastError = 'Clear failed: $e';
      return false;
    } finally {
      _clearing = false;
      notifyListeners();
    }
  }
}
