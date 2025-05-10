// lib/services/data_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'firestore_service.dart';
import 'local_db_service.dart';
import '../models/health_data.dart';
import '../app_constants.dart'; // Đảm bảo import này đúng

class DataSyncService {
  final ConnectivityService _connectivityService;
  final LocalDbService _localDbService;
  final FirestoreService _firestoreService;
  final AuthService _authService;

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _wasOffline = true; // Giả định ban đầu là offline hoặc chưa biết

  DataSyncService(
    this._connectivityService,
    this._localDbService,
    this._firestoreService,
    this._authService,
  ) {
    _initialize();
    print("DataSyncService Initialized.");
  }

  void _initialize() {
    // Lấy trạng thái ban đầu và đặt _wasOffline
    _wasOffline = !_connectivityService.isOnline();
    print(
      "[DataSyncService] Initial network state is ${_wasOffline ? 'Offline' : 'Online'}",
    );

    // Lắng nghe thay đổi trạng thái mạng và gọi hàm xử lý riêng
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivityService.networkStatusStream.listen(
      _handleNetworkChange,
    ); // <<< GỌI HÀM RIÊNG

    // Kích hoạt kiểm tra đồng bộ lần đầu nếu khởi động online
    if (!_wasOffline) {
      print(
        "[DataSyncService] App started online. Triggering initial sync check...",
      );
      // Delay nhỏ để đảm bảo mọi thứ sẵn sàng
      Future.delayed(const Duration(seconds: 3), syncOfflineData);
    }
  }

  // --- HÀM XỬ LÝ THAY ĐỔI MẠNG ---
  void _handleNetworkChange(NetworkStatus status) {
    print(
      "[DataSyncService] _handleNetworkChange received: $status. Current _wasOffline: $_wasOffline",
    );
    final bool isCurrentlyOnline = (status == NetworkStatus.online);

    // Chỉ kích hoạt đồng bộ khi chuyển từ OFFLINE sang ONLINE
    if (isCurrentlyOnline && _wasOffline) {
      print(
        "[DataSyncService] Condition met: Network came ONLINE from OFFLINE. Triggering data sync...",
      );
      _wasOffline = false; // Cập nhật trạng thái NGAY TRƯỚC KHI gọi sync
      syncOfflineData();
    } else if (!isCurrentlyOnline) {
      // Nếu chuyển sang offline, cập nhật lại cờ
      if (!_wasOffline) {
        // Chỉ log nếu trước đó đang online
        print("[DataSyncService] Condition met: Network went OFFLINE.");
      }
      _wasOffline = true;
    } else {
      // Trường hợp đang online và vẫn nhận sự kiện online (không cần làm gì)
      // Hoặc trường hợp lạ khác
      print(
        "[DataSyncService] Condition NOT met for sync trigger (isOnline: $isCurrentlyOnline, wasOffline: $_wasOffline).",
      );
    }
  }

  // ---------------------------------
  Future<void> syncOfflineData() async {
    if (_isSyncing) {
      print("[DataSyncService] Sync already in progress. Skipping.");
      return;
    }
    if (!_connectivityService.isOnline()) {
      print("[DataSyncService] No network connection. Skipping sync.");
      return;
    }
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      print("[DataSyncService] User not logged in. Skipping sync.");
      return;
    }

    _isSyncing = true;
    print(
        "[DataSyncService] Starting offline data sync for user: ${currentUser.uid}");

    try {
      int totalSyncedInThisRun = 0;
      bool hasMoreData = true;
      const int batchLimit = 100; // Giới hạn số lượng documents mỗi batch

      while (hasMoreData && _connectivityService.isOnline()) {
        // Kiểm tra mạng mỗi vòng lặp
        final unsyncedRecords = await _localDbService.getUnsyncedHealthRecords(
          limit: batchLimit,
        );

        if (unsyncedRecords.isEmpty) {
          hasMoreData = false;
          print("[DataSyncService] No more unsynced records found.");
          break; // Thoát vòng lặp while
        }

        print(
            "[DataSyncService] Found ${unsyncedRecords.length} records to sync in this batch.");
        final WriteBatch batch = _firestoreService.firestoreInstance.batch();
        final List<int> recordIdsInBatch = []; // Lưu ID của SQLite để xóa sau

        for (final recordMap in unsyncedRecords) {
          final recordId = recordMap[LocalDbService.columnId] as int?;
          if (recordId == null) {
            print("!!! [DataSyncService] Skipping record with null local ID");
            continue;
          }

          try {
            // 1. Tạo HealthData object từ dữ liệu SQLite
            final healthData = HealthData.fromDbMap(recordMap);

            // <<< SỬA PHẦN CHUẨN BỊ DATA CHO FIRESTORE >>>
            // 2. Tạo Map dữ liệu cho Firestore từ HealthData object
            //    Bắt đầu bằng Map từ toJsonForFirestore (không có recordedAt)
            final Map<String, dynamic> dataForFirestore =
                healthData.toJsonForFirestore();

            // 3. Thêm trường 'recordedAt' vào Map, lấy từ timestamp của HealthData
            //    Đảm bảo timestamp này là UTC
            dataForFirestore['recordedAt'] =
                Timestamp.fromDate(healthData.timestamp.toUtc());
            // -------------------------------------------------

            // 4. Tạo tham chiếu document mới trên Firestore
            //    Dùng .doc() để Firestore tự tạo ID duy nhất
            final docRef = _firestoreService.firestoreInstance
                .collection(AppConstants.usersCollection)
                .doc(currentUser.uid)
                .collection(AppConstants.healthDataSubcollection)
                .doc(); // ID mới tự động

            // 5. Thêm lệnh set vào WriteBatch
            batch.set(docRef, dataForFirestore); // Dùng Map đã chuẩn bị đầy đủ

            // 6. Thêm ID của bản ghi SQLite vào danh sách để xóa sau
            recordIdsInBatch.add(recordId);
          } catch (e) {
            // Lỗi khi xử lý một bản ghi cụ thể (ví dụ: parse lỗi - ít xảy ra vì đã lưu)
            print(
                "!!! [DataSyncService] Error processing local record ID $recordId during sync prep: $e");
            // Có thể bỏ qua bản ghi này hoặc dừng toàn bộ batch tùy chiến lược
          }
        }

        // Chỉ commit và xóa nếu batch có dữ liệu và có ID để xóa
        if (recordIdsInBatch.isNotEmpty) {
          try {
            print(
                "[DataSyncService] Committing Firestore batch (${recordIdsInBatch.length} records)...");
            await batch.commit(); // Gửi batch lên Firestore
            print("[DataSyncService] Batch committed successfully.");

            // Xóa các bản ghi đã đồng bộ thành công khỏi SQLite
            final deletedCount =
                await _localDbService.deleteRecordsByIds(recordIdsInBatch);
            // Hoặc nếu chỉ muốn đánh dấu:
            // final updatedCount = await _localDbService.markRecordsAsSynced(recordIdsInBatch);

            if (deletedCount >= 0) {
              // Hàm delete trả về số hàng bị xóa (>=0)
              totalSyncedInThisRun += deletedCount;
              print(
                  "[DataSyncService] Deleted $deletedCount synced records locally.");
              // Nếu số lượng xóa ít hơn số lượng trong batch -> có lỗi tiềm ẩn
              if (deletedCount < recordIdsInBatch.length) {
                print(
                    "!!! [DataSyncService] Warning: Deleted count ($deletedCount) is less than batch size (${recordIdsInBatch.length}). Some local records might not have been deleted.");
              }
            } else {
              // Hàm delete trả về -1 nếu có lỗi
              print(
                  "!!! [DataSyncService] Error deleting local records for batch (returned $deletedCount). Stopping sync.");
              hasMoreData = false; // Dừng nếu xóa lỗi
            }
          } catch (e) {
            // Lỗi khi commit batch lên Firestore
            print("!!! [DataSyncService] Error committing Firestore batch: $e");
            hasMoreData =
                false; // Dừng đồng bộ nếu không ghi được lên Firestore
          }
        } else {
          // Không có bản ghi hợp lệ nào trong batch này để xử lý
          print(
              "[DataSyncService] Batch was empty after processing records. Stopping.");
          hasMoreData = false;
        }

        // Delay nhỏ giữa các batch để tránh quá tải (tùy chọn)
        if (hasMoreData)
          await Future.delayed(const Duration(milliseconds: 200));
      } // Kết thúc while(hasMoreData)

      print(
          "[DataSyncService] Sync cycle finished. Total records processed in this run: $totalSyncedInThisRun");
    } catch (e) {
      // Lỗi chung trong quá trình đồng bộ (ví dụ: lỗi đọc SQLite ban đầu)
      print("!!! [DataSyncService] Error during overall sync process: $e");
    } finally {
      _isSyncing = false; // Luôn reset cờ syncing
      print("[DataSyncService] Sync flag reset to false.");
    }
  }

  void dispose() {
    print("Disposing DataSyncService...");
    _connectivitySubscription?.cancel();
    print("DataSyncService disposed.");
  }
}
