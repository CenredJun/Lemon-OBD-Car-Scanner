enum DtcStatus { stored, pending, permanent }

class Dtc {
  final String code;
  final String description;
  final DtcStatus status;

  const Dtc({
    required this.code,
    required this.description,
    this.status = DtcStatus.stored,
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
