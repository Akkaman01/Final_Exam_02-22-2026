import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';

class DashboardSummary {
  final int totalOfflineReports;
  final List<Map<String, Object?>> topStations;

  const DashboardSummary({
    required this.totalOfflineReports,
    required this.topStations,
  });
}

class SqliteService {
  SqliteService._();
  static final SqliteService instance = SqliteService._();

  static const _dbFile = 'exam.db';
  Database? _db;

  Future<String> _dbPath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbFile);
  }

  Future<bool> hasDatabaseFile() async {
    final path = await _dbPath();
    return databaseExists(path);
  }

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = await _dbPath();
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
    );
    return _db!;
  }

  Future<void> ensureInitialized() async {
    await database;
    await _ensureRequiredReferenceData();
  }

  Future<void> _ensureRequiredReferenceData() async {
    final db = await database;
    final rows = await db.query(
      'violation_type',
      columns: ['type_id'],
      where: 'type_name = ?',
      whereArgs: ['แจกสิ่งของ'],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('violation_type', {
        'type_id': '6',
        'type_name': 'แจกสิ่งของ',
        'severity': 'Medium',
      });
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE polling_station (
        station_id TEXT PRIMARY KEY,
        station_name TEXT NOT NULL,
        zone TEXT NOT NULL,
        province TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE violation_type (
        type_id TEXT PRIMARY KEY,
        type_name TEXT NOT NULL,
        severity TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE incident_report (
        report_id INTEGER PRIMARY KEY AUTOINCREMENT,
        station_id TEXT NOT NULL,
        type_id TEXT NOT NULL,
        reporter_name TEXT NOT NULL,
        description TEXT,
        evidence_photo TEXT,
        timestamp TEXT NOT NULL,
        ai_result TEXT,
        ai_confidence REAL,
        FOREIGN KEY (station_id) REFERENCES polling_station(station_id),
        FOREIGN KEY (type_id) REFERENCES violation_type(type_id)
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();

    batch.insert('polling_station', {
      'station_id': '101',
      'station_name': 'โรงเรียนวัดพระมหาธาตุ',
      'zone': 'เขต 1',
      'province': 'นครศรีธรรมราช',
    });
    batch.insert('polling_station', {
      'station_id': '102',
      'station_name': 'เต็นท์หน้าตลาดท่าวัง',
      'zone': 'เขต 1',
      'province': 'นครศรีธรรมราช',
    });
    batch.insert('polling_station', {
      'station_id': '103',
      'station_name': 'ศาลาหมู่บ้านคีรีวง',
      'zone': 'เขต 2',
      'province': 'นครศรีธรรมราช',
    });
    batch.insert('polling_station', {
      'station_id': '104',
      'station_name': 'หอประชุมอำเภอทุ่งสง',
      'zone': 'เขต 3',
      'province': 'นครศรีธรรมราช',
    });

    batch.insert('violation_type', {
      'type_id': '1',
      'type_name': 'ซื้อสิทธิ์ขายเสียง',
      'severity': 'High',
    });
    batch.insert('violation_type', {
      'type_id': '2',
      'type_name': 'ขนคนไปลงคะแนน',
      'severity': 'High',
    });
    batch.insert('violation_type', {
      'type_id': '3',
      'type_name': 'หาเสียงเกินเวลา',
      'severity': 'Medium',
    });
    batch.insert('violation_type', {
      'type_id': '4',
      'type_name': 'ทำลายป้ายหาเสียง',
      'severity': 'Low',
    });
    batch.insert('violation_type', {
      'type_id': '5',
      'type_name': 'เจ้าหน้าที่วางตัวไม่เป็นกลาง',
      'severity': 'High',
    });
    batch.insert('violation_type', {
      'type_id': '6',
      'type_name': 'แจกสิ่งของ',
      'severity': 'Medium',
    });

    batch.insert('incident_report', {
      'station_id': '101',
      'type_id': '1',
      'reporter_name': 'พลเมืองดี 01',
      'description': 'พบเห็นการแจกเงินบริเวณหน้าหน่วย',
      'evidence_photo': null,
      'timestamp': '2026-02-08 09:30:00',
      'ai_result': 'Money',
      'ai_confidence': 0.95,
    });
    batch.insert('incident_report', {
      'station_id': '102',
      'type_id': '3',
      'reporter_name': 'สมชาย ใจกล้า',
      'description': 'มีการเปิดรถแห่เสียงดังรบกวน',
      'evidence_photo': null,
      'timestamp': '2026-02-08 10:15:00',
      'ai_result': 'Crowd',
      'ai_confidence': 0.75,
    });

    await batch.commit(noResult: true);
  }

  Future<DashboardSummary> getDashboardSummary() async {
    final db = await database;
    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) AS total_count FROM incident_report',
    );
    final total =
        (totalRows.first['total_count'] as int?) ??
        ((totalRows.first['total_count'] as num?)?.toInt() ?? 0);

    final topStations = await db.rawQuery('''
      SELECT
        s.station_id,
        s.station_name,
        COUNT(r.report_id) AS report_count
      FROM incident_report r
      JOIN polling_station s ON s.station_id = r.station_id
      GROUP BY s.station_id, s.station_name
      ORDER BY report_count DESC, s.station_id ASC
      LIMIT 3
    ''');

    return DashboardSummary(
      totalOfflineReports: total,
      topStations: topStations,
    );
  }

  Future<List<PollingStation>> getStations() async {
    final db = await database;
    final rows = await db.query('polling_station', orderBy: 'station_id ASC');
    return rows.map(PollingStation.fromMap).toList();
  }

  Future<List<ViolationType>> getViolationTypes() async {
    final db = await database;
    final rows = await db.query('violation_type', orderBy: 'type_id ASC');
    return rows.map(ViolationType.fromMap).toList();
  }

  Future<String?> findViolationTypeIdByName(String typeName) async {
    final db = await database;
    final rows = await db.query(
      'violation_type',
      columns: ['type_id'],
      where: 'type_name = ?',
      whereArgs: [typeName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['type_id']?.toString();
  }

  Future<List<Map<String, Object?>>> getReportsJoin({
    String keyword = '',
  }) async {
    final db = await database;
    const selectClause = '''
      SELECT
        r.report_id,
        r.station_id,
        r.type_id,
        r.reporter_name,
        r.description,
        r.evidence_photo,
        r.timestamp,
        r.ai_result,
        r.ai_confidence,
        s.station_name,
        s.province,
        v.type_name,
        v.severity
      FROM incident_report r
      JOIN polling_station s ON s.station_id = r.station_id
      JOIN violation_type v ON v.type_id = r.type_id
    ''';

    if (keyword.trim().isEmpty) {
      return db.rawQuery('$selectClause ORDER BY r.report_id DESC');
    }

    return db.rawQuery('''
      $selectClause
      WHERE
        r.reporter_name LIKE ? OR
        r.description LIKE ? OR
        s.station_name LIKE ? OR
        v.type_name LIKE ?
      ORDER BY r.report_id DESC
      ''', List.filled(4, '%${keyword.trim()}%'));
  }

  Future<List<Map<String, Object?>>> searchReports({
    String keyword = '',
    String? severity,
  }) async {
    final db = await database;
    const selectClause = '''
      SELECT
        r.report_id,
        r.station_id,
        r.type_id,
        r.reporter_name,
        r.description,
        r.evidence_photo,
        r.timestamp,
        r.ai_result,
        r.ai_confidence,
        s.station_name,
        s.province,
        v.type_name,
        v.severity
      FROM incident_report r
      JOIN polling_station s ON s.station_id = r.station_id
      JOIN violation_type v ON v.type_id = r.type_id
    ''';

    final whereParts = <String>[];
    final args = <Object?>[];
    final kw = keyword.trim();

    if (kw.isNotEmpty) {
      whereParts.add('(r.reporter_name LIKE ? OR r.description LIKE ?)');
      args.add('%$kw%');
      args.add('%$kw%');
    }

    if (severity != null && severity.isNotEmpty) {
      whereParts.add('v.severity = ?');
      args.add(severity);
    }

    final whereClause = whereParts.isEmpty
        ? ''
        : 'WHERE ${whereParts.join(' AND ')}';
    final sql = '$selectClause $whereClause ORDER BY r.report_id DESC';
    return db.rawQuery(sql, args);
  }

  Future<Map<String, Object?>?> getReportByIdJoin(int reportId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        r.report_id,
        r.station_id,
        r.type_id,
        r.reporter_name,
        r.description,
        r.evidence_photo,
        r.timestamp,
        r.ai_result,
        r.ai_confidence,
        s.station_name,
        s.province,
        v.type_name,
        v.severity
      FROM incident_report r
      JOIN polling_station s ON s.station_id = r.station_id
      JOIN violation_type v ON v.type_id = r.type_id
      WHERE r.report_id = ?
      LIMIT 1
      ''',
      [reportId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> countIncidentsByStationId(String stationId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total_count FROM incident_report WHERE station_id = ?',
      [stationId],
    );
    final value =
        (rows.first['total_count'] as int?) ??
        ((rows.first['total_count'] as num?)?.toInt() ?? 0);
    return value;
  }

  Future<bool> isDuplicateStationName({
    required String stationId,
    required String stationName,
  }) async {
    final db = await database;
    final rows = await db.query(
      'polling_station',
      columns: ['station_id'],
      where: 'station_name = ? AND station_id <> ?',
      whereArgs: [stationName, stationId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> updateStation(PollingStation station) async {
    final db = await database;
    return db.update(
      'polling_station',
      station.toMap(),
      where: 'station_id = ?',
      whereArgs: [station.stationId],
    );
  }

  Future<int> insertReport(IncidentReport report) async {
    final db = await database;
    return db.insert('incident_report', report.toMap());
  }

  Future<int> updateReport(IncidentReport report) async {
    final db = await database;
    if (report.reportId == null) return 0;
    return db.update(
      'incident_report',
      report.toMap(),
      where: 'report_id = ?',
      whereArgs: [report.reportId],
    );
  }

  Future<int> deleteReport(int reportId) async {
    final db = await database;
    return db.delete(
      'incident_report',
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }
}
