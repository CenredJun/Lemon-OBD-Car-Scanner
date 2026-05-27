import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vehicle_database.dart';
import '../main.dart';
import '../models/vehicle_profile.dart';
import '../providers/obd_provider.dart';
import '../providers/vehicle_provider.dart';
import '../utils/obd_commands.dart';
import '../widgets/connection_status_widget.dart';

/// First screen of the app: pick a vehicle. A single centered card with
/// three dependent dropdowns (brand → model → year) replaces the old
/// multi-screen brand/model flow. Shown before the dashboard and before any
/// ELM327 connection is required.
class BrandSelectionScreen extends StatefulWidget {
  const BrandSelectionScreen({super.key});

  @override
  State<BrandSelectionScreen> createState() => _BrandSelectionScreenState();
}

class _BrandSelectionScreenState extends State<BrandSelectionScreen> {
  static const _bg = Color(0xFF1A1A1A);
  static const _accent = Color(0xFFFF8C00);
  static const _card = Color(0xFF222222);
  static const _fieldBg = Color(0xFF1A1A1A);
  static const _menuBg = Color(0xFF2A2A2A);
  static const _inactiveBorder = Color(0xFF333333);

  VehicleBrand? _brand;
  VehicleModel? _model;
  int? _year;

  bool get _canContinue =>
      _brand != null && _model != null && _year != null;

  @override
  Widget build(BuildContext context) {
    final brands = VehicleDatabase.brands;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(''),
        actions: const [ConnectionStatusWidget()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Header ------------------------------------------
                  const Text(
                    '🍋  Lemon OBD Car Scanner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select your vehicle to begin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // ---- Selection card ----------------------------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accent.withOpacity(0.6)),
                    ),
                    child: Column(
                      children: [
                        _dropdown<VehicleBrand>(
                          label: 'Car Brand',
                          hint: 'Select brand...',
                          value: _brand,
                          enabled: true,
                          options: [
                            for (final b in brands) _Opt(b, b.name),
                          ],
                          onChanged: (b) => setState(() {
                            _brand = b;
                            _model = null;
                            _year = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        _dropdown<VehicleModel>(
                          label: 'Model',
                          hint: 'Select model...',
                          value: _model,
                          enabled: _brand != null,
                          options: [
                            for (final m in _brand?.models ?? const [])
                              _Opt(m, '${m.name}  (${m.yearRangeLabel})'),
                          ],
                          onChanged: (m) => setState(() {
                            _model = m;
                            _year = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        _dropdown<int>(
                          label: 'Year',
                          hint: 'Select year...',
                          value: _year,
                          enabled: _model != null,
                          options: [
                            for (final y in _yearsDescending())
                              _Opt(y, '$y'),
                          ],
                          onChanged: (y) => setState(() => _year = y),
                        ),
                        const SizedBox(height: 24),
                        _continueButton(),
                      ],
                    ),
                  ),

                  // ---- "or" divider ------------------------------------
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(color: _inactiveBorder, thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: _inactiveBorder, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ---- Demo mode ---------------------------------------
                  TextButton.icon(
                    onPressed: () => _showDemoDialog(context),
                    icon: const Icon(Icons.play_circle_outline,
                        color: _accent),
                    label: const Text(
                      'Try Demo Mode',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Years for the selected model, newest first.
  List<int> _yearsDescending() {
    final years = _model?.years;
    if (years == null) return const [];
    return years.reversed.toList(growable: false);
  }

  // --------------------------------------------------------------------
  // Widgets
  // --------------------------------------------------------------------

  Widget _continueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF3A3A3A),
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: _canContinue ? _onContinue : null,
        child: const Text('Continue'),
      ),
    );
  }

  /// Generic dark-themed dropdown used for brand / model / year.
  Widget _dropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<_Opt<T>> options,
    required ValueChanged<T?> onChanged,
    required bool enabled,
  }) {
    final field = DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: _menuBg,
      iconEnabledColor: _accent,
      iconDisabledColor: _accent,
      borderRadius: BorderRadius.circular(10),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      hint: Text(
        hint,
        style: const TextStyle(color: Colors.white38, fontSize: 14),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        floatingLabelStyle: const TextStyle(color: _accent),
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: value != null ? _accent : _inactiveBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _inactiveBorder),
        ),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem<T>(
            value: o.value,
            child: Text(
              o.label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
      ],
      // The chosen value, shown in the closed field, is amber + bold.
      selectedItemBuilder: (context) => [
        for (final o in options)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              o.label,
              style: const TextStyle(
                color: _accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );

    // Disabled dropdowns are dimmed per the design spec.
    return enabled ? field : Opacity(opacity: 0.4, child: field);
  }

  // --------------------------------------------------------------------
  // Actions
  // --------------------------------------------------------------------

  void _onContinue() {
    final brand = _brand!;
    final model = _model!;
    final year = _year!;

    final vehicleProvider = context.read<VehicleProvider>();
    final obdProvider = context.read<OBDProvider>();
    final navigator = Navigator.of(context);

    final profile = VehicleProfile.fromSelection(
      brand: brand,
      model: model,
      year: year,
    );

    vehicleProvider.selectVehicle(profile);
    obdProvider.applyVehicleProfile(profile);

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  /// Shows an explanatory bottom sheet and, on confirmation, starts Demo Mode.
  void _showDemoDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.science_outlined,
                      color: Colors.purpleAccent, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Demo Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Demo Mode simulates a real car connection with live '
                'sensor data so you can explore all features without an '
                'ELM327 adapter. No real vehicle connection is needed.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startDemo(context, sheetContext),
                      child: const Text('START DEMO'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startDemo(BuildContext context, BuildContext sheetContext) {
    final vehicleProvider = context.read<VehicleProvider>();
    final obdProvider = context.read<OBDProvider>();
    final navigator = Navigator.of(context);

    final demoProfile = VehicleProfile(
      brandName: 'Demo',
      modelName: 'Demo Vehicle',
      selectedYear: 2024,
      engineType: 'gasoline',
      supportedPidCodes: ObdCommands.supportedPids
          .map((p) => p.pid)
          .toList(growable: false),
      manufacturerParams: const [],
    );

    vehicleProvider.selectVehicle(demoProfile);
    obdProvider.applyVehicleProfile(demoProfile);
    obdProvider.startDemoMode();

    Navigator.of(sheetContext).pop();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }
}

/// A single dropdown option pairing a typed [value] with its display [label].
class _Opt<T> {
  final T value;
  final String label;
  const _Opt(this.value, this.label);
}
