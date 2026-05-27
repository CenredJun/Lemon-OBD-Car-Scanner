/// Structured database of car brands, models and their supported OBD-II
/// parameters. Used by the vehicle selection flow to determine which PIDs
/// the dashboard / live data screens should poll and display.
///
/// PID support per model reflects real-world OBD-II Mode 01 behaviour:
/// only PIDs a model's ECU genuinely answers over standard OBD-II are
/// listed. Manufacturer-specific values (DPF soot, turbo boost, EV pack
/// data, …) are flagged separately because they are not pollable via
/// generic OBD-II.

/// A single diagnostic parameter a vehicle may support.
class VehicleParameter {
  final String name;
  final String category;

  /// Standard OBD-II PID code, or `null` when the parameter is
  /// manufacturer-specific / not pollable over generic OBD-II.
  final int? pid;
  final String unit;
  final String description;

  /// `true` = standard OBD-II, `false` = manufacturer-specific.
  final bool isStandard;

  const VehicleParameter({
    required this.name,
    required this.category,
    required this.pid,
    required this.unit,
    required this.description,
    required this.isStandard,
  });
}

/// A specific vehicle model belonging to a [VehicleBrand].
class VehicleModel {
  final String name;
  final List<int> years;

  /// 'gasoline', 'diesel', 'hybrid' or 'electric'.
  final String engineType;

  /// References into [VehicleDatabase.parameters].
  final List<String> supportedParameterIds;

  const VehicleModel({
    required this.name,
    required this.years,
    required this.engineType,
    required this.supportedParameterIds,
  });

  /// Resolves [supportedParameterIds] to concrete [VehicleParameter] objects.
  List<VehicleParameter> get parameters => supportedParameterIds
      .map((id) => VehicleDatabase.parameters[id])
      .whereType<VehicleParameter>()
      .toList(growable: false);

  /// Standard OBD-II PID codes this model supports.
  List<int> get standardPidCodes => parameters
      .where((p) => p.isStandard && p.pid != null)
      .map((p) => p.pid!)
      .toList(growable: false);

  /// Names of manufacturer-specific parameters this model supports.
  List<String> get manufacturerParameterNames => parameters
      .where((p) => !p.isStandard)
      .map((p) => p.name)
      .toList(growable: false);

  String get yearRangeLabel =>
      years.isEmpty ? '' : '${years.first} – ${years.last}';
}

/// A car manufacturer with a list of models.
class VehicleBrand {
  final String name;
  final String logoEmoji;
  final List<VehicleModel> models;

  const VehicleBrand({
    required this.name,
    required this.logoEmoji,
    required this.models,
  });
}

/// Inclusive year range helper.
List<int> _years(int start, int end) =>
    [for (var y = start; y <= end; y++) y];

// ---------------------------------------------------------------------------
// Standard OBD-II PID parameter-id sets (referenced by models).
//
// Naming maps to a real-world support tier rather than a brand, since the
// same tier is shared by many models across manufacturers:
//
//   _pidA   full NA gasoline: MAF, dual O2, barometric          (16 PIDs)
//   _pidA49 _pidA + accelerator pedal                           (17 PIDs)
//   _pidA49a _pidA49 + fuel pressure                            (18 PIDs)
//   _pidB   gasoline with MAF, no barometric                    (15 PIDs)
//   _pidB49 _pidB + accelerator pedal                           (16 PIDs)
//   _pidC   gasoline, no MAF, dual O2, no barometric            (14 PIDs)
//   _pidD   basic gasoline: no MAF, single O2                   (13 PIDs)
//   _pidE   small gasoline: MAP instead of MAF, single O2       (15 PIDs)
//   _pidF   turbo gasoline: MAP + MAF, dual O2                  (17 PIDs)
//   _pidF49 _pidF + accelerator pedal                           (18 PIDs)
//   _pidG   minimal/older ECU                                   ( 8 PIDs)
//   _pidDiesel       common-rail diesel with barometric         (11 PIDs)
//   _pidDieselNoBaro common-rail diesel, no barometric          (10 PIDs)
//   _pidTangHybrid   PHEV with minimal standard OBD             ( 7 PIDs)
//   _pidHybridMg     hybrid: MAF, single O2, no barometric      (14 PIDs)
//   _pidHybridGeely  hybrid: MAF, single O2, barometric         (15 PIDs)
//   _pidEv  electric: speed + module voltage only               ( 2 PIDs)
// ---------------------------------------------------------------------------

const List<String> _pidA = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle', 'o2Upstream',
  'o2Downstream', 'engineRuntime', 'fuelLevel', 'barometric', 'batteryVoltage',
];
const List<String> _pidA49 = [..._pidA, 'acceleratorPedal'];
const List<String> _pidA49a = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'fuelPressure',
  'rpm', 'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle',
  'o2Upstream', 'o2Downstream', 'engineRuntime', 'fuelLevel', 'barometric',
  'batteryVoltage', 'acceleratorPedal',
];
const List<String> _pidB = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle', 'o2Upstream',
  'o2Downstream', 'engineRuntime', 'fuelLevel', 'batteryVoltage',
];
const List<String> _pidB49 = [..._pidB, 'acceleratorPedal'];
const List<String> _pidC = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'throttle', 'o2Upstream',
  'o2Downstream', 'engineRuntime', 'fuelLevel', 'batteryVoltage',
];
const List<String> _pidD = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'throttle', 'o2Upstream',
  'engineRuntime', 'fuelLevel', 'batteryVoltage',
];
const List<String> _pidE = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'map', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'throttle', 'o2Upstream',
  'engineRuntime', 'fuelLevel', 'barometric', 'batteryVoltage',
];
const List<String> _pidF = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'map', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle', 'o2Upstream',
  'o2Downstream', 'engineRuntime', 'fuelLevel', 'barometric', 'batteryVoltage',
];
const List<String> _pidF49 = [..._pidF, 'acceleratorPedal'];
const List<String> _pidG = [
  'engineLoad', 'coolantTemp', 'rpm', 'speed', 'intakeAirTemp', 'throttle',
  'engineRuntime', 'batteryVoltage',
];
const List<String> _pidDiesel = [
  'engineLoad', 'coolantTemp', 'map', 'rpm', 'speed', 'intakeAirTemp',
  'throttle', 'engineRuntime', 'fuelLevel', 'barometric', 'batteryVoltage',
];
const List<String> _pidDieselNoBaro = [
  'engineLoad', 'coolantTemp', 'map', 'rpm', 'speed', 'intakeAirTemp',
  'throttle', 'engineRuntime', 'fuelLevel', 'batteryVoltage',
];
const List<String> _pidTangHybrid = [
  'engineLoad', 'coolantTemp', 'rpm', 'speed', 'throttle', 'engineRuntime',
  'batteryVoltage',
];
const List<String> _pidHybridMg = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle', 'o2Upstream',
  'engineRuntime', 'fuelLevel', 'batteryVoltage',
];
const List<String> _pidHybridGeely = [
  'engineLoad', 'coolantTemp', 'shortFuelTrim', 'longFuelTrim', 'rpm',
  'speed', 'timingAdvance', 'intakeAirTemp', 'maf', 'throttle', 'o2Upstream',
  'engineRuntime', 'fuelLevel', 'barometric', 'batteryVoltage',
];
const List<String> _pidEv = ['speed', 'batteryVoltage'];

// ---------------------------------------------------------------------------
// Manufacturer-specific parameter sets, assigned by engine type / hardware.
// ---------------------------------------------------------------------------

const List<String> _mDieselFull = [
  'egrStatus', 'dpfSoot', 'turboBoost', 'dpfTemp',
];
const List<String> _mDiesel3 = ['egrStatus', 'dpfSoot', 'turboBoost'];
const List<String> _mDiesel2 = ['egrStatus', 'dpfSoot'];
const List<String> _mEgrTurbo = ['egrStatus', 'turboBoost'];
const List<String> _mEgr = ['egrStatus'];
const List<String> _mTurbo = ['turboBoost'];
const List<String> _mHybridFull = [
  'hybridBatteryVoltage', 'hybridBatterySoc', 'hybridBatteryTemp',
  'electricMotorOutput',
];
const List<String> _mHybridMg = [
  'hybridBatteryVoltage', 'hybridBatterySoc', 'electricMotorOutput',
];
const List<String> _mEvFull = [
  'evBatteryVoltage', 'evBatterySoc', 'evBatteryTemp', 'evMotorRpm',
  'evRangeRemaining', 'chargingStatus',
];
const List<String> _mTang = [
  'evBatteryVoltage', 'evBatterySoc', 'hybridBatteryTemp',
  'electricMotorOutput',
];

/// Top-level access to the vehicle catalogue.
class VehicleDatabase {
  VehicleDatabase._();

  /// All known diagnostic parameters keyed by parameter id.
  static const Map<String, VehicleParameter> parameters = {
    // ---- Standard OBD-II parameters --------------------------------------
    'rpm': VehicleParameter(
      name: 'Engine RPM', category: 'Engine', pid: 0x0C, unit: 'rpm',
      description: 'Engine revolutions per minute', isStandard: true,
    ),
    'speed': VehicleParameter(
      name: 'Vehicle Speed', category: 'Engine', pid: 0x0D, unit: 'km/h',
      description: 'Road speed of the vehicle', isStandard: true,
    ),
    'coolantTemp': VehicleParameter(
      name: 'Coolant Temp', category: 'Engine', pid: 0x05, unit: '°C',
      description: 'Engine coolant temperature', isStandard: true,
    ),
    'intakeAirTemp': VehicleParameter(
      name: 'Intake Air Temp', category: 'Air', pid: 0x0F, unit: '°C',
      description: 'Intake air temperature', isStandard: true,
    ),
    'engineLoad': VehicleParameter(
      name: 'Engine Load', category: 'Engine', pid: 0x04, unit: '%',
      description: 'Calculated engine load value', isStandard: true,
    ),
    'throttle': VehicleParameter(
      name: 'Throttle Position', category: 'Engine', pid: 0x11, unit: '%',
      description: 'Absolute throttle position', isStandard: true,
    ),
    'fuelLevel': VehicleParameter(
      name: 'Fuel Level', category: 'Fuel', pid: 0x2F, unit: '%',
      description: 'Fuel tank level input', isStandard: true,
    ),
    'shortFuelTrim': VehicleParameter(
      name: 'Short Term Fuel Trim', category: 'Fuel', pid: 0x06, unit: '%',
      description: 'Short term fuel trim, bank 1', isStandard: true,
    ),
    'longFuelTrim': VehicleParameter(
      name: 'Long Term Fuel Trim', category: 'Fuel', pid: 0x07, unit: '%',
      description: 'Long term fuel trim, bank 1', isStandard: true,
    ),
    'maf': VehicleParameter(
      name: 'Mass Air Flow', category: 'Air', pid: 0x10, unit: 'g/s',
      description: 'Mass air flow sensor rate', isStandard: true,
    ),
    'map': VehicleParameter(
      name: 'Intake Manifold Pressure', category: 'Air', pid: 0x0B,
      unit: 'kPa', description: 'Intake manifold absolute pressure',
      isStandard: true,
    ),
    'barometric': VehicleParameter(
      name: 'Barometric Pressure', category: 'Air', pid: 0x33, unit: 'kPa',
      description: 'Absolute barometric pressure', isStandard: true,
    ),
    'timingAdvance': VehicleParameter(
      name: 'Timing Advance', category: 'Engine', pid: 0x0E, unit: '°',
      description: 'Ignition timing advance', isStandard: true,
    ),
    'batteryVoltage': VehicleParameter(
      name: 'Battery Voltage', category: 'Electrical', pid: 0x42, unit: 'V',
      description: 'Control module / battery voltage', isStandard: true,
    ),
    'o2Upstream': VehicleParameter(
      name: 'O2 Upstream', category: 'Emissions', pid: 0x14, unit: 'V',
      description: 'Upstream oxygen sensor voltage', isStandard: true,
    ),
    'o2Downstream': VehicleParameter(
      name: 'O2 Downstream', category: 'Emissions', pid: 0x15, unit: 'V',
      description: 'Downstream oxygen sensor voltage', isStandard: true,
    ),
    'engineRuntime': VehicleParameter(
      name: 'Engine Run Time', category: 'Engine', pid: 0x1F, unit: 'sec',
      description: 'Time since engine start', isStandard: true,
    ),
    'fuelPressure': VehicleParameter(
      name: 'Fuel Pressure', category: 'Fuel', pid: 0x0A, unit: 'kPa',
      description: 'Fuel rail / system pressure', isStandard: true,
    ),
    'acceleratorPedal': VehicleParameter(
      name: 'Accelerator Pedal Position', category: 'Engine', pid: 0x49,
      unit: '%', description: 'Accelerator pedal position D', isStandard: true,
    ),
    // ---- Manufacturer-specific parameters --------------------------------
    'dpfSoot': VehicleParameter(
      name: 'DPF Soot Level', category: 'Emissions', pid: null, unit: '%',
      description: 'Diesel particulate filter soot load',
      isStandard: false,
    ),
    'dpfTemp': VehicleParameter(
      name: 'Diesel Particulate Filter Temp', category: 'Emissions',
      pid: null, unit: '°C',
      description: 'Diesel particulate filter exhaust temperature',
      isStandard: false,
    ),
    'egrStatus': VehicleParameter(
      name: 'EGR Status', category: 'Emissions', pid: null, unit: '',
      description: 'Exhaust gas recirculation status',
      isStandard: false,
    ),
    'turboBoost': VehicleParameter(
      name: 'Turbo Boost Pressure', category: 'Air', pid: null, unit: 'kPa',
      description: 'Turbocharger boost pressure',
      isStandard: false,
    ),
    'hybridBatteryVoltage': VehicleParameter(
      name: 'Hybrid Battery Voltage', category: 'Hybrid', pid: null,
      unit: 'V', description: 'High-voltage hybrid battery voltage',
      isStandard: false,
    ),
    'hybridBatterySoc': VehicleParameter(
      name: 'Hybrid Battery SOC', category: 'Hybrid', pid: null,
      unit: '%', description: 'Hybrid battery state of charge',
      isStandard: false,
    ),
    'hybridBatteryTemp': VehicleParameter(
      name: 'Hybrid Battery Temperature', category: 'Hybrid', pid: null,
      unit: '°C', description: 'Hybrid battery pack temperature',
      isStandard: false,
    ),
    'electricMotorOutput': VehicleParameter(
      name: 'Electric Motor Output', category: 'Hybrid', pid: null,
      unit: 'kW', description: 'Electric drive motor power output',
      isStandard: false,
    ),
    'evBatteryVoltage': VehicleParameter(
      name: 'EV Battery Voltage', category: 'Electric', pid: null, unit: 'V',
      description: 'Traction battery pack voltage', isStandard: false,
    ),
    'evBatterySoc': VehicleParameter(
      name: 'EV Battery SOC', category: 'Electric', pid: null, unit: '%',
      description: 'Traction battery state of charge', isStandard: false,
    ),
    'evBatteryTemp': VehicleParameter(
      name: 'EV Battery Temperature', category: 'Electric', pid: null,
      unit: '°C', description: 'Traction battery temperature',
      isStandard: false,
    ),
    'evMotorRpm': VehicleParameter(
      name: 'EV Motor RPM', category: 'Electric', pid: null, unit: 'rpm',
      description: 'Electric drive motor speed', isStandard: false,
    ),
    'evRangeRemaining': VehicleParameter(
      name: 'EV Range Remaining', category: 'Electric', pid: null, unit: 'km',
      description: 'Estimated remaining driving range', isStandard: false,
    ),
    'chargingStatus': VehicleParameter(
      name: 'Charging Status', category: 'Electric', pid: null, unit: '',
      description: 'Traction battery charging state', isStandard: false,
    ),
  };

  /// All supported brands.
  static final List<VehicleBrand> brands = [
    // ===================================================================
    // TOYOTA
    // ===================================================================
    VehicleBrand(
      name: 'Toyota',
      logoEmoji: '\u{1F697}',
      models: [
        VehicleModel(name: 'Vios', years: _years(2008, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Corolla Cross (Gasoline)',
            years: _years(2020, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Corolla Cross (Hybrid)',
            years: _years(2020, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidA49, ..._mHybridFull]),
        VehicleModel(name: 'Fortuner (Gasoline, Old Gen)',
            years: _years(2005, 2015),
            engineType: 'gasoline', supportedParameterIds: _pidC),
        VehicleModel(name: 'Fortuner (Gasoline)',
            years: _years(2016, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Fortuner (Diesel)', years: _years(2005, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'Innova (Gasoline)', years: _years(2005, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'Innova (Diesel)', years: _years(2005, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'Hilux (Gasoline)', years: _years(2005, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'Hilux (Diesel)', years: _years(2005, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'RAV4 (Gasoline)', years: _years(2013, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'RAV4 (Hybrid)', years: _years(2013, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidA49, ..._mHybridFull]),
        VehicleModel(name: 'Land Cruiser', years: _years(2000, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'Camry (Gasoline)', years: _years(2006, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Camry (Hybrid)', years: _years(2006, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidA49, ..._mHybridFull]),
        VehicleModel(name: 'Yaris', years: _years(2006, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidC),
        VehicleModel(name: 'Rush', years: _years(2018, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'Wigo', years: _years(2013, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
      ],
    ),
    // ===================================================================
    // MITSUBISHI
    // ===================================================================
    VehicleBrand(
      name: 'Mitsubishi',
      logoEmoji: '\u{1F699}',
      models: [
        VehicleModel(name: 'Mirage', years: _years(2013, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidE),
        VehicleModel(name: 'Mirage G4', years: _years(2014, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidE),
        VehicleModel(name: 'Montero Sport', years: _years(2016, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Strada', years: _years(2019, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Outlander', years: _years(2016, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Eclipse Cross', years: _years(2018, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'L300', years: _years(2000, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidG),
        VehicleModel(name: 'Galant', years: _years(2004, 2015),
            engineType: 'gasoline', supportedParameterIds: _pidB),
      ],
    ),
    // ===================================================================
    // NISSAN
    // ===================================================================
    VehicleBrand(
      name: 'Nissan',
      logoEmoji: '\u{1F690}',
      models: [
        VehicleModel(name: 'Almera', years: _years(2013, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Navara', years: _years(2015, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Terra', years: _years(2018, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'X-Trail', years: _years(2014, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Patrol', years: _years(2010, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mEgrTurbo]),
        VehicleModel(name: 'Urvan', years: _years(2012, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDieselNoBaro, ..._mEgrTurbo]),
        VehicleModel(name: 'Sylphy', years: _years(2013, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'GT-R', years: _years(2009, 2022),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
      ],
    ),
    // ===================================================================
    // SUZUKI
    // ===================================================================
    VehicleBrand(
      name: 'Suzuki',
      logoEmoji: '\u{1F3CE}',
      models: [
        VehicleModel(name: 'Ertiga', years: _years(2012, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'Vitara', years: _years(2015, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Swift', years: _years(2005, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'Celerio', years: _years(2015, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'Jimny', years: _years(2019, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'Dzire', years: _years(2017, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'APV', years: _years(2005, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidG),
        VehicleModel(name: 'Ciaz', years: _years(2015, 2022),
            engineType: 'gasoline', supportedParameterIds: _pidB),
      ],
    ),
    // ===================================================================
    // HONDA
    // ===================================================================
    VehicleBrand(
      name: 'Honda',
      logoEmoji: '\u{1F3CD}',
      models: [
        VehicleModel(name: 'City', years: _years(2002, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Civic', years: _years(2002, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'CR-V', years: _years(2002, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'BR-V', years: _years(2016, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Jazz/Fit', years: _years(2002, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidB49),
        VehicleModel(name: 'HR-V', years: _years(2015, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Accord', years: _years(2003, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Brio', years: _years(2012, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'WR-V', years: _years(2023, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Pilot', years: _years(2003, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
      ],
    ),
    // ===================================================================
    // ISUZU
    // ===================================================================
    VehicleBrand(
      name: 'Isuzu',
      logoEmoji: '\u{1F69A}',
      models: [
        VehicleModel(name: 'D-Max', years: _years(2003, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'mu-X', years: _years(2014, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'Crosswind', years: _years(2000, 2013),
            engineType: 'diesel',
            supportedParameterIds: [..._pidG, ..._mEgr]),
        VehicleModel(name: 'Traviz', years: _years(2016, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'Sportivo', years: _years(2004, 2012),
            engineType: 'diesel',
            supportedParameterIds: [..._pidG, ..._mEgr]),
      ],
    ),
    // ===================================================================
    // MAZDA
    // ===================================================================
    VehicleBrand(
      name: 'Mazda',
      logoEmoji: '\u{1F698}',
      models: [
        VehicleModel(name: 'Mazda2', years: _years(2007, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Mazda3', years: _years(2004, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Mazda6', years: _years(2003, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'CX-3', years: _years(2016, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'CX-5 (Gasoline)', years: _years(2013, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'CX-5 (Diesel)', years: _years(2013, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel2]),
        VehicleModel(name: 'CX-8', years: _years(2018, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49a),
        VehicleModel(name: 'BT-50', years: _years(2007, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDieselFull]),
        VehicleModel(name: 'MX-5', years: _years(2006, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
      ],
    ),
    // ===================================================================
    // FORD
    // ===================================================================
    VehicleBrand(
      name: 'Ford',
      logoEmoji: '\u{1F6FB}',
      models: [
        VehicleModel(name: 'Ranger (Gasoline)', years: _years(2007, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Ranger (Diesel)', years: _years(2007, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Everest', years: _years(2003, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'EcoSport', years: _years(2014, 2019),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'Explorer', years: _years(2011, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'F-150', years: _years(2010, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'Mustang', years: _years(2015, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'Territory', years: _years(2020, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
      ],
    ),
    // ===================================================================
    // HYUNDAI
    // ===================================================================
    VehicleBrand(
      name: 'Hyundai',
      logoEmoji: '\u{1F696}',
      models: [
        VehicleModel(name: 'Accent', years: _years(2006, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Tucson', years: _years(2010, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Santa Fe (Gasoline)', years: _years(2007, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49a),
        VehicleModel(name: 'Santa Fe (Diesel)', years: _years(2007, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Elantra', years: _years(2004, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Creta', years: _years(2021, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Staria (Gasoline)', years: _years(2021, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49a),
        VehicleModel(name: 'Staria (Diesel)', years: _years(2021, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Ioniq 5', years: _years(2022, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
      ],
    ),
    // ===================================================================
    // KIA
    // ===================================================================
    VehicleBrand(
      name: 'Kia',
      logoEmoji: '\u{1F695}',
      models: [
        VehicleModel(name: 'Picanto', years: _years(2008, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'Soluto', years: _years(2019, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidB),
        VehicleModel(name: 'Rio', years: _years(2006, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Sportage (Gasoline)', years: _years(2005, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49),
        VehicleModel(name: 'Sportage (Diesel)', years: _years(2005, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Sorento (Gasoline)', years: _years(2003, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA49a),
        VehicleModel(name: 'Sorento (Diesel)', years: _years(2003, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Carnival', years: _years(2015, 2024),
            engineType: 'diesel',
            supportedParameterIds: [..._pidDiesel, ..._mDiesel3]),
        VehicleModel(name: 'Stinger', years: _years(2018, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'EV6', years: _years(2022, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
      ],
    ),
    // ===================================================================
    // BYD
    // ===================================================================
    VehicleBrand(
      name: 'BYD',
      logoEmoji: '\u{1F50B}',
      models: [
        VehicleModel(name: 'Atto 3', years: _years(2022, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'Dolphin', years: _years(2023, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'Seal', years: _years(2023, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'Han', years: _years(2023, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'Tang', years: _years(2023, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidTangHybrid, ..._mTang]),
        VehicleModel(name: 'F3', years: _years(2006, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidD),
      ],
    ),
    // ===================================================================
    // MG
    // ===================================================================
    VehicleBrand(
      name: 'MG',
      logoEmoji: '\u{1F3C1}',
      models: [
        VehicleModel(name: 'MG5 (Gasoline)', years: _years(2021, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'MG5 (Electric)', years: _years(2021, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'MG ZS', years: _years(2018, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'MG ZS EV', years: _years(2020, 2024),
            engineType: 'electric',
            supportedParameterIds: [..._pidEv, ..._mEvFull]),
        VehicleModel(name: 'MG HS', years: _years(2020, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'MG RX5', years: _years(2020, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'MG One', years: _years(2022, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'MG VS HEV', years: _years(2023, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidHybridMg, ..._mHybridMg]),
      ],
    ),
    // ===================================================================
    // GEELY
    // ===================================================================
    VehicleBrand(
      name: 'Geely',
      logoEmoji: '✨',
      models: [
        VehicleModel(name: 'Coolray', years: _years(2020, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'Okavango', years: _years(2021, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'Azkarra', years: _years(2020, 2024),
            engineType: 'hybrid',
            supportedParameterIds: [..._pidHybridGeely, ..._mHybridFull]),
        VehicleModel(name: 'Emgrand', years: _years(2013, 2022),
            engineType: 'gasoline', supportedParameterIds: _pidD),
        VehicleModel(name: 'Tugella', years: _years(2021, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'MK', years: _years(2010, 2020),
            engineType: 'gasoline', supportedParameterIds: _pidD),
      ],
    ),
    // ===================================================================
    // GAC MOTOR
    // ===================================================================
    VehicleBrand(
      name: 'GAC Motor',
      logoEmoji: '\u{1F31F}',
      models: [
        VehicleModel(name: 'GS3', years: _years(2020, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'GS4', years: _years(2016, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'GS8', years: _years(2017, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF49, ..._mTurbo]),
        VehicleModel(name: 'GM6', years: _years(2018, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'GA4', years: _years(2019, 2024),
            engineType: 'gasoline', supportedParameterIds: _pidA),
        VehicleModel(name: 'Emkoo', years: _years(2023, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'Emzoom', years: _years(2023, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
        VehicleModel(name: 'Empow', years: _years(2023, 2024),
            engineType: 'gasoline',
            supportedParameterIds: [..._pidF, ..._mTurbo]),
      ],
    ),
  ];

  /// Looks up a brand by name (case-insensitive).
  static VehicleBrand? findBrand(String name) {
    for (final b in brands) {
      if (b.name.toLowerCase() == name.toLowerCase()) return b;
    }
    return null;
  }
}
