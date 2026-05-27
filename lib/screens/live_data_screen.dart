import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pid_info.dart';
import '../providers/obd_provider.dart';
import '../utils/obd_commands.dart';
import '../widgets/connection_status_widget.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  int? _selectedPid;

  @override
  void initState() {
    super.initState();
    _selectedPid = ObdCommands.pidRpm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Data'),
        actions: const [ConnectionStatusWidget()],
      ),
      body: Consumer<OBDProvider>(
        builder: (context, obd, _) {
          final selectedInfo = _selectedPid == null
              ? null
              : ObdCommands.findPid(_selectedPid!);
          // SINGLE SOURCE OF TRUTH: show exactly the PIDs enabled in the
          // provider — identical set to the Dashboard.
          final pids = ObdCommands.supportedPids
              .where((p) => obd.isPidEnabled(p.pid))
              .toList();
          // Same priority order as the Dashboard so rows line up with gauges.
          pids.sort((a, b) => ObdCommands.comparePidPriority(a.pid, b.pid));
          final manufacturerParams = obd.manufacturerParams;
          return Column(
            children: [
              SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildChart(obd, selectedInfo),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2C)),
              Expanded(
                child: ListView(
                  children: [
                    _buildDetectionChip(obd),
                    if (pids.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No standard OBD-II PIDs for this vehicle.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    for (final pid in pids) ...[
                      _buildRow(obd, pid),
                      const Divider(
                          height: 1, color: Color(0xFF2C2C2C)),
                    ],
                    if (manufacturerParams.isNotEmpty)
                      _ManufacturerSection(params: manufacturerParams),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Small status chip shown above the PID list explaining whether the PIDs
  /// shown were auto-detected from the vehicle or come from the database.
  Widget _buildDetectionChip(OBDProvider obd) {
    if (obd.isDemoMode) return const SizedBox.shrink();

    IconData icon;
    Widget leading;
    String text;
    Color color;

    if (obd.isDetectingPids) {
      color = const Color(0xFFFF8C00);
      text = 'Detecting vehicle parameters...';
      leading = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
        ),
      );
    } else if (obd.pidDetectionDone) {
      color = Colors.green;
      icon = Icons.verified;
      text =
          '${obd.detectedPids.length} parameters auto-detected from vehicle';
      leading = Icon(icon, color: color, size: 14);
    } else if (obd.isConnected) {
      color = const Color(0xFFFF8C00);
      icon = Icons.storage;
      text = 'Showing parameters from vehicle database';
      leading = Icon(icon, color: color, size: 14);
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(OBDProvider obd, PidInfo pid) {
    final stats = obd.statsFor(pid.pid);
    final unsupported = obd.isPidUnsupported(pid.pid);
    final enabled = obd.isPidEnabled(pid.pid);
    final isSelected = _selectedPid == pid.pid;

    return Material(
      color: isSelected
          ? const Color(0xFF2A2118)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPid = pid.pid),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '0x${pid.hexCode}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFFF8C00),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pid.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unsupported
                          ? 'PID not supported'
                          : (stats.hasData
                              ? '${stats.current.toStringAsFixed(1)} ${pid.unit}'
                              : '— ${pid.unit}'),
                      style: TextStyle(
                        color: unsupported
                            ? Colors.redAccent
                            : Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeColor: const Color(0xFFFF8C00),
                onChanged: (v) =>
                    obd.setPidEnabled(pid.pid, v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(OBDProvider obd, PidInfo? pid) {
    if (pid == null) {
      return const Center(
        child: Text('Select a PID',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final history = obd.historyFor(pid.pid).values;
    if (history.isEmpty) {
      return Center(
        child: Text(
          obd.isPidUnsupported(pid.pid)
              ? '${pid.name}: PID not supported'
              : 'No data for ${pid.name} yet.',
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }

    final firstTs = history.first.timestamp.millisecondsSinceEpoch;
    final spots = history
        .map((v) => FlSpot(
              (v.timestamp.millisecondsSinceEpoch - firstTs) / 1000.0,
              v.value,
            ))
        .toList();
    final maxX = spots.last.x;
    final minX = (maxX - 60.0).clamp(0.0, double.infinity);

    return LineChart(
      LineChartData(
        backgroundColor: const Color(0xFF1A1A1A),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFF2C2C2C), strokeWidth: 1),
          getDrawingVerticalLine: (_) => const FlLine(
              color: Color(0xFF2C2C2C), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 10,
              getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(0)}s',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFF2C2C2C)),
        ),
        minX: minX,
        maxX: maxX < 1 ? 1 : maxX,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFFF8C00),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFF8C00).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom section of the Live Data list showing manufacturer-specific
/// parameters as greyed-out, non-pollable cards.
class _ManufacturerSection extends StatelessWidget {
  final List<String> params;
  const _ManufacturerSection({required this.params});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(
            'MANUFACTURER-SPECIFIC',
            style: TextStyle(
              color: Color(0xFFFF8C00),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final name in params)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C2C2C)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    color: Colors.white24, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Requires OEM scanner',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
