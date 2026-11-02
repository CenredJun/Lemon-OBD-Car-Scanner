import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/obd_data.dart';
import '../utils/obd_commands.dart';

class ObdResponse {
  final String raw;
  final String cleaned;
  final bool isError;
  final bool isNoData;
  final List<int>? dataBytes;

  const ObdResponse({
    required this.raw,
    required this.cleaned,
    this.isError = false,
    this.isNoData = false,
    this.dataBytes,
  });

  bool get hasData => dataBytes != null && dataBytes!.isNotEmpty;
}

class ObdService {
  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  final StringBuffer _rxBuffer = StringBuffer();
  Completer<String>? _pending;
  final _connectionController =
      StreamController<ObdConnectionState>.broadcast();
  ObdConnectionState _state = ObdConnectionState.disconnected;
  bool _busy = false;
  bool _autoReconnect = true;
  ObdSettings _settings = const ObdSettings();
  Timer? _reconnectTimer;

  Stream<ObdConnectionState> get connectionStream =>
      _connectionController.stream;

  ObdConnectionState get state => _state;

  bool get isConnected => _state == ObdConnectionState.connected;

  void _setState(ObdConnectionState s) {
    _state = s;
    if (!_connectionController.isClosed) {
      _connectionController.add(s);
    }
  }

  Future<bool> connect(ObdSettings settings,
      {Duration timeout = const Duration(seconds: 10)}) async {
    _settings = settings;
    _autoReconnect = true;
    await _disposeSocket();
    _setState(ObdConnectionState.connecting);

    try {
      _socket = await Socket.connect(
        settings.ipAddress,
        settings.port,
        timeout: timeout,
      );
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      _socketSub = _socket!.listen(
        _onData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: true,
      );

      final ok = await _initElm327(settings);
      if (!ok) {
        await _disposeSocket();
        _setState(ObdConnectionState.error);
        return false;
      }
      _setState(ObdConnectionState.connected);
      return true;
    } on SocketException catch (_) {
      await _disposeSocket();
      _setState(ObdConnectionState.error);
      _scheduleReconnect();
      return false;
    } on TimeoutException catch (_) {
      await _disposeSocket();
      _setState(ObdConnectionState.error);
      _scheduleReconnect();
      return false;
    } catch (_) {
      await _disposeSocket();
      _setState(ObdConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    await _disposeSocket();
    _setState(ObdConnectionState.disconnected);
  }

  Future<bool> _initElm327(ObdSettings settings) async {
    try {
      await sendRaw(ObdCommands.reset,
          timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 800));
      await sendRaw(ObdCommands.echoOff);
      await sendRaw(ObdCommands.linefeedsOff);
      await sendRaw(ObdCommands.headersOff);
      await sendRaw(ObdCommands.spacesOff);
      await sendRaw(settings.protocolCommand);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onData(List<int> data) {
    final chunk = utf8.decode(data, allowMalformed: true);
    _rxBuffer.write(chunk);
    if (chunk.contains('>')) {
      final full = _rxBuffer.toString();
      _rxBuffer.clear();
      final pending = _pending;
      _pending = null;
      if (pending != null && !pending.isCompleted) {
        pending.complete(full);
      }
    }
  }

  void _onSocketError(Object err) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(err);
    }
    _setState(ObdConnectionState.error);
    _scheduleReconnect();
  }

  void _onSocketDone() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
          const SocketException('Socket closed by remote'));
    }
    if (_state == ObdConnectionState.connected) {
      _setState(ObdConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_autoReconnect && _state != ObdConnectionState.connected) {
        connect(_settings);
      }
    });
  }

  Future<String> sendRaw(String command,
      {Duration timeout = const Duration(seconds: 4)}) async {
    if (_socket == null) {
      throw StateError('Not connected');
    }
    while (_busy) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    _busy = true;
    try {
      _rxBuffer.clear();
      final completer = Completer<String>();
      _pending = completer;
      _socket!.write('$command\r');
      await _socket!.flush();
      final result =
          await completer.future.timeout(timeout, onTimeout: () {
        _pending = null;
        throw TimeoutException('OBD command timeout: $command');
      });
      return result;
    } finally {
      _busy = false;
    }
  }

  Future<ObdResponse> requestPid(int pid,
      {Duration timeout = const Duration(seconds: 3)}) async {
    final hex = pid.toRadixString(16).padLeft(2, '0').toUpperCase();
    final cmd = '01$hex';
    try {
      final raw = await sendRaw(cmd, timeout: timeout);
      return _parsePidResponse(raw, pid);
    } on TimeoutException {
      return const ObdResponse(
        raw: '',
        cleaned: '',
        isError: true,
      );
    }
  }

  /// Asks the vehicle which standard OBD-II PIDs it supports by reading the
  /// four "supported PIDs" bitmask requests (Mode 01 PID 0x00/0x20/0x40/0x60).
  ///
  /// Returns the supported PID numbers, filtered down to the ones this app
  /// knows how to decode. An empty list means detection failed or the car
  /// reported nothing usable.
  Future<List<int>> detectSupportedPids() async {
    // These 4 PIDs return bitmasks of what the car supports:
    //   PID 0x00 → bitmask for PIDs 0x01 to 0x20
    //   PID 0x20 → bitmask for PIDs 0x21 to 0x40
    //   PID 0x40 → bitmask for PIDs 0x41 to 0x60
    //   PID 0x60 → bitmask for PIDs 0x61 to 0x80
    final List<int> supported = [];
    //   PID 0x80 → bitmask for PIDs 0x81 to 0xA0
    //   PID 0xA0 → bitmask for PIDs 0xA1 to 0xC0 (odometer is 0xA6)
    final List<int> rangeStarters = [0x00, 0x20, 0x40, 0x60, 0x80, 0xA0];

    for (final rangeStart in rangeStarters) {
      try {
        final response = await requestPid(rangeStart,
            timeout: const Duration(seconds: 4));

        if (response.isError || response.isNoData || !response.hasData) {
          continue;
        }

        // Response is 4 bytes = 32 bits. Each bit represents whether the
        // next PID is supported: bit 31 (MSB of byte 0) = PID rangeStart+1,
        // bit 0 (LSB of byte 3) = PID rangeStart+32.
        if (response.dataBytes!.length < 4) continue;

        final bytes = response.dataBytes!;
        // Combine 4 bytes into a 32-bit integer.
        final bitmask = (bytes[0] << 24) |
            (bytes[1] << 16) |
            (bytes[2] << 8) |
            bytes[3];

        // Check each bit.
        for (int bit = 0; bit < 32; bit++) {
          // bit 31 = PID rangeStart+1, bit 0 = PID rangeStart+32.
          final pidNumber = rangeStart + (32 - bit);
          final isSupported = (bitmask >> bit) & 1 == 1;

          if (isSupported) {
            // Don't include the range-starter PIDs themselves
            // (0x00, 0x20, 0x40, 0x60) in the result.
            if (pidNumber % 0x20 != 0) {
              supported.add(pidNumber);
            }
          }
        }

        // If PID rangeStart+0x20 is NOT supported, the next range won't
        // have data either — stop early.
        final nextRangeSupported = (bitmask & 1) == 1;
        if (!nextRangeSupported && rangeStart != rangeStarters.last) {
          break;
        }
      } catch (e) {
        // If a range query fails, skip it and try the next.
        continue;
      }
    }

    // Filter to only include PIDs we know how to display (intersect with
    // our known PID list from ObdCommands).
    final knownPids = ObdCommands.supportedPids.map((p) => p.pid).toSet();
    return supported.where((pid) => knownPids.contains(pid)).toList();
  }

  // ---------------------------------------------------------------------
  // Inspection requests (one-shot, not part of the live polling loop)
  // ---------------------------------------------------------------------

  /// Reads the 17-character VIN (Mode 09 PID 02). Returns `null` when the
  /// car does not report it.
  ///
  /// Works for both CAN multi-frame replies ("014 / 0:490201… / 1:…") and
  /// older protocols (five "4902 0N …" lines) by collecting every data
  /// byte and keeping only characters that are valid in a VIN. VINs never
  /// contain I, O or Q, which also drops the 0x49 ('I') service byte.
  Future<String?> requestVin() async {
    final raw = await sendRaw('0902', timeout: const Duration(seconds: 6));
    final upper = raw.toUpperCase();
    if (upper.contains('NODATA') || upper.contains('NO DATA')) return null;

    final bytes = <int>[];
    for (var line in raw.split(RegExp(r'[\r\n]+'))) {
      line = line.replaceAll(' ', '').replaceAll('>', '').toUpperCase();
      if (line.isEmpty || _isErrorPayload(line)) continue;
      // CAN frame index prefix, e.g. "0:" / "1:" / "2:".
      line = line.replaceFirst(RegExp(r'^[0-9A-F]:'), '');
      // Lone byte-count line of a CAN multi-frame reply, e.g. "014".
      if (line.length == 3) continue;
      bytes.addAll(_hexToBytes(line));
    }

    final buf = StringBuffer();
    for (final b in bytes) {
      final isDigit = b >= 0x30 && b <= 0x39;
      final isLetter = b >= 0x41 && b <= 0x5A;
      if ((isDigit || isLetter) && b != 0x49 && b != 0x4F && b != 0x51) {
        buf.writeCharCode(b);
      }
    }
    final chars = buf.toString();
    if (chars.length < 17) return null;
    return chars.substring(chars.length - 17);
  }

  /// Battery voltage measured by the ELM327 itself on OBD pin 16
  /// ("ATRV"). Works on every car, engine on or off.
  Future<double?> readAdapterVoltage() async {
    final raw = await sendRaw('ATRV', timeout: const Duration(seconds: 3));
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*V', caseSensitive: false)
        .firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  /// Permanent DTCs (Mode 0A). These cannot be erased with a scan tool;
  /// the ECU clears them itself once the fault is confirmed fixed.
  Future<List<String>> requestPermanentDtcs() async {
    final raw = await sendRaw('0A', timeout: const Duration(seconds: 4));
    return _parseDtcResponse(raw, mode: 0x4A);
  }

  /// The DTC that caused freeze frame 0 to be stored (Mode 02 PID 02), or
  /// `null` when no freeze frame exists.
  Future<String?> requestFreezeFrameDtc() async {
    final raw =
        await sendRaw('020200', timeout: const Duration(seconds: 3));
    final cleaned = _cleanResponse(raw);
    if (cleaned.contains('NODATA') || _isErrorPayload(cleaned)) return null;
    final idx = cleaned.indexOf('4202');
    if (idx < 0) return null;
    // After "4202": frame number byte ("00"), then the 2-byte DTC.
    final rest = cleaned.substring(idx + 4);
    if (rest.length < 6) return null;
    return _decodeDtcCodeBytes(rest.substring(2, 6));
  }

  /// Raw data bytes of [pid] from freeze frame 0 (Mode 02), or `null` when
  /// the ECU did not store that PID.
  Future<List<int>?> requestFreezeFramePid(int pid) async {
    final hex = pid.toRadixString(16).padLeft(2, '0').toUpperCase();
    final raw =
        await sendRaw('02${hex}00', timeout: const Duration(seconds: 2));
    final cleaned = _cleanResponse(raw);
    if (cleaned.contains('NODATA') || _isErrorPayload(cleaned)) return null;
    final marker = '42$hex';
    final idx = cleaned.indexOf(marker);
    if (idx < 0) return null;
    // Skip the frame number byte that follows the PID.
    final data = cleaned.substring(idx + marker.length);
    if (data.length < 4) return null;
    final bytes = _hexToBytes(data.substring(2));
    return bytes.isEmpty ? null : bytes;
  }

  Future<List<String>> requestDtcs() async {
    final raw = await sendRaw(ObdCommands.requestDtcs,
        timeout: const Duration(seconds: 4));
    return _parseDtcResponse(raw, mode: 0x43);
  }

  Future<List<String>> requestPendingDtcs() async {
    final raw = await sendRaw(ObdCommands.requestPendingDtcs,
        timeout: const Duration(seconds: 4));
    return _parseDtcResponse(raw, mode: 0x47);
  }

  Future<bool> clearDtcs() async {
    final raw = await sendRaw(ObdCommands.clearDtcs,
        timeout: const Duration(seconds: 4));
    final cleaned = _cleanResponse(raw);
    return cleaned.contains('44') && !_isErrorPayload(cleaned);
  }

  ObdResponse _parsePidResponse(String raw, int pid) {
    final cleaned = _cleanResponse(raw);

    if (cleaned.contains('NODATA')) {
      return ObdResponse(
        raw: raw,
        cleaned: cleaned,
        isNoData: true,
      );
    }
    if (_isErrorPayload(cleaned)) {
      return ObdResponse(
        raw: raw,
        cleaned: cleaned,
        isError: true,
      );
    }

    final pidHex = pid.toRadixString(16).padLeft(2, '0').toUpperCase();
    final marker = '41$pidHex';
    final idx = cleaned.indexOf(marker);
    if (idx < 0) {
      return ObdResponse(
        raw: raw,
        cleaned: cleaned,
        isError: true,
      );
    }
    final dataHex = cleaned.substring(idx + marker.length);
    final bytes = _hexToBytes(dataHex);
    return ObdResponse(
      raw: raw,
      cleaned: cleaned,
      dataBytes: bytes,
    );
  }

  List<String> _parseDtcResponse(String raw, {required int mode}) {
    final cleaned = _cleanResponse(raw);
    if (cleaned.contains('NODATA') || _isErrorPayload(cleaned)) {
      return const [];
    }

    final modeHex =
        mode.toRadixString(16).padLeft(2, '0').toUpperCase();
    final result = <String>[];
    var idx = cleaned.indexOf(modeHex);
    while (idx >= 0) {
      var i = idx + 2;
      if (i + 2 <= cleaned.length) {
        i += 2;
      }
      while (i + 4 <= cleaned.length) {
        final code =
            _decodeDtcCodeBytes(cleaned.substring(i, i + 4));
        if (code == null || code == 'P0000') break;
        result.add(code);
        i += 4;
      }
      idx = cleaned.indexOf(modeHex, i);
    }
    return result.toSet().toList();
  }

  String? _decodeDtcCodeBytes(String fourHex) {
    if (fourHex.length != 4) return null;
    final byte1 = int.tryParse(fourHex.substring(0, 2), radix: 16);
    final byte2 = int.tryParse(fourHex.substring(2, 4), radix: 16);
    if (byte1 == null || byte2 == null) return null;
    if (byte1 == 0 && byte2 == 0) return null;
    final systemBits = (byte1 >> 6) & 0x03;
    String letter;
    switch (systemBits) {
      case 0:
        letter = 'P';
        break;
      case 1:
        letter = 'C';
        break;
      case 2:
        letter = 'B';
        break;
      case 3:
        letter = 'U';
        break;
      default:
        letter = 'P';
    }
    final firstDigit = (byte1 >> 4) & 0x03;
    final secondDigit = byte1 & 0x0F;
    final last2 = byte2.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$letter$firstDigit${secondDigit.toRadixString(16).toUpperCase()}$last2';
  }

  String _cleanResponse(String raw) {
    return raw
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .replaceAll('>', '')
        .toUpperCase();
  }

  bool _isErrorPayload(String cleaned) {
    return cleaned.contains('ERROR') ||
        cleaned.contains('UNABLETOCONNECT') ||
        cleaned.contains('CANERROR') ||
        cleaned.contains('BUSINIT') ||
        cleaned.contains('STOPPED') ||
        cleaned.contains('BUSBUSY') ||
        cleaned.contains('?');
  }

  List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (int i = 0; i + 1 < hex.length; i += 2) {
      final v = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (v == null) break;
      out.add(v);
    }
    return out;
  }

  Future<void> _disposeSocket() async {
    _reconnectTimer?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SocketException('Socket disposed'));
    }
    try {
      await _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _rxBuffer.clear();
    _busy = false;
  }

  Future<void> dispose() async {
    _autoReconnect = false;
    await _disposeSocket();
    await _connectionController.close();
  }
}
