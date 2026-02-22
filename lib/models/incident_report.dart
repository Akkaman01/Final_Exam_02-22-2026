class IncidentReport {
  final int? reportId;
  final String stationId;
  final String typeId;
  final String reporterName;
  final String? description;
  final String? evidencePhoto;
  final String timestamp;
  final String? aiResult;
  final double? aiConfidence;

  const IncidentReport({
    this.reportId,
    required this.stationId,
    required this.typeId,
    required this.reporterName,
    this.description,
    this.evidencePhoto,
    required this.timestamp,
    this.aiResult,
    this.aiConfidence,
  });

  factory IncidentReport.fromMap(Map<String, Object?> map) {
    final rawAiConfidence = map['ai_confidence'];
    return IncidentReport(
      reportId: map['report_id'] as int?,
      stationId: (map['station_id'] ?? '').toString(),
      typeId: (map['type_id'] ?? '').toString(),
      reporterName: (map['reporter_name'] ?? '').toString(),
      description: map['description']?.toString(),
      evidencePhoto: map['evidence_photo']?.toString(),
      timestamp: (map['timestamp'] ?? '').toString(),
      aiResult: map['ai_result']?.toString(),
      aiConfidence: rawAiConfidence is num ? rawAiConfidence.toDouble() : null,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'station_id': stationId,
      'type_id': typeId,
      'reporter_name': reporterName,
      'description': description,
      'evidence_photo': evidencePhoto,
      'timestamp': timestamp,
      'ai_result': aiResult,
      'ai_confidence': aiConfidence,
    };
    if (includeId) {
      map['report_id'] = reportId;
    }
    return map;
  }
}
