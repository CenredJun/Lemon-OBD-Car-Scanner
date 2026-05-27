import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/obd_data.dart';
import '../providers/obd_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/connection_status_widget.dart';
import 'brand_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late int _intervalMs;
  late String _protocol;

  static const _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    final s = context.read<OBDProvider>().settings;
    _ipController = TextEditingController(text: s.ipAddress);
    _portController =
        TextEditingController(text: s.port.toString());
    _intervalMs = s.pollingIntervalMs;
    _protocol = s.protocol;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;
    if (ip.isEmpty || port <= 0 || port > 65535) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade900,
        content: const Text('Please enter a valid IP and port (1-65535).'),
      ));
      return;
    }
    final provider = context.read<OBDProvider>();
    await provider.updateSettings(ObdSettings(
      ipAddress: ip,
      port: port,
      pollingIntervalMs: _intervalMs,
      protocol: _protocol,
    ));
    messenger.showSnackBar(const SnackBar(
      backgroundColor: Color(0xFF333333),
      content: Text('Settings saved.'),
    ));
  }

  /// Re-runs OBD-II supported-PID detection, showing a blocking progress
  /// dialog and reporting the result via a SnackBar.
  Future<void> _rescanPids() async {
    final obd = context.read<OBDProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF222222),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
              ),
            ),
            SizedBox(width: 16),
            Flexible(
              child: Text(
                'Scanning vehicle parameters...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    await obd.rescanSupportedPids();

    if (!mounted) return;
    navigator.pop(); // dismiss the progress dialog

    final count = obd.detectedPids.length;
    if (count > 0) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF333333),
        content: Text(
            'Detected $count parameters supported by your vehicle'),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade900,
        content: const Text(
            'Could not detect parameters. Using vehicle database.'),
      ));
    }
  }

  void _exitDemoMode() {
    final obd = context.read<OBDProvider>();
    final navigator = Navigator.of(context);
    obd.stopDemoMode();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BrandSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [ConnectionStatusWidget()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (context.watch<OBDProvider>().isDemoMode) ...[
            _DemoModeCard(onExit: _exitDemoMode),
            const SizedBox(height: 16),
          ],
          const _SectionTitle('VEHICLE'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final profile =
                        context.watch<VehicleProvider>().selectedVehicle;
                    return Text(
                      profile == null
                          ? 'No vehicle selected'
                          : 'Current: ${profile.displayName}',
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions_car),
                    label: const Text('CHANGE VEHICLE'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BrandSelectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('CONNECTION'),
          _Card(
            child: Column(
              children: [
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.text,
                  decoration: _input('ELM327 IP address',
                      hint: '192.168.0.10'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration:
                      _input('Port', hint: '35000'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('POLLING'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Polling interval: $_intervalMs ms',
                  style: const TextStyle(color: Colors.white),
                ),
                Slider(
                  min: 250,
                  max: 2000,
                  divisions: 35,
                  activeColor: const Color(0xFFFF8C00),
                  value: _intervalMs.toDouble(),
                  label: '$_intervalMs ms',
                  onChanged: (v) => setState(
                      () => _intervalMs = (v / 50).round() * 50),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('PROTOCOL'),
          _Card(
            child: DropdownButtonFormField<String>(
              value: _protocol,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: _input('OBD-II Protocol'),
              items: ObdSettings.protocolCommands.keys
                  .map((k) =>
                      DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _protocol = v ?? 'Auto'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('SAVE SETTINGS'),
                  onPressed: _save,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.power),
                  label: Text(
                    context.watch<OBDProvider>().isConnected
                        ? 'RECONNECT'
                        : 'CONNECT',
                  ),
                  onPressed: () async {
                    await _save();
                    final obd = context.read<OBDProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await obd.connect();
                    if (!ok) {
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: Colors.red.shade900,
                        content: Text(
                            obd.lastError ?? 'Connection failed.'),
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final obd = context.watch<OBDProvider>();
              if (!obd.isConnected || obd.isDemoMode) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.radar),
                    label: const Text('RE-SCAN VEHICLE PARAMETERS'),
                    onPressed:
                        obd.isDetectingPids ? null : _rescanPids,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const _SectionTitle('ABOUT'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lemon OBD Car Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version $_appVersion',
                  style:
                      const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lemon OBD Car Scanner — a professional-grade vehicle diagnostic tool. Connect your ELM327 WiFi adapter to scan live engine data, read and clear fault codes, and monitor your vehicle in real time.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFF8C00)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFF8C00),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Highlighted card shown at the top of Settings while Demo Mode is active.
class _DemoModeCard extends StatelessWidget {
  final VoidCallback onExit;
  const _DemoModeCard({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Demo Mode Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You are viewing simulated vehicle data',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.purpleAccent),
                foregroundColor: Colors.purpleAccent,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('EXIT DEMO MODE'),
              onPressed: onExit,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: child,
    );
  }
}
