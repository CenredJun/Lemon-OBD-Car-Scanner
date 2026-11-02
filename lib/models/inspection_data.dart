// Data returned by the one-shot "Inspection" checks: readiness monitors,
// freeze frame, VIN and adapter battery voltage.

/// One OBD-II emissions self-test (readiness monitor).
class ReadinessMonitor {
  final String name;

  /// `true` when the car has finished running this self-test.
  final bool complete;

  const ReadinessMonitor({required this.name, required this.complete});
}

/// Decoded Mode 01 PID 0x01 ("monitor status since DTCs cleared").
class ReadinessStatus {
  /// Check engine light (MIL) currently on.
  final bool milOn;

  /// Number of emissions-related DTCs the ECU reports as stored.
  final int dtcCount;

  /// `true` for compression-ignition (diesel) engines.
  final bool isDiesel;

  /// Only the monitors this car actually supports.
  final List<ReadinessMonitor> monitors;

  const ReadinessStatus({
    required this.milOn,
    required this.dtcCount,
    required this.isDiesel,
    required this.monitors,
  });

  int get completeCount => monitors.where((m) => m.complete).length;
  int get incompleteCount => monitors.length - completeCount;

  static const List<String> _sparkMonitors = [
    'Catalyst',
    'Heated Catalyst',
    'Evaporative System',
    'Secondary Air System',
    'A/C Refrigerant',
    'Oxygen Sensor',
    'Oxygen Sensor Heater',
    'EGR System',
  ];

  static const List<String> _dieselMonitors = [
    'NMHC Catalyst',
    'NOx / SCR Aftertreatment',
    '', // reserved
    'Boost Pressure',
    '', // reserved
    'Exhaust Gas Sensor',
    'Particulate Filter (DPF)',
    'EGR / VVT System',
  ];

  /// Parses the 4 data bytes (A, B, C, D) of PID 0x01.
  ///
  /// Byte B bits 0-2 = continuous monitors supported, bits 4-6 = incomplete.
  /// Byte C = engine-specific monitors supported, byte D = incomplete.
  /// For "incomplete" bits, 1 means NOT complete.
  static ReadinessStatus? parse(List<int> b) {
    if (b.length < 4) return null;
    final a = b[0], bb = b[1], c = b[2], d = b[3];
    final isDiesel = (bb & 0x08) != 0;
    final monitors = <ReadinessMonitor>[];

    const continuous = ['Misfire', 'Fuel System', 'Components'];
    for (var i = 0; i < 3; i++) {
      if ((bb >> i) & 1 == 1) {
        monitors.add(ReadinessMonitor(
          name: continuous[i],
          complete: (bb >> (i + 4)) & 1 == 0,
        ));
      }
    }

    final names = isDiesel ? _dieselMonitors : _sparkMonitors;
    for (var i = 0; i < 8; i++) {
      if (names[i].isEmpty) continue;
      if ((c >> i) & 1 == 1) {
        monitors.add(ReadinessMonitor(
          name: names[i],
          complete: (d >> i) & 1 == 0,
        ));
      }
    }

    return ReadinessStatus(
      milOn: (a & 0x80) != 0,
      dtcCount: a & 0x7F,
      isDiesel: isDiesel,
      monitors: monitors,
    );
  }
}

/// Snapshot of sensor values the ECU stored when a fault code was set.
class FreezeFrame {
  /// The DTC that triggered the snapshot.
  final String dtc;

  /// PID → decoded value.
  final Map<int, double> values;

  const FreezeFrame({required this.dtc, required this.values});
}
