import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/obd_data.dart';
import '../providers/obd_provider.dart';
import '../utils/obd_commands.dart';
import '../widgets/connection_status_widget.dart';
import '../widgets/gauge_widget.dart';
import 'vehicle_info_bar_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          ConnectionStatusWidget(),
        ],
      ),
      body: Consumer<OBDProvider>(
        builder: (context, obd, _) {
          return Column(
            children: [
              const VehicleInfoBar(),
              if (obd.isDemoMode) const _DemoWatermark(),
              const _PidDetectionBanner(),
              Expanded(
                child: obd.connectionState !=
                        ObdConnectionState.connected
                    ? _DisconnectedView(state: obd.connectionState)
                    : _buildConnectedView(obd),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectedView(OBDProvider obd) {
    // SINGLE SOURCE OF TRUTH: the PIDs shown are exactly those enabled in the
    // provider (auto-detected from the car, vehicle database, or demo mode).
    final enabledPids = ObdCommands.supportedPids
        .where((pid) => obd.isPidEnabled(pid.pid))
        .toList();
    // Same priority order as the Live Data screen so the two stay aligned.
    enabledPids.sort(
        (a, b) => ObdCommands.comparePidPriority(a.pid, b.pid));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final pid in enabledPids) _buildGauge(obd, pid.pid),
          ],
        ),
        if (obd.manufacturerParams.isNotEmpty)
          _ManufacturerParamsSection(params: obd.manufacturerParams),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton.icon(
            onPressed: obd.resetMinMax,
            icon: const Icon(Icons.refresh),
            label: const Text('RESET MIN/MAX'),
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(OBDProvider obd, int pid) {
    final info = ObdCommands.findPid(pid)!;
    final stats = obd.statsFor(pid);
    return GaugeWidget(
      label: info.name,
      unit: info.unit,
      value: stats.current,
      minValue: info.minValue,
      maxValue: info.maxValue,
      recordedMin: stats.displayMin,
      recordedMax: stats.displayMax,
      hasData: stats.hasData,
    );
  }
}

/// Subtle banner shown on the dashboard while Demo Mode is active.
class _DemoWatermark extends StatelessWidget {
  const _DemoWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.science_outlined,
              color: Colors.purpleAccent, size: 14),
          SizedBox(width: 6),
          Text(
            'DEMO MODE — Simulated Data',
            style: TextStyle(
              color: Colors.purpleAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner shown beneath the vehicle info bar while the app is auto-detecting
/// supported PIDs, and briefly afterwards to confirm the result.
class _PidDetectionBanner extends StatefulWidget {
  const _PidDetectionBanner();

  @override
  State<_PidDetectionBanner> createState() => _PidDetectionBannerState();
}

class _PidDetectionBannerState extends State<_PidDetectionBanner> {
  Timer? _hideTimer;
  bool _showSuccess = false;
  bool _wasDetecting = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<OBDProvider>();

    // Demo Mode never runs real detection — show nothing.
    if (obd.isDemoMode) return const SizedBox.shrink();

    if (obd.isDetectingPids) {
      _wasDetecting = true;
      _showSuccess = false;
      return _banner(
        color: const Color(0xFFFF8C00),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Scanning vehicle supported parameters...',
              style: TextStyle(color: Color(0xFFFF8C00), fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Detection just finished this build cycle — show success for 3 seconds.
    if (_wasDetecting) {
      _wasDetecting = false;
      if (obd.pidDetectionDone) {
        _showSuccess = true;
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccess = false);
        });
      }
    }

    if (_showSuccess && obd.pidDetectionDone) {
      return _banner(
        color: Colors.green,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 14),
            const SizedBox(width: 8),
            Text(
              'Detected ${obd.detectedPids.length} supported '
              'parameters from your vehicle',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _banner({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// Informational list of manufacturer-specific parameters that the selected
/// vehicle exposes but which cannot be read over generic OBD-II.
class _ManufacturerParamsSection extends StatelessWidget {
  final List<String> params;
  const _ManufacturerParamsSection({required this.params});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3320)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber,
                  color: Color(0xFFFF8C00), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The following parameters require a '
                  'manufacturer-specific scanner:',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final name in params)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Text('•  ',
                      style: TextStyle(color: Colors.white38)),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  final ObdConnectionState state;
  const _DisconnectedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final obd = context.read<OBDProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final connecting = state == ObdConnectionState.connecting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connecting ? Icons.wifi_tethering : Icons.wifi_off,
              size: 64,
              color: connecting
                  ? const Color(0xFFFF8C00)
                  : Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              connecting ? 'Connecting...' : 'Not Connected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your phone is connected to the ELM327 WiFi network, then tap below to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            if (connecting)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFF8C00)),
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.power),
                label: const Text('CONNECT'),
                onPressed: () async {
                  final ok = await obd.connect();
                  if (!ok) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade900,
                        content: Text(obd.lastError ??
                            'Connection failed.'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
