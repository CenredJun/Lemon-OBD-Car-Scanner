import '../models/pid_info.dart';

class ObdCommands {
  static const String reset = 'ATZ';
  static const String echoOff = 'ATE0';
  static const String linefeedsOff = 'ATL0';
  static const String headersOff = 'ATH0';
  static const String spacesOff = 'ATS0';
  static const String autoProtocol = 'ATSP0';

  static const String requestDtcs = '03';
  static const String clearDtcs = '04';
  static const String requestPendingDtcs = '07';

  static const int pidEngineLoad = 0x04;
  static const int pidCoolantTemp = 0x05;
  static const int pidShortTermFuelTrim = 0x06;
  static const int pidLongTermFuelTrim = 0x07;
  static const int pidFuelPressure = 0x0A;
  static const int pidIntakeManifoldPressure = 0x0B;
  static const int pidRpm = 0x0C;
  static const int pidSpeed = 0x0D;
  static const int pidTimingAdvance = 0x0E;
  static const int pidIntakeAirTemp = 0x0F;
  static const int pidMafAirFlow = 0x10;
  static const int pidThrottlePosition = 0x11;
  static const int pidO2Sensor1Voltage = 0x14;
  static const int pidO2Sensor2Voltage = 0x15;
  static const int pidEngineRunTime = 0x1F;
  static const int pidFuelLevel = 0x2F;
  static const int pidBarometricPressure = 0x33;
  static const int pidControlModuleVoltage = 0x42;
  static const int pidAmbientAirTemp = 0x46;
  static const int pidAcceleratorPedal = 0x49;

  /// Every standard OBD-II PID the app knows how to decode and display.
  /// This is the master catalogue both the Dashboard and Live Data screens
  /// draw from; which of these are actually shown is decided solely by
  /// [OBDProvider.isPidEnabled].
  static final List<PidInfo> supportedPids = [
    PidInfo(
      pid: pidEngineLoad,
      name: 'Engine Load',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      requiredBytes: 1,
      formula: (b) => b[0] * 100.0 / 255.0,
    ),
    PidInfo(
      pid: pidCoolantTemp,
      name: 'Coolant Temp',
      unit: '°C',
      minValue: -40,
      maxValue: 215,
      requiredBytes: 1,
      formula: (b) => b[0] - 40.0,
    ),
    PidInfo(
      pid: pidShortTermFuelTrim,
      name: 'Short Term Fuel Trim',
      unit: '%',
      minValue: -100,
      maxValue: 99.2,
      requiredBytes: 1,
      formula: (b) => (b[0] - 128) * 100.0 / 128.0,
    ),
    PidInfo(
      pid: pidLongTermFuelTrim,
      name: 'Long Term Fuel Trim',
      unit: '%',
      minValue: -100,
      maxValue: 99.2,
      requiredBytes: 1,
      formula: (b) => (b[0] - 128) * 100.0 / 128.0,
    ),
    PidInfo(
      pid: pidFuelPressure,
      name: 'Fuel Pressure',
      unit: 'kPa',
      minValue: 0,
      maxValue: 765,
      requiredBytes: 1,
      formula: (b) => b[0] * 3.0,
    ),
    PidInfo(
      pid: pidIntakeManifoldPressure,
      name: 'Intake Manifold Pressure',
      unit: 'kPa',
      minValue: 0,
      maxValue: 255,
      requiredBytes: 1,
      formula: (b) => b[0].toDouble(),
    ),
    PidInfo(
      pid: pidRpm,
      name: 'Engine RPM',
      unit: 'rpm',
      minValue: 0,
      maxValue: 8000,
      requiredBytes: 2,
      formula: (b) => ((b[0] * 256) + b[1]) / 4.0,
    ),
    PidInfo(
      pid: pidSpeed,
      name: 'Vehicle Speed',
      unit: 'km/h',
      minValue: 0,
      maxValue: 260,
      requiredBytes: 1,
      formula: (b) => b[0].toDouble(),
    ),
    PidInfo(
      pid: pidTimingAdvance,
      name: 'Timing Advance',
      unit: '°',
      minValue: -64,
      maxValue: 63.5,
      requiredBytes: 1,
      formula: (b) => (b[0] / 2.0) - 64.0,
    ),
    PidInfo(
      pid: pidIntakeAirTemp,
      name: 'Intake Air Temp',
      unit: '°C',
      minValue: -40,
      maxValue: 215,
      requiredBytes: 1,
      formula: (b) => b[0] - 40.0,
    ),
    PidInfo(
      pid: pidMafAirFlow,
      name: 'MAF Air Flow',
      unit: 'g/s',
      minValue: 0,
      maxValue: 655.35,
      requiredBytes: 2,
      formula: (b) => ((b[0] * 256) + b[1]) / 100.0,
    ),
    PidInfo(
      pid: pidThrottlePosition,
      name: 'Throttle Position',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      requiredBytes: 1,
      formula: (b) => b[0] * 100.0 / 255.0,
    ),
    PidInfo(
      pid: pidO2Sensor1Voltage,
      name: 'O2 Upstream',
      unit: 'V',
      minValue: 0,
      maxValue: 1.275,
      requiredBytes: 2,
      formula: (b) => b[0] * 0.005,
    ),
    PidInfo(
      pid: pidO2Sensor2Voltage,
      name: 'O2 Downstream',
      unit: 'V',
      minValue: 0,
      maxValue: 1.275,
      requiredBytes: 2,
      formula: (b) => b[0] * 0.005,
    ),
    PidInfo(
      pid: pidEngineRunTime,
      name: 'Engine Run Time',
      unit: 'sec',
      minValue: 0,
      maxValue: 65535,
      requiredBytes: 2,
      formula: (b) => ((b[0] * 256) + b[1]).toDouble(),
    ),
    PidInfo(
      pid: pidFuelLevel,
      name: 'Fuel Level',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      requiredBytes: 1,
      formula: (b) => b[0] * 100.0 / 255.0,
    ),
    PidInfo(
      pid: pidBarometricPressure,
      name: 'Barometric Pressure',
      unit: 'kPa',
      minValue: 0,
      maxValue: 255,
      requiredBytes: 1,
      formula: (b) => b[0].toDouble(),
    ),
    PidInfo(
      pid: pidControlModuleVoltage,
      name: 'Control Module Voltage',
      unit: 'V',
      minValue: 0,
      maxValue: 65.535,
      requiredBytes: 2,
      formula: (b) => ((b[0] * 256) + b[1]) / 1000.0,
    ),
    PidInfo(
      pid: pidAmbientAirTemp,
      name: 'Ambient Air Temp',
      unit: '°C',
      minValue: -40,
      maxValue: 215,
      requiredBytes: 1,
      formula: (b) => b[0] - 40.0,
    ),
    PidInfo(
      pid: pidAcceleratorPedal,
      name: 'Accelerator Pedal Position',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      requiredBytes: 1,
      formula: (b) => b[0] * 100.0 / 255.0,
    ),
  ];

  /// Display priority order shared by the Dashboard gauges and the Live Data
  /// list, so both screens present the same PIDs in the same order. A lower
  /// index is shown first; any PID not listed sorts to the end.
  static const List<int> pidDisplayPriority = [
    pidRpm, // Engine RPM          — 1st always
    pidSpeed, // Vehicle Speed       — 2nd always
    pidCoolantTemp, // Coolant Temp        — 3rd always
    pidEngineLoad, // Engine Load         — 4th always
    pidThrottlePosition, // Throttle Position
    pidIntakeAirTemp, // Intake Air Temp
    pidAmbientAirTemp, // Ambient Air Temp
    pidMafAirFlow, // MAF Air Flow
    pidFuelLevel, // Fuel Level
    pidIntakeManifoldPressure, // Intake Manifold Pressure (MAP)
    pidFuelPressure, // Fuel Pressure
    pidTimingAdvance, // Timing Advance
    pidAcceleratorPedal, // Accelerator Pedal Position
    pidShortTermFuelTrim, // Short Term Fuel Trim
    pidLongTermFuelTrim, // Long Term Fuel Trim
    pidO2Sensor1Voltage, // O2 Upstream
    pidO2Sensor2Voltage, // O2 Downstream
    pidBarometricPressure, // Barometric Pressure
    pidControlModuleVoltage, // Control Module Voltage
    pidEngineRunTime, // Engine Run Time     — last always
  ];

  /// Comparator that orders two PIDs by [pidDisplayPriority]. Pass to
  /// `List<PidInfo>.sort` as `(a, b) => comparePidPriority(a.pid, b.pid)`.
  static int comparePidPriority(int a, int b) {
    final ai = pidDisplayPriority.indexOf(a);
    final bi = pidDisplayPriority.indexOf(b);
    final aIndex = ai == -1 ? 999 : ai;
    final bIndex = bi == -1 ? 999 : bi;
    return aIndex.compareTo(bIndex);
  }

  static PidInfo? findPid(int pid) {
    for (final p in supportedPids) {
      if (p.pid == pid) return p;
    }
    return null;
  }
}
