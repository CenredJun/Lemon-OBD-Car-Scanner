import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'providers/dtc_provider.dart';
import 'providers/obd_provider.dart';
import 'providers/vehicle_provider.dart';
import 'screens/brand_selection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/fault_codes_screen.dart';
import 'screens/live_data_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Obd2ScannerApp());
}

class Obd2ScannerApp extends StatelessWidget {
  const Obd2ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OBDProvider>(
          create: (_) => OBDProvider()..loadSettings(),
        ),
        ChangeNotifierProvider<VehicleProvider>(
          create: (_) => VehicleProvider()..load(),
        ),
        ChangeNotifierProxyProvider<OBDProvider, DTCProvider>(
          create: (ctx) => DTCProvider(ctx.read<OBDProvider>()),
          update: (_, obd, prev) => prev ?? DTCProvider(obd),
        ),
      ],
      child: MaterialApp(
        title: 'Lemon OBD Car Scanner',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _AppEntry(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const accent = Color(0xFFFF8C00);
    const bg = Color(0xFF1A1A1A);
    const surface = Color(0xFF222222);
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: surface,
        background: bg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, letterSpacing: 0.6),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: accent),
          foregroundColor: accent,
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, letterSpacing: 0.6),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: const Color(0xFF333333),
      ),
    );
  }
}

/// Decides the first screen: the brand picker when no vehicle has been
/// selected, otherwise the main app shell.
class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<VehicleProvider>();
    if (!vehicle.isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
          ),
        ),
      );
    }
    if (!vehicle.hasVehicleSelected) {
      return const BrandSelectionScreen();
    }
    return const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    FaultCodesScreen(),
    LiveDataScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load the PID set for the selected vehicle (covers the case where a
      // profile was restored from storage on launch).
      final profile = context.read<VehicleProvider>().selectedVehicle;
      if (profile != null) {
        context.read<OBDProvider>().applyVehicleProfile(profile);
      }
      // Some Android versions require location permission for WiFi scans;
      // request it once on first launch.
      await Permission.location.request();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber),
              label: 'Fault Codes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Live Data'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
