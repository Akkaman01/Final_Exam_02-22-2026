class ViolationType {
  final String typeId;
  final String typeName;
  final String severity;

  const ViolationType({
    required this.typeId,
    required this.typeName,
    required this.severity,
  });

  factory ViolationType.fromMap(Map<String, Object?> map) {
    return ViolationType(
      typeId: (map['type_id'] ?? '').toString(),
      typeName: (map['type_name'] ?? '').toString(),
      severity: (map['severity'] ?? '').toString(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'type_id': typeId,
      'type_name': typeName,
      'severity': severity,
    };
  }
}
