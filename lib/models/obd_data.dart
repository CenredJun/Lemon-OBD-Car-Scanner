enum ObdConnectionState { disconnected, connecting, connected, error }

class ObdSettings {
  final String ipAddress;
  final int port;
  final int pollingIntervalMs;
  final String protocol;

  const ObdSettings({
    this.ipAddress = '192.168.0.10',
    this.port = 35000,
    this.pollingIntervalMs = 500,
    this.protocol = 'Auto',
  });

  ObdSettings copyWith({
    String? ipAddress,
    int? port,
    int? pollingIntervalMs,
    String? protocol,
  }) {
    return ObdSettings(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      pollingIntervalMs: pollingIntervalMs ?? this.pollingIntervalMs,
      protocol: protocol ?? this.protocol,
    );
  }

  static const Map<String, String> protocolCommands = {
    'Auto': 'ATSP0',
    'ISO 9141': 'ATSP3',
    'CAN 11bit': 'ATSP6',
    'CAN 29bit': 'ATSP7',
  };

  String get protocolCommand => protocolCommands[protocol] ?? 'ATSP0';
}
