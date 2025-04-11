// lib/services/local_db_service.dart
import 'package:path/path.dart'; // Cần để join đường dẫn
import 'package:sqflite/sqflite.dart'; // Thư viện SQLite chính
import 'package:path_provider/path_provider.dart'; // Để lấy đường dẫn lưu trữ phù hợp
import 'dart:async'; // Cho Future
import '../models/health_data.dart'; // Import model HealthData

class LocalDbService {
  static const _databaseName = "health_data_v1.db"; // Thêm version vào tên file
  static const _databaseVersion = 1; // Version của cấu trúc DB

  static const tableHealthRecords = 'health_records'; // Tên bảng

  // --- Định nghĩa tên các cột trong bảng ---
  static const columnId = '_id'; // Dùng dấu gạch dưới cho ID theo convention
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
  static const columnWifi = 'wifi'; // Lưu dạng INTEGER (0 = false, 1 = true)
  static const columnTimestamp =
      'timestamp'; // Lưu dạng INTEGER (Unix milliseconds UTC)
  static const columnIsSynced =
      'is_synced'; // Lưu dạng INTEGER (0 = false, 1 = true)

  // --- Singleton Pattern ---
  // Đảm bảo chỉ có một instance của LocalDbService và Database
  LocalDbService._privateConstructor();
  static final LocalDbService instance = LocalDbService._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    // Trả về database đã có nếu đã được khởi tạo
    if (_database != null) return _database!;
    // Nếu chưa, khởi tạo database
    _database = await _initDatabase();
    return _database!;
  }

  // --- Khởi tạo Database ---
  Future<Database> _initDatabase() async {
    final documentsDirectory =
        await getApplicationDocumentsDirectory(); // Lấy thư mục Documents của app
    final path = join(
      documentsDirectory.path,
      _databaseName,
    ); // Tạo đường dẫn đầy đủ tới file DB
    print("Database path: $path"); // Log đường dẫn để debug

    // Mở database (hoặc tạo nếu chưa có)
    return await openDatabase(
      path,
      version: _databaseVersion, // Version hiện tại
      onCreate: _onCreate, // Hàm được gọi khi DB được tạo lần đầu
      // onUpgrade: _onUpgrade, // Cần hàm này nếu bạn thay đổi version và cấu trúc DB
    );
  }

  // --- Tạo bảng khi DB được tạo lần đầu ---
  Future<void> _onCreate(Database db, int version) async {
    print("Creating database table '$tableHealthRecords'...");
    await db.execute('''
      CREATE TABLE $tableHealthRecords (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAx REAL NOT NULL,
        $columnAy REAL NOT NULL,
        $columnAz REAL NOT NULL,
        $columnGx REAL NOT NULL,
        $columnGy REAL NOT NULL,
        $columnGz REAL NOT NULL,
        $columnSteps INTEGER NOT NULL,
        $columnHr INTEGER NOT NULL,
        $columnSpo2 INTEGER NOT NULL,
        $columnIr INTEGER NOT NULL,
        $columnRed INTEGER NOT NULL,
        $columnWifi INTEGER NOT NULL CHECK($columnWifi IN (0, 1)),
        $columnTimestamp INTEGER NOT NULL UNIQUE,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0 CHECK($columnIsSynced IN (0, 1))
      )
      ''');
    // Tạo Index để tăng tốc độ truy vấn các cột thường dùng trong WHERE hoặc ORDER BY
    await db.execute(
      'CREATE INDEX idx_timestamp ON $tableHealthRecords ($columnTimestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_is_synced ON $tableHealthRecords ($columnIsSynced)',
    );
    print("Database table '$tableHealthRecords' created with indexes.");
  }

  // --- Các hàm CRUD (Create, Read, Update, Delete) ---

  /// Lưu một bản ghi HealthData vào bảng cục bộ.
  /// Trạng thái is_synced sẽ được đặt là 0 (chưa đồng bộ).
  /// Sử dụng conflictAlgorithm.ignore để bỏ qua nếu timestamp đã tồn tại.
  Future<int> saveHealthRecordLocally(HealthData data) async {
    try {
      final db = await database;
      // Chuyển đổi HealthData thành Map cho SQLite
      Map<String, dynamic> row = {
        // columnId không cần cung cấp vì nó là AUTOINCREMENT
        columnAx: data.ax,
        columnAy: data.ay,
        columnAz: data.az,
        columnGx: data.gx,
        columnGy: data.gy,
        columnGz: data.gz,
        columnSteps: data.steps,
        columnHr: data.hr,
        columnSpo2: data.spo2,
        columnIr: data.ir,
        columnRed: data.red,
        columnWifi:
            data.wifi ? 1 : 0, // Chuyển bool thành int (1=true, 0=false)
        columnTimestamp:
            data.timestamp
                .toUtc()
                .millisecondsSinceEpoch, // Lưu timestamp dạng UTC milliseconds
        columnIsSynced: 0, // Mặc định là chưa đồng bộ
      };

      // Insert vào bảng, bỏ qua nếu có bản ghi trùng timestamp
      final id = await db.insert(
        tableHealthRecords,
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (id > 0) {
        // print("Saved health record locally with ID: $id, Timestamp: ${data.timestamp.toIso8601String()}");
      } else if (id == 0) {
        // id = 0 nghĩa là không có hàng nào được chèn (do conflict)
        print(
          "Skipped saving duplicate local record for timestamp: ${data.timestamp.toIso8601String()}",
        );
      }
      return id; // Trả về ID của hàng mới được chèn, hoặc 0 nếu bị ignore
    } catch (e) {
      print("!!! Error saving health record locally: $e");
      return -1; // Trả về giá trị âm để báo lỗi
    }
  }

  /// Lấy danh sách các bản ghi HealthData chưa được đồng bộ (is_synced = 0).
  /// Trả về List các Map, mỗi Map chứa dữ liệu của một hàng bao gồm cả '_id'.
  /// Sắp xếp theo timestamp cũ nhất trước.
  /// [limit]: Giới hạn số lượng bản ghi trả về (mặc định 50).
  Future<List<Map<String, dynamic>>> getUnsyncedHealthRecords({
    int limit = 50,
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableHealthRecords,
        columns: null, // Lấy tất cả các cột
        where: '$columnIsSynced = ?', // Điều kiện lọc
        whereArgs: [0], // Giá trị cho điều kiện where (is_synced = 0)
        orderBy:
            '$columnTimestamp ASC', // Sắp xếp theo timestamp tăng dần (cũ trước)
        limit: limit, // Giới hạn số lượng kết quả
      );
      if (maps.isNotEmpty) {
        print("Found ${maps.length} unsynced health records (limit $limit).");
      }
      return maps;
    } catch (e) {
      print("!!! Error getting unsynced health records: $e");
      return []; // Trả về danh sách rỗng nếu có lỗi
    }
  }

  /// Đánh dấu một danh sách các bản ghi là đã đồng bộ (cập nhật is_synced = 1).
  /// [recordIds]: Danh sách các '_id' của bản ghi cần cập nhật.
  /// Trả về số lượng hàng đã được cập nhật, hoặc -1 nếu có lỗi.
  Future<int> markRecordsAsSynced(List<int> recordIds) async {
    if (recordIds.isEmpty) {
      print("markRecordsAsSynced called with empty list.");
      return 0; // Không có gì để cập nhật
    }
    try {
      final db = await database;
      // Tạo chuỗi placeholders (?, ?, ...) cho mệnh đề WHERE IN
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.update(
        tableHealthRecords,
        {columnIsSynced: 1}, // Dữ liệu cần cập nhật
        where:
            '$columnId IN ($placeholders)', // Điều kiện: _id nằm trong danh sách
        whereArgs: recordIds, // Danh sách các ID
      );
      print("Marked $count records as synced (IDs: $recordIds).");
      return count; // Trả về số hàng bị ảnh hưởng
    } catch (e) {
      print("!!! Error marking records as synced: $e");
      return -1; // Báo lỗi
    }
  }

  /// (Tùy chọn) Xóa các bản ghi dựa trên danh sách ID.
  /// Hữu ích nếu bạn muốn xóa thay vì chỉ đánh dấu là đã đồng bộ.
  Future<int> deleteRecordsByIds(List<int> recordIds) async {
    if (recordIds.isEmpty) {
      print("deleteRecordsByIds called with empty list.");
      return 0;
    }
    try {
      final db = await database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final count = await db.delete(
        tableHealthRecords,
        where: '$columnId IN ($placeholders)',
        whereArgs: recordIds,
      );
      print("Deleted $count records (IDs: $recordIds).");
      return count;
    } catch (e) {
      print("!!! Error deleting records by IDs: $e");
      return -1;
    }
  }

  /// (Tùy chọn) Đếm tổng số bản ghi chưa đồng bộ.
  Future<int> countUnsyncedRecords() async {
    try {
      final db = await database;
      // Sử dụng helper `firstIntValue` để lấy giá trị COUNT(*)
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $tableHealthRecords WHERE $columnIsSynced = 0',
        ),
      );
      return count ?? 0; // Trả về 0 nếu count là null
    } catch (e) {
      print("!!! Error counting unsynced records: $e");
      return 0; // Trả về 0 nếu có lỗi
    }
  }

  /// (Tùy chọn) Đóng database connection.
  /// Thường không cần gọi thủ công vì nó sẽ tự đóng khi app đóng.
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      print("Database connection closed.");
    }
  }

  /// (Tùy chọn) Xóa hoàn toàn file database (chỉ dùng để debug/reset).
  Future<void> deleteDatabaseFile() async {
    try {
      await closeDatabase(); // Đảm bảo đóng kết nối trước khi xóa
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      await deleteDatabase(path);
      print("Database file deleted: $path");
    } catch (e) {
      print("!!! Error deleting database file: $e");
    }
  }
}

// --- Helper để chuyển đổi Map từ DB thành HealthData ---
// Đặt ở đây hoặc trong file model HealthData
HealthData healthDataFromDbMap(Map<String, dynamic> map) {
  // Lấy giá trị từ map, kiểm tra null hoặc dùng giá trị mặc định nếu cần
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
    wifi:
        (map[LocalDbService.columnWifi] as int?) == 1, // Chuyển int thành bool
    // Chuyển int milliseconds (UTC) thành DateTime (Local)
    timestamp:
        DateTime.fromMillisecondsSinceEpoch(
          map[LocalDbService.columnTimestamp] as int? ?? 0,
          isUtc: true,
        ).toLocal(),
  );
}
