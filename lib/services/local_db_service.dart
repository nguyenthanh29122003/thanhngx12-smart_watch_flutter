// lib/services/local_db_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Cho kDebugMode

// Import Models
import '../models/health_data.dart';
import '../models/activity_segment.dart'; // Model cho lịch sử hoạt động

class LocalDbService {
  static const _databaseName = "health_data_v1.db";
  // QUAN TRỌNG: Tăng version nếu bạn thay đổi schema (ví dụ: thêm bảng mới)
  // Nếu DB đã tồn tại với version cũ, onUpgrade sẽ được gọi.
  // Nếu bạn đang phát triển và muốn tạo lại từ đầu, hãy gỡ cài đặt app
  // hoặc dùng deleteDatabaseFile() rồi đặt version là 1.
  static const _databaseVersion = 3; // Giả sử version 2 đã thêm cột temp/pres
  // Version 3 sẽ thêm bảng activity_segments

  // --- Bảng Health Records ---
  static const tableHealthRecords = 'health_records';
  static const columnId = '_id'; // Dùng chung cho Primary Key của các bảng
  static const columnAx = 'ax';
  static const columnAy = 'ay';
  static const columnAz = 'az';
  static const columnGx = 'gx';
  static const columnGy = 'gy';
  static const columnGz = 'gz';
  static const columnSteps = 'steps';
  static const columnHr = 'hr';
  static const columnSpo2 = 'spo2';
  static const columnIr = 'ir';
  static const columnRed = 'red';
  static const columnWifi = 'wifi';
  static const columnTimestamp = 'timestamp'; // Unix milliseconds UTC
  static const columnIsSynced = 'is_synced'; // 0 = false, 1 = true
  static const columnTemp = 'temp'; // REAL NULL
  static const columnPres = 'pres'; // REAL NULL

  // --- Bảng Activity Segments (MỚI) ---
  static const tableActivitySegments = 'activity_segments';
  // columnId (PK) đã được định nghĩa ở trên
  static const columnActivityName = 'activityName'; // TEXT NOT NULL
  static const columnSegmentStartTime =
      'startTime'; // TEXT NOT NULL (ISO8601 UTC)
  static const columnSegmentEndTime = 'endTime'; // TEXT NOT NULL (ISO8601 UTC)
  static const columnSegmentDuration = 'durationInSeconds'; // INTEGER NOT NULL
  static const columnSegmentCalories = 'caloriesBurned'; // REAL NULL
  static const columnSegmentUserId = 'userId'; // TEXT NULL (tùy chọn)

  // --- Singleton Pattern ---
  LocalDbService._privateConstructor();
  static final LocalDbService instance = LocalDbService._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    if (kDebugMode) print("[LocalDbService] Database path: $path");

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    if (kDebugMode)
      print("[LocalDbService] Creating database tables version $version...");
    // Tạo bảng health_records
    await _createHealthRecordsTable(db);

    // Tạo bảng activity_segments nếu version hiện tại khi tạo là 3 hoặc cao hơn
    if (version >= 3) {
      await _createActivitySegmentsTable(db);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode)
      print(
          "[LocalDbService] Upgrading database from version $oldVersion to $newVersion...");
    if (oldVersion < 2) {
      if (kDebugMode)
        print(
            "  Applying upgrade for v2: Adding temp and pres columns to $tableHealthRecords");
      try {
        await db.execute(
            'ALTER TABLE $tableHealthRecords ADD COLUMN $columnTemp REAL NULL');
        if (kDebugMode) print("    Added column: $columnTemp");
      } catch (e) {
        if (kDebugMode)
          print("    Error adding $columnTemp (may exist or other issue): $e");
      }
      try {
        await db.execute(
            'ALTER TABLE $tableHealthRecords ADD COLUMN $columnPres REAL NULL');
        if (kDebugMode) print("    Added column: $columnPres");
      } catch (e) {
        if (kDebugMode)
          print("    Error adding $columnPres (may exist or other issue): $e");
      }
    }
    if (oldVersion < 3) {
      if (kDebugMode)
        print(
            "  Applying upgrade for v3: Creating table $tableActivitySegments");
      await _createActivitySegmentsTable(db);
    }
    // Thêm các khối if (oldVersion < X) cho các lần nâng cấp sau
    if (kDebugMode) print("[LocalDbService] Database upgrade complete.");
  }

  // Hàm helper để tạo bảng health_records
  Future<void> _createHealthRecordsTable(Database db) async {
    if (kDebugMode)
      print("[LocalDbService] Creating table '$tableHealthRecords'...");
    await db.execute('''
      CREATE TABLE $tableHealthRecords (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAx REAL NOT NULL, $columnAy REAL NOT NULL, $columnAz REAL NOT NULL,
        $columnGx REAL NOT NULL, $columnGy REAL NOT NULL, $columnGz REAL NOT NULL,
        $columnSteps INTEGER NOT NULL, $columnHr INTEGER NOT NULL, $columnSpo2 INTEGER NOT NULL,
        $columnIr INTEGER NOT NULL, $columnRed INTEGER NOT NULL, $columnWifi INTEGER NOT NULL,
        $columnTimestamp INTEGER NOT NULL UNIQUE,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        $columnTemp REAL NULL,
        $columnPres REAL NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_hr_timestamp ON $tableHealthRecords ($columnTimestamp)');
    await db.execute(
        'CREATE INDEX idx_hr_is_synced ON $tableHealthRecords ($columnIsSynced)');
    if (kDebugMode)
      print("[LocalDbService] Table '$tableHealthRecords' created/ensured.");
  }

  // Hàm helper để tạo bảng activity_segments
  Future<void> _createActivitySegmentsTable(Database db) async {
    if (kDebugMode)
      print("[LocalDbService] Creating table '$tableActivitySegments'...");
    await db.execute('''
      CREATE TABLE $tableActivitySegments (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnActivityName TEXT NOT NULL,
        $columnSegmentStartTime TEXT NOT NULL,
        $columnSegmentEndTime TEXT NOT NULL,
        $columnSegmentDuration INTEGER NOT NULL,
        $columnSegmentCalories REAL NULL,
        $columnSegmentUserId TEXT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_segment_start_time ON $tableActivitySegments ($columnSegmentStartTime)');
    if (kDebugMode)
      print("[LocalDbService] Table '$tableActivitySegments' created/ensured.");
  }

  // --- Các hàm cho HealthData ---
  Future<int> saveHealthRecordLocally(HealthData data) async {
    try {
      final db = await database;
      Map<String, dynamic> row = {
        columnAx: data.ax, columnAy: data.ay, columnAz: data.az,
        columnGx: data.gx, columnGy: data.gy, columnGz: data.gz,
        columnSteps: data.steps, columnHr: data.hr, columnSpo2: data.spo2,
        columnIr: data.ir, columnRed: data.red,
        columnWifi: data.wifi ? 1 : 0,
        columnTimestamp:
            data.timestamp.toUtc().millisecondsSinceEpoch, // Luôn lưu UTC
        columnIsSynced: 0, // Mặc định là chưa đồng bộ
        columnTemp: data.temperature,
        columnPres: data.pressure,
      };
      final id = await db.insert(tableHealthRecords, row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id == 0 && kDebugMode) {
        print(
            "[LocalDbService] Skipped saving duplicate HealthData (timestamp conflict): ${data.timestamp.toIso8601String()}");
      } else if (id > 0 && kDebugMode) {
        // print("[LocalDbService] Saved HealthData with local ID: $id");
      }
      return id;
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error saving health record locally: $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedHealthRecords(
      {int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        tableHealthRecords,
        where: '$columnIsSynced = ?',
        whereArgs: [0],
        orderBy: '$columnTimestamp ASC',
        limit: limit,
      );
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error getting unsynced health records: $e");
      return [];
    }
  }

  Future<List<HealthData>> getUnsyncedHealthDataObjects(
      {int limit = 50}) async {
    final List<Map<String, dynamic>> maps =
        await getUnsyncedHealthRecords(limit: limit);
    // Sử dụng HealthData.fromDbMap từ model HealthData
    return List.generate(maps.length, (i) => HealthData.fromDbMap(maps[i]));
  }

  Future<int> markRecordsAsSynced(List<int> recordIds) async {
    if (recordIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.update(
        tableHealthRecords,
        {columnIsSynced: 1},
        where: '$columnId IN ($placeholders)',
        whereArgs: recordIds,
      );
      if (kDebugMode)
        print("[LocalDbService] Marked $count health records as synced.");
      return count;
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error marking health records as synced: $e");
      return -1;
    }
  }

  Future<int> deleteHealthRecordsByIds(List<int> recordIds) async {
    // Đổi tên để rõ ràng hơn
    if (recordIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.delete(
        tableHealthRecords,
        where: '$columnId IN ($placeholders)',
        whereArgs: recordIds,
      );
      if (kDebugMode)
        print("[LocalDbService] Deleted $count health records by IDs.");
      return count;
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error deleting health records by IDs: $e");
      return -1;
    }
  }

  Future<int> countUnsyncedHealthRecords() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableHealthRecords WHERE $columnIsSynced = 0',
      ));
      return count ?? 0;
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error counting unsynced health records: $e");
      return 0;
    }
  }

  // --- Các hàm cho ActivitySegment (MỚI) ---

  Future<int> insertActivitySegment(ActivitySegment segment) async {
    try {
      final db = await database;
      Map<String, dynamic> segmentMap = segment.toMap();
      if (segment.id == null) {
        segmentMap.remove('id'); // Để SQLite tự tạo ID
      }

      final id = await db.insert(
        tableActivitySegments,
        segmentMap,
        conflictAlgorithm:
            ConflictAlgorithm.replace, // Hoặc .ignore nếu không muốn ghi đè
      );
      if (kDebugMode && id > 0) {
        print(
            "[LocalDbService] Inserted activity segment ID: $id, Activity: ${segment.activityName}, Duration: ${segment.durationInSeconds}s");
      }
      return id;
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error inserting activity segment: $e");
      return -1;
    }
  }

  Future<List<ActivitySegment>> getActivitySegmentsForDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final String startStr =
          startDate.toUtc().toIso8601String(); // So sánh bằng UTC
      final String endStr = endDate.toUtc().toIso8601String();

      // Lấy các segment có startTime nằm trong khoảng, hoặc endTime nằm trong khoảng,
      // hoặc startTime trước khoảng và endTime sau khoảng (bao trùm)
      // Điều này phức tạp hơn, cách đơn giản là lấy theo startTime:
      final List<Map<String, dynamic>> maps = await db.query(
        tableActivitySegments,
        where:
            '$columnSegmentStartTime < ? AND $columnSegmentEndTime > ?', // Lấy các segment giao với khoảng thời gian
        whereArgs: [endStr, startStr], // Lưu ý thứ tự cho logic giao nhau
        orderBy: '$columnSegmentStartTime ASC',
      );
      // Hoặc một logic đơn giản hơn:
      // where: '$columnSegmentStartTime >= ? AND $columnSegmentStartTime < ?',
      // whereArgs: [startStr, endStr],

      return List.generate(
          maps.length, (i) => ActivitySegment.fromMap(maps[i]));
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error fetching activity segments for date range $startDate - $endDate: $e");
      return [];
    }
  }

  Future<List<ActivitySegment>> getActivitySegmentsForDay(DateTime date) async {
    final DateTime startOfDay =
        DateTime.utc(date.year, date.month, date.day); // UTC để nhất quán
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    return await getActivitySegmentsForDateRange(startOfDay, endOfDay);
  }

  Future<int> updateActivitySegmentCalories(
      int segmentId, double calories) async {
    try {
      final db = await database;
      final count = await db.update(
        tableActivitySegments,
        {columnSegmentCalories: calories},
        where: '$columnId = ?', // Giả định columnId là PK
        whereArgs: [segmentId],
      );
      if (kDebugMode && count > 0)
        print("[LocalDbService] Updated calories for segment ID: $segmentId");
      return count;
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error updating calories for segment $segmentId: $e");
      return 0;
    }
  }

  Future<List<ActivitySegment>> getAllActivitySegments(
      {int limit = 100, String? userId}) async {
    try {
      final db = await database;
      String? whereClause = userId != null ? '$columnSegmentUserId = ?' : null;
      List<dynamic>? whereArgs = userId != null ? [userId] : null;

      final List<Map<String, dynamic>> maps = await db.query(
          tableActivitySegments,
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: '$columnSegmentStartTime DESC',
          limit: limit);
      return List.generate(
          maps.length, (i) => ActivitySegment.fromMap(maps[i]));
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error fetching all activity segments: $e");
      return [];
    }
  }

  // --- Các hàm tiện ích chung ---
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      if (kDebugMode) print("[LocalDbService] Database connection closed.");
    }
  }

  Future<void> deleteDatabaseFile() async {
    try {
      await closeDatabase();
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      await deleteDatabase(path);
      if (kDebugMode) print("[LocalDbService] Database file deleted: $path");
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error deleting database file: $e");
    }
  }
}
