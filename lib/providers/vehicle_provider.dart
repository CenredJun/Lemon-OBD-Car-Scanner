import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle_profile.dart';

/// Holds the user's selected vehicle and persists it across app restarts.
class VehicleProvider extends ChangeNotifier {
  static const String _prefsKey = 'vehicle.profile';

  VehicleProfile? _selectedVehicle;
  bool _loaded = false;

  /// Currently selected vehicle, or `null` if none chosen yet.
  VehicleProfile? get selectedVehicle => _selectedVehicle;

  /// `true` once the persisted selection has been read from disk.
  bool get isLoaded => _loaded;

  bool get hasVehicleSelected => _selectedVehicle != null;

  /// Loads any persisted selection from [SharedPreferences].
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _selectedVehicle = VehicleProfile.fromJson(json);
      }
    } catch (_) {
      // Corrupt / incompatible stored data — start fresh.
      _selectedVehicle = null;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Selects [profile] and persists it.
  Future<void> selectVehicle(VehicleProfile profile) async {
    _selectedVehicle = profile;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
  }

  /// Clears the current selection and the persisted value.
  Future<void> clearVehicle() async {
    _selectedVehicle = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
