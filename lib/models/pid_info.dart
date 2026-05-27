typedef PidFormula = double Function(List<int> bytes);

class PidInfo {
  final int pid;
  final String name;
  final String unit;
  final double minValue;
  final double maxValue;
  final PidFormula formula;
  final int requiredBytes;

  const PidInfo({
    required this.pid,
    required this.name,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.formula,
    required this.requiredBytes,
  });

  String get hexCode => pid.toRadixString(16).padLeft(2, '0').toUpperCase();

  String get modePidCommand => '01$hexCode';
}

class PidValue {
  final int pid;
  final double value;
  final DateTime timestamp;

  const PidValue({
    required this.pid,
    required this.value,
    required this.timestamp,
  });
}

class PidStats {
  double current = 0;
  double min = double.infinity;
  double max = -double.infinity;
  bool hasData = false;

  void update(double value) {
    current = value;
    min = hasData ? (value < min ? value : min) : value;
    max = hasData ? (value > max ? value : max) : value;
    hasData = true;
  }

  void reset() {
    current = 0;
    min = double.infinity;
    max = -double.infinity;
    hasData = false;
  }

  double get displayMin => hasData ? min : 0;
  double get displayMax => hasData ? max : 0;
}
