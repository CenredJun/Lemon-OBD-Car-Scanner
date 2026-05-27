import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dtc_provider.dart';
import '../providers/obd_provider.dart';
import '../widgets/connection_status_widget.dart';
import '../widgets/dtc_card_widget.dart';

class FaultCodesScreen extends StatelessWidget {
  const FaultCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fault Codes'),
        actions: const [ConnectionStatusWidget()],
      ),
      body: Consumer2<DTCProvider, OBDProvider>(
        builder: (context, dtc, obd, _) {
          final messenger = ScaffoldMessenger.of(context);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: dtc.isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(dtc.isScanning ? 'SCANNING' : 'SCAN DTCs'),
                        onPressed: dtc.isScanning || !obd.isConnected
                            ? null
                            : () async {
                                await dtc.scan();
                                if (dtc.lastError != null) {
                                  messenger.showSnackBar(SnackBar(
                                    backgroundColor: Colors.red.shade900,
                                    content: Text(dtc.lastError!),
                                  ));
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                              color: Colors.redAccent),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(dtc.isClearing
                            ? 'CLEARING'
                            : 'CLEAR DTCs'),
                        onPressed: dtc.isClearing ||
                                !obd.isConnected ||
                                (dtc.storedCodes.isEmpty &&
                                    dtc.pendingCodes.isEmpty)
                            ? null
                            : () => _confirmClear(
                                context, dtc, messenger),
                      ),
                    ),
                  ],
                ),
              ),
              if (dtc.lastScanTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Last scan: ${_fmtTime(dtc.lastScanTime!)}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ),
              Expanded(
                child: _buildList(dtc),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(DTCProvider dtc) {
    if (dtc.storedCodes.isEmpty && dtc.pendingCodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: Colors.greenAccent),
            const SizedBox(height: 12),
            Text(
              dtc.lastScanTime == null
                  ? 'No scan performed yet.\nTap SCAN DTCs to begin.'
                  : 'No fault codes detected.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }
    return ListView(
      children: [
        if (dtc.storedCodes.isNotEmpty) ...[
          const _SectionHeader(
              title: 'STORED CODES', color: Colors.redAccent),
          ...dtc.storedCodes.map((c) => DtcCardWidget(dtc: c)),
        ],
        if (dtc.pendingCodes.isNotEmpty) ...[
          const _SectionHeader(
              title: 'PENDING CODES', color: Color(0xFFFF8C00)),
          ...dtc.pendingCodes.map((c) => DtcCardWidget(dtc: c)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  void _confirmClear(BuildContext context, DTCProvider dtc,
      ScaffoldMessengerState messenger) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Clear all DTCs?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear all stored and pending fault codes from the ECU and reset readiness monitors. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await dtc.clearAll();
              messenger.showSnackBar(SnackBar(
                backgroundColor:
                    ok ? Colors.green.shade900 : Colors.red.shade900,
                content: Text(ok
                    ? 'DTCs cleared successfully.'
                    : (dtc.lastError ?? 'Clear failed.')),
              ));
            },
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
