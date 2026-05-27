# 🍋 Lemon OBD Car Scanner

A Flutter Android app that connects to an ELM327 WiFi OBD-II adapter and provides real-time vehicle diagnostics — with automatic ECU parameter detection.

## What makes it different

Most OBD-II apps guess which parameters your car supports using a static database. **Lemon OBD asks the car directly** — sending OBD-II bitmask requests (0x00, 0x20, 0x40, 0x60) that return a 32-bit map of exactly which PIDs the ECU supports. No guessing. No false data.

## Features

- **Auto PID Detection** — queries ECU bitmask on connection, detects exactly what your car supports
- **Live Dashboard** — animated circular gauges in priority order (RPM, Speed, Coolant, Load first)
- **Fault Code Scanner** — scan and clear stored + pending DTCs with 100+ code descriptions
- **Live Data + Charts** — 60-second time-series chart per sensor, synced with dashboard
- **Vehicle Database** — 14 brands, 121+ models (gasoline, diesel, hybrid, EV)
- **Demo Mode** — physics-based engine simulation across all 20 PIDs, no hardware needed

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x / Dart 3.x |
| State Management | Provider 6.x |
| Charts | fl_chart 0.68 |
| Hardware Comms | dart:io TCP Socket (raw WiFi to ELM327) |
| Build | Android Gradle Plugin 8.6, Kotlin 2.1.0 |
| Target | minSdk 21 (Android 5.0+) / targetSdk 36 |

## Hardware Required

- ELM327 WiFi OBD-II adapter (~$10 on Shopee/Lazada)
- Any Android phone (Android 5.0+)
- A car with an OBD-II port (all cars 1996+ US, 2001+ EU)

## Setup

```bash
git clone https://github.com/CenredJun/Lemon-OBD-Car-Scanner.git
cd Lemon-OBD-Car-Scanner
flutter pub get
flutter run
```

**To connect to real hardware:**
1. Plug ELM327 into your car's OBD-II port
2. Turn ignition ON
3. Connect your phone to the ELM327 WiFi network
4. Open the app → select your vehicle → tap CONNECT

## Real-World Validation

Tested on a **Mitsubishi Mirage G4 2022** — auto-detected 16 supported parameters live from the ECU including RPM, Coolant Temp, MAP, O2 sensors, Timing Advance, and more.

Fuel Level (0x2F) was correctly identified as **NOT supported** by this vehicle — confirmed by the ECU's own bitmask response.

## Architecture Notes

- **Raw TCP socket** — no third-party OBD library. ELM327 AT command protocol implemented from scratch
- **Single source of truth** — `_enabledPids` in OBDProvider is the only PID filter for both Dashboard and Live Data
- **StringBuffer + Completer** — handles TCP fragmentation by resolving only on ELM327's `>` prompt
- **3-strike blacklisting** — PIDs need 3 consecutive NO DATA responses before removal
- **Bitmask PID discovery** — 4 queries, 32-bit parse, persisted to SharedPreferences

## Portfolio

[cenredportfolio.bizguro.net/lemon-obd-car-scanner](https://cenredportfolio.bizguro.net/lemon-obd-car-scanner/)