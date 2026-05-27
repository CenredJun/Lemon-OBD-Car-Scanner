// Standalone audit script for the vehicle database.
//
// Run from the project root:
//   dart run audit/audit_vehicles.dart > audit/audit_report.txt
//
// Imports the pure-Dart vehicle catalogue and prints a full PID-support
// report plus a summary and a list of potential data issues.

import 'package:obd2_scanner/data/vehicle_database.dart';

/// Human-readable names for every standard OBD-II PID used in the database.
const Map<int, String> pidNames = {
  0x04: 'Engine Load',
  0x05: 'Coolant Temperature',
  0x06: 'Short Term Fuel Trim',
  0x07: 'Long Term Fuel Trim',
  0x0A: 'Fuel Pressure',
  0x0B: 'Intake Manifold Pressure (MAP)',
  0x0C: 'Engine RPM',
  0x0D: 'Vehicle Speed',
  0x0E: 'Timing Advance',
  0x0F: 'Intake Air Temperature',
  0x10: 'MAF Air Flow Rate',
  0x11: 'Throttle Position',
  0x14: 'O2 Sensor Upstream',
  0x15: 'O2 Sensor Downstream',
  0x1F: 'Engine Run Time',
  0x2F: 'Fuel Tank Level',
  0x33: 'Barometric Pressure',
  0x42: 'Control Module Voltage',
  0x49: 'Accelerator Pedal Position',
};

/// Manufacturer-specific parameter names grouped by category.
const Set<String> dieselParams = {
  'EGR Status',
  'DPF Soot Level',
  'Diesel Particulate Filter Temp',
};
const Set<String> hybridParams = {
  'Hybrid Battery Voltage',
  'Hybrid Battery SOC',
  'Hybrid Battery Temperature',
  'Electric Motor Output',
};
const Set<String> evParams = {
  'EV Battery Voltage',
  'EV Battery SOC',
  'EV Battery Temperature',
  'EV Motor RPM',
  'EV Range Remaining',
  'Charging Status',
};
const String turboParam = 'Turbo Boost Pressure';

String hex(int pid) =>
    '0x${pid.toRadixString(16).toUpperCase().padLeft(2, '0')}';

String pidLabel(int pid) => pidNames[pid] ?? 'Unknown PID';

void main() {
  final divider = '═' * 51;

  // ---- Aggregates -------------------------------------------------------
  var totalModels = 0;
  var dieselCount = 0;
  var hybridCount = 0;
  var evCount = 0;
  var turboCount = 0;
  var totalPids = 0;

  String? mostModel;
  var mostPids = -1;
  String? fewestModel;
  var fewestPids = 1 << 30;

  final zeroPidModels = <String>[];
  final lowPidModels = <String>[];
  final mafAndMapModels = <String>[];
  final orphanDownstreamModels = <String>[];

  // ---- Per-brand / per-model report ------------------------------------
  for (final brand in VehicleDatabase.brands) {
    print('');
    print(divider);
    print('${brand.name.toUpperCase()} (${brand.models.length} models)');
    print(divider);

    for (final model in brand.models) {
      totalModels++;

      final pids = [...model.standardPidCodes]..sort();
      final manuf = model.manufacturerParameterNames;
      totalPids += pids.length;

      final fullName = '${brand.name} ${model.name}';
      if (pids.length > mostPids) {
        mostPids = pids.length;
        mostModel = fullName;
      }
      if (pids.length < fewestPids) {
        fewestPids = pids.length;
        fewestModel = fullName;
      }

      // Category tallies (a model can fall into more than one).
      if (manuf.any(dieselParams.contains)) dieselCount++;
      if (manuf.any(hybridParams.contains)) hybridCount++;
      if (manuf.any(evParams.contains)) evCount++;
      if (manuf.contains(turboParam)) turboCount++;

      // Issue detection.
      if (pids.isEmpty) zeroPidModels.add(fullName);
      if (pids.isNotEmpty && pids.length < 5) lowPidModels.add(fullName);
      if (pids.contains(0x10) && pids.contains(0x0B)) {
        mafAndMapModels.add(fullName);
      }
      if (pids.contains(0x15) && !pids.contains(0x14)) {
        orphanDownstreamModels.add(fullName);
      }

      // Print the model block.
      final yearLabel = model.years.isEmpty
          ? 'n/a'
          : '${model.years.first}-${model.years.last}';
      print('');
      print('  📋 ${model.name} ($yearLabel) '
          '[${model.engineType.toUpperCase()}]');
      print('     Standard PIDs (${pids.length}):');
      if (pids.isEmpty) {
        print('       — none —');
      } else {
        for (final pid in pids) {
          print('       ✅ ${hex(pid)} — ${pidLabel(pid)}');
        }
      }
      print('     Manufacturer-Specific (${manuf.length}):');
      if (manuf.isEmpty) {
        print('       — none —');
      } else {
        for (final name in manuf) {
          print('       🔧 $name');
        }
      }
    }
  }

  // ---- Summary ----------------------------------------------------------
  final avg =
      totalModels == 0 ? 0.0 : totalPids / totalModels;

  print('');
  print(divider);
  print('SUMMARY');
  print(divider);
  print('  Total brands:            ${VehicleDatabase.brands.length}');
  print('  Total models:            $totalModels');
  print('  Models with diesel params:  $dieselCount');
  print('  Models with hybrid params:  $hybridCount');
  print('  Models with EV params:      $evCount');
  print('  Models with turbo params:   $turboCount');
  print('  Most PIDs:   $mostModel with $mostPids PIDs');
  print('  Fewest PIDs: $fewestModel with $fewestPids PIDs');
  print('  Average PIDs per model:  ${avg.toStringAsFixed(1)}');

  // ---- Potential issues -------------------------------------------------
  print('');
  print(divider);
  print('POTENTIAL ISSUES');
  print(divider);

  print('');
  print('  ⚠️  Models with 0 standard PIDs (EV only):');
  if (zeroPidModels.isEmpty) {
    print('       — none —');
  } else {
    for (final m in zeroPidModels) {
      print('       • $m');
    }
  }

  print('');
  print('  ⚠️  Models with fewer than 5 standard PIDs (very limited):');
  if (lowPidModels.isEmpty) {
    print('       — none —');
  } else {
    for (final m in lowPidModels) {
      print('       • $m');
    }
  }

  print('');
  print('  ⚠️  Models with BOTH MAF (0x10) and MAP (0x0B):');
  print('       (common on modern turbo engines — review, not always wrong)');
  if (mafAndMapModels.isEmpty) {
    print('       — none —');
  } else {
    for (final m in mafAndMapModels) {
      print('       • $m');
    }
  }

  print('');
  print('  ⚠️  Models with O2 Downstream (0x15) but NO O2 Upstream (0x14):');
  print('       (physically impossible — flag as data error)');
  if (orphanDownstreamModels.isEmpty) {
    print('       — none —');
  } else {
    for (final m in orphanDownstreamModels) {
      print('       • $m  <<< DATA ERROR');
    }
  }

  print('');
  print(divider);
  print('END OF REPORT');
  print(divider);
}
