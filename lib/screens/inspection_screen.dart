import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inspection_data.dart';
import '../providers/inspection_provider.dart';
import '../providers/obd_provider.dart';
import '../providers/vehicle_provider.dart';
import '../utils/dtc_descriptions.dart';
import '../utils/obd_commands.dart';
import '../widgets/connection_status_widget.dart';

const _accent = Color(0xFFFF8C00);
const _card = Color(0xFF222222);

/// One-tap vehicle inspection: battery voltage, VIN, readiness monitors
/// and freeze frame. Useful when checking a used car.
class InspectionScreen extends StatelessWidget {
  const InspectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection'),
        actions: const [ConnectionStatusWidget()],
      ),
      body: Consumer2<InspectionProvider, OBDProvider>(
        builder: (context, insp, obd, _) {
          final messenger = ScaffoldMessenger.of(context);
          final vehicle = context.watch<VehicleProvider>().selectedVehicle;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ElevatedButton.icon(
                icon: insp.isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(insp.isRunning
                    ? 'INSPECTING…'
                    : 'RUN INSPECTION'),
                onPressed: insp.isRunning || !obd.isConnected
                    ? null
                    : () async {
                        await insp.run();
                        if (insp.lastError != null) {
                          messenger.showSnackBar(SnackBar(
                            backgroundColor: Colors.red.shade900,
                            content: Text(insp.lastError!),
                          ));
                        }
                      },
              ),
              const SizedBox(height: 6),
              Text(
                insp.isRunning
                    ? insp.currentStep
                    : !obd.isConnected
                        ? 'Connect to your ELM327 first. For best results '
                            'turn the ignition ON (engine running is fine).'
                        : insp.lastRun == null
                            ? 'Reads battery voltage, VIN, emissions '
                                'readiness and freeze frame data.'
                            : 'Last inspection: ${_fmtTime(insp.lastRun!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              if (insp.hasResults && !insp.isRunning) ...[
                _MileageCard(insp: insp),
                _BatteryCard(voltage: insp.batteryVoltage),
                _VinCard(vin: insp.vin, selectedYear: vehicle?.selectedYear),
                _ReadinessCard(status: insp.readiness),
                _FreezeFrameCard(
                  frame: insp.freezeFrame,
                  brand: vehicle?.brandName,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

// ---------------------------------------------------------------------------
// Shared card shell
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _Row(this.label, this.value, {this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  const _Note(this.text, {this.color = Colors.white38});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

// ---------------------------------------------------------------------------
// Mileage check
// ---------------------------------------------------------------------------

enum _Level { ok, caution, danger }

class _Finding {
  final _Level level;
  final String text;
  const _Finding(this.level, this.text);
}

String _km(double v, {int decimals = 0}) {
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

/// Compares the odometer reading on the instrument cluster (typed in by
/// the user) with what the car's computers report.
class _MileageCard extends StatefulWidget {
  final InspectionProvider insp;
  const _MileageCard({required this.insp});

  @override
  State<_MileageCard> createState() => _MileageCardState();
}

class _MileageCardState extends State<_MileageCard> {
  final _controller = TextEditingController();
  bool _miles = false;

  static const double _kmPerMile = 1.609344;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final cleaned = _controller.text.replaceAll(RegExp(r'[,\s]'), '');
    final v = double.tryParse(cleaned);
    widget.insp.setDashboardKm(
        v == null || v < 0 ? null : (_miles ? v * _kmPerMile : v));
    FocusScope.of(context).unfocus();
  }

  List<_Finding> _findings() {
    final insp = widget.insp;
    final dash = insp.dashboardKm;
    final ecu = insp.ecuOdometerKm;
    final since = insp.distanceSinceClearedKm;
    final withMil = insp.distanceWithMilKm;
    final perm = insp.permanentCodeCount;
    final readiness = insp.readiness;
    final out = <_Finding>[];

    if (ecu != null && dash != null) {
      // Cluster and ECU can differ slightly; allow 50 km or 1 %.
      final tolerance = ecu * 0.01 < 50 ? 50.0 : ecu * 0.01;
      final diff = ecu - dash;
      if (diff.abs() <= tolerance) {
        out.add(const _Finding(_Level.ok,
            'Dashboard matches the ECU total mileage.'));
      } else if (diff > 0) {
        out.add(_Finding(_Level.danger,
            'ECU shows ${_km(diff)} km MORE than the dashboard. '
            'Strong sign the odometer was rolled back.'));
      } else {
        out.add(_Finding(_Level.caution,
            'Dashboard shows ${_km(-diff)} km more than the ECU. The '
            'engine computer or instrument cluster may have been '
            'replaced. Ask for repair records.'));
      }
    }

    if (dash != null && since != null && since > dash + 1) {
      out.add(_Finding(_Level.danger,
          'The car has driven ${_km(since)} km since codes were last '
          'cleared — more than the dashboard total. That is impossible '
          'on a genuine odometer.'));
    }
    if (dash != null && withMil != null && withMil > dash + 1) {
      out.add(_Finding(_Level.danger,
          'Distance driven with the check engine light on '
          '(${_km(withMil)} km) is more than the dashboard total.'));
    }
    if (since != null && since < 300) {
      out.add(_Finding(_Level.caution,
          'Fault codes were cleared only ${_km(since)} km ago.'));
    }
    if (readiness != null && readiness.incompleteCount >= 3) {
      out.add(const _Finding(_Level.caution,
          'Several readiness self-tests are incomplete — codes or the '
          'battery were reset recently.'));
    }
    if (perm != null && perm > 0) {
      out.add(_Finding(_Level.caution,
          '$perm permanent fault code(s) — a fault existed recently even '
          'if the check engine light is off.'));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final insp = widget.insp;
    final ecu = insp.ecuOdometerKm;
    final dash = insp.dashboardKm;
    final findings = _findings();

    return _Section(
      icon: Icons.speed,
      title: 'Mileage Check',
      children: [
        const Text(
          'Total mileage (from the car\'s computer)',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          ecu == null ? 'Not reported' : '${_km(ecu, decimals: 1)} km',
          style: TextStyle(
            color: ecu == null ? Colors.white38 : Colors.white,
            fontSize: ecu == null ? 18 : 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        if (ecu != null)
          Text(
            '${_km(ecu / _kmPerMile)} miles',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          )
        else
          const Text(
            'This car does not report its total mileage over standard '
            'OBD-II.',
            style: TextStyle(color: _accent, fontSize: 12),
          ),
        const Divider(color: Colors.white12, height: 22),
        const Text(
          'Optional — enter the dashboard reading to compare:',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _apply(),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'e.g. 65000',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('km'),
              selected: !_miles,
              onSelected: (_) => setState(() => _miles = false),
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('mi'),
              selected: _miles,
              onSelected: (_) => setState(() => _miles = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _apply,
            child: const Text('COMPARE'),
          ),
        ),
        const Divider(color: Colors.white12, height: 22),
        _Row('Dashboard', dash == null ? '—' : '${_km(dash)} km'),
        _Row(
          'ECU total mileage',
          ecu == null ? 'Not reported' : '${_km(ecu, decimals: 1)} km',
          valueColor: ecu == null ? Colors.white38 : Colors.white,
        ),
        if (insp.distanceSinceClearedKm != null)
          _Row('Since codes cleared',
              '${_km(insp.distanceSinceClearedKm!)} km'),
        if (insp.distanceWithMilKm != null)
          _Row('With check engine on',
              '${_km(insp.distanceWithMilKm!)} km'),
        if (ecu == null)
          const _Note(
            'This car does not report its total mileage over standard '
            'OBD-II, so the dashboard can\'t be verified directly. The '
            'clues below can still reveal tampering.',
            color: _accent,
          ),
        if (dash == null)
          const _Note('Enter the dashboard reading and tap COMPARE.')
        else if (findings.isEmpty)
          const _Note(
            'No red flags found in the data the car reports. Still check '
            'service records, oil-change stickers and LTO records.',
            color: Colors.greenAccent,
          )
        else
          for (final f in findings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    f.level == _Level.ok
                        ? Icons.check_circle
                        : f.level == _Level.danger
                            ? Icons.error
                            : Icons.warning_amber,
                    size: 16,
                    color: f.level == _Level.ok
                        ? Colors.greenAccent
                        : f.level == _Level.danger
                            ? Colors.redAccent
                            : _accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.text,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Battery
// ---------------------------------------------------------------------------

class _BatteryCard extends StatelessWidget {
  final double? voltage;
  const _BatteryCard({required this.voltage});

  @override
  Widget build(BuildContext context) {
    final v = voltage;
    if (v == null) {
      return const _Section(
        icon: Icons.battery_charging_full,
        title: 'Battery',
        children: [_Note('The adapter did not report a voltage.')],
      );
    }
    // Trucks such as some JAC models run a 24 V system.
    final is24 = v > 20;
    final n = is24 ? v / 2 : v;
    String status;
    Color color;
    if (n > 15.0) {
      status = 'Too high — check the alternator / regulator';
      color = Colors.redAccent;
    } else if (n >= 13.2) {
      status = 'Charging — alternator is working';
      color = Colors.greenAccent;
    } else if (n >= 12.4) {
      status = 'Good (engine off)';
      color = Colors.greenAccent;
    } else if (n >= 12.0) {
      status = 'Low — battery partly discharged';
      color = _accent;
    } else {
      status = 'Weak — charge or test the battery';
      color = Colors.redAccent;
    }
    return _Section(
      icon: Icons.battery_charging_full,
      title: 'Battery',
      children: [
        _Row('Voltage${is24 ? ' (24 V system)' : ''}',
            '${v.toStringAsFixed(1)} V',
            valueColor: color),
        _Note(status, color: color),
        const _Note('Engine running should read about 13.5–14.7 V '
            '(double for 24 V). Engine off: 12.4 V or more is healthy.'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// VIN
// ---------------------------------------------------------------------------

class _VinCard extends StatelessWidget {
  final String? vin;
  final int? selectedYear;
  const _VinCard({required this.vin, required this.selectedYear});

  /// Model year from VIN position 10 (30-year cycle; picks the most recent
  /// year that is not in the future). Not every non-US VIN encodes this.
  static int? _modelYear(String vin) {
    const codes = 'ABCDEFGHJKLMNPRSTVWXY123456789';
    final i = codes.indexOf(vin[9]);
    if (i < 0) return null;
    var year = 1980 + i;
    final maxYear = DateTime.now().year + 1;
    while (year + 30 <= maxYear) {
      year += 30;
    }
    return year;
  }

  @override
  Widget build(BuildContext context) {
    final v = vin;
    if (v == null) {
      return const _Section(
        icon: Icons.badge_outlined,
        title: 'Vehicle ID (VIN)',
        children: [
          _Note('This car did not report its VIN over OBD-II. Most cars '
              'from about 2005 onward do; older ones often don\'t. Check '
              'the plate on the dashboard or door pillar instead.'),
        ],
      );
    }
    final year = _modelYear(v);
    final mismatch =
        year != null && selectedYear != null && year != selectedYear;
    return _Section(
      icon: Icons.badge_outlined,
      title: 'Vehicle ID (VIN)',
      children: [
        SelectableText(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 2,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        _Row('Manufacturer code', v.substring(0, 3)),
        if (year != null) _Row('Model year (from VIN)', '$year'),
        if (mismatch)
          _Note(
            'Selected vehicle year is $selectedYear. Some Asian-market '
            'VINs don\'t encode the year, but if they should match, '
            'compare with the OR/CR papers.',
            color: _accent,
          ),
        const _Note('Compare this VIN with the vehicle\'s OR/CR and the '
            'chassis plate. A mismatch is a red flag.'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Readiness monitors
// ---------------------------------------------------------------------------

class _ReadinessCard extends StatelessWidget {
  final ReadinessStatus? status;
  const _ReadinessCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      return const _Section(
        icon: Icons.checklist,
        title: 'Emissions Readiness',
        children: [_Note('The car did not report readiness monitors.')],
      );
    }
    final allDone = s.incompleteCount == 0;
    return _Section(
      icon: Icons.checklist,
      title: 'Emissions Readiness',
      children: [
        _Row(
          'Check engine light',
          s.milOn ? 'ON' : 'OFF',
          valueColor: s.milOn ? Colors.redAccent : Colors.greenAccent,
        ),
        _Row('Stored emission codes', '${s.dtcCount}',
            valueColor:
                s.dtcCount > 0 ? Colors.redAccent : Colors.greenAccent),
        _Row('Engine type', s.isDiesel ? 'Diesel' : 'Gasoline'),
        _Row(
          'Monitors complete',
          '${s.completeCount} / ${s.monitors.length}',
          valueColor: allDone ? Colors.greenAccent : _accent,
        ),
        const Divider(color: Colors.white12, height: 18),
        for (final m in s.monitors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  m.complete
                      ? Icons.check_circle
                      : Icons.hourglass_bottom,
                  size: 16,
                  color: m.complete ? Colors.greenAccent : _accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.name,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
                Text(
                  m.complete ? 'Complete' : 'Not complete',
                  style: TextStyle(
                    color: m.complete ? Colors.greenAccent : _accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        _Note(
          allDone
              ? 'All self-tests have completed. No sign of recently '
                  'cleared codes.'
              : s.incompleteCount >= 3
                  ? 'Several self-tests are not complete. This usually '
                      'means codes were cleared or the battery was '
                      'disconnected recently. If buying, ask why.'
                  : 'Some self-tests are not complete yet. They finish '
                      'after a few days of normal driving.',
          color: allDone ? Colors.white38 : _accent,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Freeze frame
// ---------------------------------------------------------------------------

class _FreezeFrameCard extends StatelessWidget {
  final FreezeFrame? frame;
  final String? brand;
  const _FreezeFrameCard({required this.frame, required this.brand});

  @override
  Widget build(BuildContext context) {
    final f = frame;
    if (f == null) {
      return const _Section(
        icon: Icons.ac_unit,
        title: 'Freeze Frame',
        children: [
          _Note('No freeze frame stored. The ECU saves one when a fault '
              'code turns on the check engine light.'),
        ],
      );
    }
    final pids = f.values.keys.toList()..sort(ObdCommands.comparePidPriority);
    return _Section(
      icon: Icons.ac_unit,
      title: 'Freeze Frame',
      children: [
        _Row('Triggered by', f.dtc, valueColor: Colors.redAccent),
        _Note(DtcDescriptions.lookup(f.dtc, brand: brand),
            color: Colors.white70),
        const Divider(color: Colors.white12, height: 18),
        if (pids.isEmpty)
          const _Note('The ECU did not return any snapshot values.')
        else
          for (final pid in pids)
            _Row(
              ObdCommands.findPid(pid)?.name ?? 'PID $pid',
              '${f.values[pid]!.toStringAsFixed(_decimals(pid))} '
                  '${ObdCommands.findPid(pid)?.unit ?? ''}',
            ),
        const _Note('Engine conditions at the moment the fault was '
            'recorded.'),
      ],
    );
  }

  static int _decimals(int pid) {
    switch (pid) {
      case ObdCommands.pidRpm:
      case ObdCommands.pidSpeed:
      case ObdCommands.pidCoolantTemp:
      case ObdCommands.pidIntakeAirTemp:
      case ObdCommands.pidIntakeManifoldPressure:
        return 0;
      case ObdCommands.pidO2Sensor1Voltage:
      case ObdCommands.pidO2Sensor2Voltage:
        return 3;
      default:
        return 1;
    }
  }
}
