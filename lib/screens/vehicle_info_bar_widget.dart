import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vehicle_database.dart';
import '../providers/vehicle_provider.dart';
import 'brand_selection_screen.dart';
import 'model_selection_screen.dart';

/// Compact bar shown at the top of the Dashboard displaying the currently
/// selected vehicle with a quick "Change" action.
class VehicleInfoBar extends StatelessWidget {
  const VehicleInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<VehicleProvider>().selectedVehicle;
    if (profile == null) return const SizedBox.shrink();

    final brand = VehicleDatabase.findBrand(profile.brandName);
    final emoji = brand?.logoEmoji ?? '\u{1F697}';
    final badgeColor = engineTypeColor(profile.engineType);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.engineType.toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Color(0xFFFF8C00)),
              foregroundColor: const Color(0xFFFF8C00),
            ),
            icon: const Icon(Icons.directions_car, size: 16),
            label: const Text('CHANGE'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BrandSelectionScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
