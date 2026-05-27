import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/obd_data.dart';
import '../providers/obd_provider.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<OBDProvider>();
    final state = obd.connectionState;
    final demoMode = obd.isDemoMode;

    Color color;
    String label;
    Widget icon;

    if (demoMode && state == ObdConnectionState.connected) {
      color = Colors.purpleAccent;
      label = 'DEMO';
      icon = const Icon(Icons.science_outlined,
          color: Colors.purpleAccent, size: 16);
    } else if (state == ObdConnectionState.connected) {
      color = Colors.greenAccent;
      label = 'CONNECTED';
      icon = const Icon(Icons.wifi_tethering,
          color: Colors.greenAccent, size: 16);
    } else if (state == ObdConnectionState.connecting) {
      color = const Color(0xFFFF8C00);
      label = 'CONNECTING';
      icon = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
        ),
      );
    } else if (state == ObdConnectionState.error) {
      color = Colors.redAccent;
      label = 'ERROR';
      icon = const Icon(Icons.error_outline,
          color: Colors.redAccent, size: 16);
    } else {
      color = Colors.white38;
      label = 'DISCONNECTED';
      icon = const Icon(Icons.wifi_off,
          color: Colors.white38, size: 16);
    }

    return GestureDetector(
      onTap: () {
        if (demoMode) {
          // No real adapter to connect/disconnect while in Demo Mode.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF333333),
              content: Text(
                  'Exit Demo Mode in Settings to connect to a real adapter.'),
            ),
          );
        } else if (state == ObdConnectionState.connected) {
          obd.disconnect();
        } else {
          _attemptConnect(context, obd);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attemptConnect(
      BuildContext context, OBDProvider obd) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await obd.connect();
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text(obd.lastError ??
              'Could not connect. Make sure you are joined to the ELM327 WiFi network.'),
        ),
      );
    }
  }
}
