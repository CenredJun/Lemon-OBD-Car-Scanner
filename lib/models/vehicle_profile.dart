import '../data/vehicle_database.dart';

/// The vehicle the user has selected. Determines which OBD-II PIDs the app
/// polls and which manufacturer-specific parameters it surfaces.
class VehicleProfile {
  final String brandName;
  final String modelName;
  final int selectedYear;

  /// 'gasoline', 'diesel', 'hybrid' or 'electric'.
  final String engineType;

  /// Standard OBD-II PIDs supported by this vehicle.
  final List<int> supportedPidCodes;

  /// Names of manufacturer-specific parameters (not pollable over OBD-II).
  final List<String> manufacturerParams;

  const VehicleProfile({
    required this.brandName,
    required this.modelName,
    required this.selectedYear,
    required this.engineType,
    required this.supportedPidCodes,
    required this.manufacturerParams,
  });

  /// Builds a profile from a database [brand]/[model] selection and a year.
  factory VehicleProfile.fromSelection({
    required VehicleBrand brand,
    required VehicleModel model,
    required int year,
  }) {
    return VehicleProfile(
      brandName: brand.name,
      modelName: model.name,
      selectedYear: year,
      engineType: model.engineType,
      supportedPidCodes: model.standardPidCodes,
      manufacturerParams: model.manufacturerParameterNames,
    );
  }

  /// Human-readable label, e.g. "Toyota Vios 2022".
  String get displayName => '$brandName $modelName $selectedYear';

  bool get hasManufacturerParams => manufacturerParams.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'brandName': brandName,
        'modelName': modelName,
        'selectedYear': selectedYear,
        'engineType': engineType,
        'supportedPidCodes': supportedPidCodes,
        'manufacturerParams': manufacturerParams,
      };

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    return VehicleProfile(
      brandName: json['brandName'] as String,
      modelName: json['modelName'] as String,
      selectedYear: json['selectedYear'] as int,
      engineType: json['engineType'] as String,
      supportedPidCodes: (json['supportedPidCodes'] as List)
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      manufacturerParams: (json['manufacturerParams'] as List)
          .map((e) => e as String)
          .toList(growable: false),
    );
  }
}
