// lib/services/local_db_service.dart
import 'package:path/path.dart'; // Cần để join đường dẫn
import 'package:sqflite/sqflite.dart'; // Thư viện SQLite chính
import 'package:path_provider/path_provider.dart'; // Để lấy đường dẫn lưu trữ phù hợp
import 'dart:async'; // Cho Future
import '../models/health_data.dart'; // Import model HealthData

class LocalDbService {
  static const _databaseName = "health_data_v1.db"; // Tên file DB
  // <<< TĂNG VERSION LÊN 2 ĐỂ TRIGGER onUpgrade >>>
  static const _databaseVersion = 2;

  static const tableHealthRecords = 'health_records'; // Tên bảng

  // --- Định nghĩa tên các cột trong bảng ---
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
  static const columnTimestamp =
      'timestamp'; // Lưu dạng INTEGER (Unix milliseconds UTC)
  static const columnIsSynced =
      'is_synced'; // Lưu dạng INTEGER (0 = false, 1 = true)
  // <<< THÊM TÊN CỘT MỚI >>>
  static const columnTemp = 'temp'; // Cột nhiệt độ (REAL NULL)
  static const columnPres = 'pres'; // Cột áp suất (REAL NULL)
  // -----------------------

  // --- Singleton Pattern ---
  LocalDbService._privateConstructor();
  static final LocalDbService instance = LocalDbService._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // --- Khởi tạo Database ---
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    print("Database path: $path");

    return await openDatabase(
      path,
      version: _databaseVersion, // <<< SỬ DỤNG VERSION MỚI (2)
      onCreate: _onCreate, // Hàm tạo bảng lần đầu
      onUpgrade: _onUpgrade, // <<< THÊM HÀM XỬ LÝ NÂNG CẤP
    );
  }

  // --- Tạo bảng khi DB được tạo lần đầu ---
  Future<void> _onCreate(Database db, int version) async {
    print("Creating database table '$tableHealthRecords' version $version...");
    await db.execute('''
      CREATE TABLE $tableHealthRecords (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAx REAL NOT NULL, $columnAy REAL NOT NULL, $columnAz REAL NOT NULL,
        $columnGx REAL NOT NULL, $columnGy REAL NOT NULL, $columnGz REAL NOT NULL,
        $columnSteps INTEGER NOT NULL, $columnHr INTEGER NOT NULL, $columnSpo2 INTEGER NOT NULL,
        $columnIr INTEGER NOT NULL, $columnRed INTEGER NOT NULL, $columnWifi INTEGER NOT NULL,
        $columnTimestamp INTEGER NOT NULL UNIQUE,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        $columnTemp REAL NULL,  -- <<< THÊM CỘT TEMP >>>
        $columnPres REAL NULL   -- <<< THÊM CỘT PRES >>>
      )
      ''');
    // Tạo Index
    await db.execute(
        'CREATE INDEX idx_timestamp ON $tableHealthRecords ($columnTimestamp)');
    await db.execute(
        'CREATE INDEX idx_is_synced ON $tableHealthRecords ($columnIsSynced)');
    print("Database table '$tableHealthRecords' created.");
  }

  // --- Hàm xử lý nâng cấp cấu trúc DB ---
  // Được gọi tự động khi version trong openDatabase cao hơn version DB hiện có
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Upgrading database from version $oldVersion to $newVersion...");
    // Chạy các lệnh ALTER TABLE tuần tự cho từng phiên bản cần nâng cấp
    if (oldVersion < 2) {
      // Nâng cấp từ v1 lên v2: Thêm cột temp và pres
      try {
        await db.execute(
            'ALTER TABLE $tableHealthRecords ADD COLUMN $columnTemp REAL NULL');
        print("Added column: $columnTemp");
      } catch (e) {
        print("Error adding column $columnTemp (maybe already exists?): $e");
      }
      try {
        await db.execute(
            'ALTER TABLE $tableHealthRecords ADD COLUMN $columnPres REAL NULL');
        print("Added column: $columnPres");
      } catch (e) {
        print("Error adding column $columnPres (maybe already exists?): $e");
      }
    }
    // Thêm các khối `if (oldVersion < 3)`... cho các lần nâng cấp sau này
    print("Database upgrade complete.");
  }

  // --- Lưu một bản ghi HealthData vào bảng cục bộ ---
  Future<int> saveHealthRecordLocally(HealthData data) async {
    try {
      final db = await database;
      // Chuyển đổi HealthData thành Map cho SQLite
      Map<String, dynamic> row = {
        columnAx: data.ax, columnAy: data.ay, columnAz: data.az,
        columnGx: data.gx, columnGy: data.gy, columnGz: data.gz,
        columnSteps: data.steps, columnHr: data.hr, columnSpo2: data.spo2,
        columnIr: data.ir, columnRed: data.red,
        columnWifi: data.wifi ? 1 : 0,
        columnTimestamp:
            data.timestamp.toUtc().millisecondsSinceEpoch, // Luôn lưu UTC ms
        columnIsSynced: 0,
        // <<< THÊM GIÁ TRỊ CHO CỘT MỚI >>>
        columnTemp: data.temperature, // Kiểu double? tương ứng với REAL NULL
        columnPres: data.pressure, // Kiểu double? tương ứng với REAL NULL
      };

      // Insert vào bảng, bỏ qua nếu có bản ghi trùng timestamp
      final id = await db.insert(tableHealthRecords, row,
          conflictAlgorithm: ConflictAlgorithm.ignore);

      if (id > 0) {/* Log thành công (nếu cần) */} else if (id == 0) {
        print(
            "Skipped saving duplicate local record for timestamp: ${data.timestamp.toIso8601String()}");
      }
      return id;
    } catch (e) {
      print("!!! Error saving health record locally: $e");
      return -1; // Báo lỗi
    }
  }

  // --- Lấy các bản ghi chưa đồng bộ ---
  Future<List<Map<String, dynamic>>> getUnsyncedHealthRecords(
      {int limit = 50}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableHealthRecords,
        columns: null,
        where: '$columnIsSynced = ?',
        whereArgs: [0],
        orderBy: '$columnTimestamp ASC',
        limit: limit,
      );
      if (maps.isNotEmpty) {/* Log số lượng (nếu cần) */}
      return maps;
    } catch (e) {
      print("!!! Error getting unsynced health records: $e");
      return [];
    }
  }

  // --- Đánh dấu các bản ghi đã đồng bộ ---
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
      print(
          "Marked $count records as synced (IDs: ${recordIds.length > 5 ? recordIds.sublist(0, 5).toString() + '...' : recordIds}).");
      return count;
    } catch (e) {
      print("!!! Error marking records as synced: $e");
      return -1;
    }
  }

  // --- (Tùy chọn) Xóa các bản ghi theo ID ---
  Future<int> deleteRecordsByIds(List<int> recordIds) async {
    if (recordIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.delete(
        tableHealthRecords,
        where: '$columnId IN ($placeholders)',
        whereArgs: recordIds,
      );
      print("Deleted $count records by IDs.");
      return count;
    } catch (e) {
      print("!!! Error deleting records by IDs: $e");
      return -1;
    }
  }

  // --- (Tùy chọn) Đếm số bản ghi chưa đồng bộ ---
  Future<int> countUnsyncedRecords() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableHealthRecords WHERE $columnIsSynced = 0',
      ));
      return count ?? 0;
    } catch (e) {
      print("!!! Error counting unsynced records: $e");
      return 0;
    }
  }

  // --- (Tùy chọn) Đóng database ---
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      print("Database connection closed.");
    }
  }

  // --- (Tùy chọn) Xóa file database ---
  Future<void> deleteDatabaseFile() async {
    try {
      await closeDatabase();
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      await deleteDatabase(path);
      print("Database file deleted: $path");
    } catch (e) {
      print("!!! Error deleting database file: $e");
    }
  }
}

// --- Helper (Đã cập nhật - có thể để ở file khác) ---
HealthData healthDataFromDbMap(Map<String, dynamic> map) {
  double? parseNullableDoubleFromDb(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  return HealthData(
    ax: (map[LocalDbService.columnAx] as num?)?.toDouble() ?? 0.0,
    ay: (map[LocalDbService.columnAy] as num?)?.toDouble() ?? 0.0,
    az: (map[LocalDbService.columnAz] as num?)?.toDouble() ?? 0.0,
    gx: (map[LocalDbService.columnGx] as num?)?.toDouble() ?? 0.0,
    gy: (map[LocalDbService.columnGy] as num?)?.toDouble() ?? 0.0,
    gz: (map[LocalDbService.columnGz] as num?)?.toDouble() ?? 0.0,
    steps: (map[LocalDbService.columnSteps] as num?)?.toInt() ?? 0,
    hr: (map[LocalDbService.columnHr] as num?)?.toInt() ?? -1,
    spo2: (map[LocalDbService.columnSpo2] as num?)?.toInt() ?? -1,
    ir: (map[LocalDbService.columnIr] as num?)?.toInt() ?? 0,
    red: (map[LocalDbService.columnRed] as num?)?.toInt() ?? 0,
    wifi: (map[LocalDbService.columnWifi] as int?) == 1,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
        map[LocalDbService.columnTimestamp] as int? ?? 0,
        isUtc: true),
    temperature: parseNullableDoubleFromDb(map[LocalDbService.columnTemp]),
    pressure: parseNullableDoubleFromDb(map[LocalDbService.columnPres]),
  );
}
