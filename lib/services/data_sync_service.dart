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
    // ... (Nội dung hàm syncOfflineData giữ nguyên như code bạn đã có) ...
    if (_isSyncing) {
      /* ... */
      return;
    }
    if (!_connectivityService.isOnline()) {
      /* ... */
      return;
    }
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      /* ... */
      return;
    }

    _isSyncing = true;
    print(
      "[DataSyncService] Starting offline data sync for user: ${currentUser.uid}",
    );

    try {
      int totalSyncedInThisRun = 0;
      bool hasMoreData = true;
      const int batchLimit = 100; // Đổi thành const

      while (hasMoreData && _connectivityService.isOnline()) {
        final unsyncedRecords = await _localDbService.getUnsyncedHealthRecords(
          limit: batchLimit,
        );

        if (unsyncedRecords.isEmpty) {
          hasMoreData = false;
          print("[DataSyncService] No more unsynced records found.");
          break;
        }

        print(
          "[DataSyncService] Found ${unsyncedRecords.length} records to sync.",
        );
        final WriteBatch batch = _firestoreService.firestoreInstance.batch();
        final List<int> recordIdsInBatch = [];

        for (final recordMap in unsyncedRecords) {
          final recordId = recordMap[LocalDbService.columnId] as int?;
          if (recordId == null) {
            print("!!! Skipping record with null ID");
            continue;
          }
          try {
            final healthData = HealthData.fromDbMap(recordMap);
            final firestoreData = healthData.toJsonForFirestore();
            final docRef =
                _firestoreService.firestoreInstance
                    .collection(AppConstants.usersCollection)
                    .doc(currentUser.uid)
                    .collection(AppConstants.healthDataSubcollection)
                    .doc();
            batch.set(docRef, firestoreData);
            recordIdsInBatch.add(recordId);
          } catch (e) {
            print("!!! Error processing record ID $recordId: $e");
          }
        }

        if (recordIdsInBatch.isNotEmpty) {
          try {
            print(
              "[DataSyncService] Committing batch (${recordIdsInBatch.length} records)...",
            );
            await batch.commit();
            print("[DataSyncService] Batch committed.");
            final deletedCount = await _localDbService.deleteRecordsByIds(
              recordIdsInBatch,
            );
            if (deletedCount > 0) {
              totalSyncedInThisRun += deletedCount;
              print(
                "[DataSyncService] Deleted $deletedCount synced records locally.",
              );
            } else {
              print("!!! Failed to delete local records for batch.");
              hasMoreData = false; // Stop if local delete fails
            }
          } catch (e) {
            print("!!! Error committing Firestore batch: $e");
            hasMoreData = false; // Stop sync cycle on Firestore error
          }
        } else {
          print("[DataSyncService] Batch empty, stopping.");
          hasMoreData = false;
        }
      }
      print(
        "[DataSyncService] Sync cycle finished. Total synced: $totalSyncedInThisRun",
      );
    } catch (e) {
      print("!!! Error during sync process: $e");
    } finally {
      _isSyncing = false;
      print("[DataSyncService] Sync flag reset.");
    }
  }

  void dispose() {
    print("Disposing DataSyncService...");
    _connectivitySubscription?.cancel();
    print("DataSyncService disposed.");
  }
}
