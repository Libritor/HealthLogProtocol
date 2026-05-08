class OuraDevice {
  final String id;
  final String name;
  final bool isConnected;
  final int batteryPercent;
  final String? firmwareVersion;
  final String? hardwareType;
  final String? email;

  const OuraDevice({
    required this.id,
    this.name = 'Oura Ring 3',
    this.isConnected = false,
    this.batteryPercent = 0,
    this.firmwareVersion,
    this.hardwareType,
    this.email,
  });

  OuraDevice copyWith({
    String? id,
    String? name,
    bool? isConnected,
    int? batteryPercent,
    String? firmwareVersion,
    String? hardwareType,
    String? email,
  }) {
    return OuraDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnected: isConnected ?? this.isConnected,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareType: hardwareType ?? this.hardwareType,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OuraDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
