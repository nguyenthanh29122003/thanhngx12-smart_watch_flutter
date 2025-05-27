// lib/services/local_db_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Cho kDebugMode

// Import Models
import '../models/health_data.dart';
import '../models/activity_segment.dart';

class LocalDbService {
  static const _databaseName = "health_data_v1.db";
  static const _databaseVersion =
      3; // Version 3: Thêm bảng activity_segments với is_synced

  // --- Bảng Health Records ---
  static const tableHealthRecords = 'health_records';
  static const columnId = '_id';
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
  static const columnTimestamp = 'timestamp';
  static const columnIsSynced = 'is_synced'; // Dùng chung tên cột cho is_synced
  static const columnTemp = 'temp';
  static const columnPres = 'pres';

  // --- Bảng Activity Segments ---
  static const tableActivitySegments = 'activity_segments';
  // columnId (PK) đã được định nghĩa ở trên
  static const columnActivityName = 'activityName';
  static const columnSegmentStartTime = 'startTime';
  static const columnSegmentEndTime = 'endTime';
  static const columnSegmentDuration = 'durationInSeconds';
  static const columnSegmentCalories = 'caloriesBurned';
  static const columnSegmentUserId = 'userId';
  // static const columnSegmentIsSynced = 'is_synced'; // <<< DÙNG CHUNG columnIsSynced

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
    await _createHealthRecordsTable(db);
    if (version >= 3) {
      // Nếu DB được tạo mới với version 3+
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
            "  Applying upgrade for v3: Creating table $tableActivitySegments (with is_synced column)");
      await _createActivitySegmentsTable(
          db); // Hàm này đã bao gồm cột is_synced
    }
    // Nếu bạn có version 3 đã tạo bảng activity_segments mà CHƯA CÓ cột is_synced:
    // if (oldVersion == 3 && newVersion >= 4) { // Giả sử bạn tăng lên version 4 để thêm cột
    //   if (kDebugMode) print("  Applying upgrade for v4: Adding $columnIsSynced column to $tableActivitySegments");
    //   try {
    //     await db.execute('ALTER TABLE $tableActivitySegments ADD COLUMN $columnIsSynced INTEGER NOT NULL DEFAULT 0');
    //     if (kDebugMode) print("    Added column to $tableActivitySegments: $columnIsSynced");
    //   } catch (e) { if (kDebugMode) print("    Error adding $columnIsSynced to $tableActivitySegments (may exist or other issue): $e");}
    // }
    if (kDebugMode) print("[LocalDbService] Database upgrade complete.");
  }

  Future<void> _createHealthRecordsTable(Database db) async {
    if (kDebugMode)
      print(
          "[LocalDbService] Creating/Ensuring table '$tableHealthRecords'...");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHealthRecords ( 
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
    '''); // Thêm IF NOT EXISTS cho an toàn
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hr_timestamp ON $tableHealthRecords ($columnTimestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hr_is_synced ON $tableHealthRecords ($columnIsSynced)');
    if (kDebugMode)
      print("[LocalDbService] Table '$tableHealthRecords' created/ensured.");
  }

  Future<void> _createActivitySegmentsTable(Database db) async {
    if (kDebugMode)
      print(
          "[LocalDbService] Creating/Ensuring table '$tableActivitySegments'...");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableActivitySegments (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnActivityName TEXT NOT NULL,
        $columnSegmentStartTime TEXT NOT NULL,
        $columnSegmentEndTime TEXT NOT NULL,
        $columnSegmentDuration INTEGER NOT NULL,
        $columnSegmentCalories REAL NULL,
        $columnSegmentUserId TEXT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0 -- <<< THÊM CỘT is_synced
      )
    '''); // Thêm IF NOT EXISTS
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_segment_start_time ON $tableActivitySegments ($columnSegmentStartTime)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_segment_user_id ON $tableActivitySegments ($columnSegmentUserId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_segment_is_synced ON $tableActivitySegments ($columnIsSynced)'); // Index cho is_synced
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
        columnTimestamp: data.timestamp.toUtc().millisecondsSinceEpoch,
        columnIsSynced: 0, // Mặc định là chưa đồng bộ
        columnTemp: data.temperature,
        columnPres: data.pressure,
      };
      final id = await db.insert(tableHealthRecords, row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id == 0 && kDebugMode) {
        // print("[LocalDbService] Skipped saving duplicate HealthData (timestamp conflict): ${data.timestamp.toIso8601String()}");
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
    return List.generate(maps.length, (i) => HealthData.fromDbMap(maps[i]));
  }

  Future<int> markHealthRecordsAsSynced(List<int> recordIds) async {
    // Đổi tên để rõ ràng
    if (recordIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.update(
        tableHealthRecords, // <<< SỬA: Tên bảng đúng
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

  // --- Các hàm cho ActivitySegment (CẬP NHẬT VÀ THÊM MỚI) ---

  Future<int> insertActivitySegment(ActivitySegment segment) async {
    try {
      final db = await database;
      // toMap() trong ActivitySegment đã xử lý việc isSynced thành 0 hoặc 1
      Map<String, dynamic> segmentMap = segment.toMap();
      if (segment.id == null) {
        segmentMap.remove('id');
      }
      // Đảm bảo isSynced được thêm vào map nếu chưa có (mặc định là false khi tạo segment)
      segmentMap[columnIsSynced] = (segment.isSynced) ? 1 : 0;

      final id = await db.insert(
        tableActivitySegments,
        segmentMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (kDebugMode && id > 0) {
        // print("[LocalDbService] Inserted activity segment ID: $id, Activity: ${segment.activityName}, Synced: ${segment.isSynced}");
      }
      return id;
    } catch (e) {
      if (kDebugMode)
        print("!!! [LocalDbService] Error inserting activity segment: $e");
      return -1;
    }
  }

  Future<List<ActivitySegment>> getActivitySegmentsForDateRange(
      DateTime startDate, DateTime endDate,
      {String? userId}) async {
    try {
      final db = await database;
      final String startStr = startDate.toUtc().toIso8601String();
      final String endStr = endDate.toUtc().toIso8601String();

      String whereClause =
          '$columnSegmentStartTime < ? AND $columnSegmentEndTime > ?';
      List<dynamic> whereArgs = [endStr, startStr];

      if (userId != null) {
        whereClause += ' AND $columnSegmentUserId = ?';
        whereArgs.add(userId);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        tableActivitySegments,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$columnSegmentStartTime ASC',
      );
      return List.generate(
          maps.length, (i) => ActivitySegment.fromMap(maps[i]));
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error fetching activity segments for date range $startDate - $endDate: $e");
      return [];
    }
  }

  Future<List<ActivitySegment>> getActivitySegmentsForDay(DateTime date,
      {String? userId}) async {
    final DateTime startOfDay = DateTime.utc(date.year, date.month, date.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    return await getActivitySegmentsForDateRange(startOfDay, endOfDay,
        userId: userId);
  }

  Future<int> updateActivitySegmentCalories(
      int segmentId, double calories) async {
    try {
      final db = await database;
      return await db.update(
        tableActivitySegments,
        {columnSegmentCalories: calories},
        where: '$columnId = ?',
        whereArgs: [segmentId],
      );
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

  // --- HÀM MỚI CHO ĐỒNG BỘ ACTIVITY SEGMENT ---
  Future<List<ActivitySegment>> getUnsyncedActivitySegments(
      {int limit = 50, String? userId}) async {
    try {
      final db = await database;
      String whereClause = '$columnIsSynced = ?';
      List<dynamic> whereArgs = [0];

      if (userId != null) {
        whereClause += ' AND $columnSegmentUserId = ?';
        whereArgs.add(userId);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        tableActivitySegments,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$columnSegmentStartTime ASC', // Đồng bộ cái cũ trước
        limit: limit,
      );
      return List.generate(
          maps.length, (i) => ActivitySegment.fromMap(maps[i]));
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error getting unsynced activity segments: $e");
      return [];
    }
  }

  Future<int> markActivitySegmentsAsSynced(List<int> segmentIds) async {
    if (segmentIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(segmentIds.length, '?').join(',');
      final count = await db.update(
        tableActivitySegments,
        {columnIsSynced: 1}, // Đặt is_synced = 1
        where: '$columnId IN ($placeholders)', // Giả sử columnId là PK
        whereArgs: segmentIds,
      );
      if (kDebugMode)
        print("[LocalDbService] Marked $count activity segments as synced.");
      return count;
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [LocalDbService] Error marking activity segments as synced: $e");
      return -1;
    }
  }
  // ---------------------------------------------

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
