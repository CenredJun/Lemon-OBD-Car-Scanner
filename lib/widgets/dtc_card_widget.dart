import 'package:flutter/material.dart';

import '../models/dtc_model.dart';

class DtcCardWidget extends StatelessWidget {
  final Dtc dtc;
  const DtcCardWidget({super.key, required this.dtc});

  Color get _accent {
    switch (dtc.systemLetter) {
      case 'P':
        return const Color(0xFFFF8C00);
      case 'C':
        return Colors.cyanAccent;
      case 'B':
        return Colors.amberAccent;
      case 'U':
        return Colors.purpleAccent;
      default:
        return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _accent, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dtc.code,
              style: TextStyle(
                color: _accent,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dtc.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dtc.systemName} • ${dtc.status.name.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 0.5,
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
