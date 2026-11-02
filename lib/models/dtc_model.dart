enum DtcStatus { stored, pending, permanent }

class Dtc {
  final String code;
  final String description;
  final DtcStatus status;

  /// Brand whose manufacturer list described this code, or `null` when the
  /// generic SAE description was used.
  final String? manufacturer;

  const Dtc({
    required this.code,
    required this.description,
    this.status = DtcStatus.stored,
    this.manufacturer,
  });

  String get systemLetter {
    if (code.isEmpty) return '?';
    return code[0];
  }

  String get systemName {
    switch (systemLetter) {
      case 'P':
        return 'Powertrain';
      case 'C':
        return 'Chassis';
      case 'B':
        return 'Body';
      case 'U':
        return 'Network';
      default:
        return 'Unknown';
    }
  }
}
