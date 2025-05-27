// lib/services/data_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Cho kDebugMode

// Import các file cục bộ
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'firestore_service.dart';
import 'local_db_service.dart'; // LocalDbService đã được cập nhật
import '../models/health_data.dart'; // Model HealthData với fromDbMap và toJsonForFirestore
import '../app_constants.dart'; // Chứa các hằng số như collection names, batch limit

class DataSyncService {
  final ConnectivityService _connectivityService;
  final LocalDbService _localDbService;
  final FirestoreService _firestoreService;
  final AuthService _authService;

  StreamSubscription? _connectivitySubscription;
  bool _isSyncingHealthData = false; // Cờ riêng cho health data sync
  bool _wasOffline = true;

  DataSyncService(
    this._connectivityService,
    this._localDbService,
    this._firestoreService,
    this._authService,
  ) {
    _initialize();
    if (kDebugMode) print("[DataSyncService] Initialized.");
  }

  void _initialize() {
    _wasOffline = !_connectivityService.isOnline();
    if (kDebugMode) {
      print(
          "[DataSyncService] Initial network state is ${_wasOffline ? 'Offline' : 'Online'}");
    }

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivityService.networkStatusStream.listen(
      _handleNetworkChange,
    );

    // Kích hoạt đồng bộ lần đầu nếu khởi động online và đã đăng nhập
    if (!_wasOffline && _authService.currentUser != null) {
      if (kDebugMode) {
        print(
            "[DataSyncService] App started online and user logged in. Triggering initial health data sync check...");
      }
      Future.delayed(const Duration(seconds: 10),
          syncOfflineHealthData); // Delay lâu hơn chút
    }
  }

  void _handleNetworkChange(NetworkStatus status) {
    if (kDebugMode) {
      print(
          "[DataSyncService] _handleNetworkChange received: $status. Current _wasOffline: $_wasOffline");
    }
    final bool isCurrentlyOnline = (status == NetworkStatus.online);

    if (isCurrentlyOnline && _wasOffline) {
      if (kDebugMode)
        print("[DataSyncService] Network came ONLINE from OFFLINE.");
      _wasOffline = false; // Cập nhật trạng thái trước
      if (_authService.currentUser != null) {
        // Chỉ đồng bộ nếu đã đăng nhập
        if (kDebugMode)
          print(
              "[DataSyncService] Triggering health data sync due to network change...");
        syncOfflineHealthData();
      } else {
        if (kDebugMode)
          print(
              "[DataSyncService] Network online, but user not logged in. Sync deferred.");
      }
    } else if (!isCurrentlyOnline) {
      if (!_wasOffline && kDebugMode) {
        // Chỉ log nếu trước đó đang online
        print("[DataSyncService] Network went OFFLINE.");
      }
      _wasOffline = true;
    }
  }

  // Đồng bộ HealthData từ SQLite lên Firestore
  Future<void> syncOfflineHealthData() async {
    if (_isSyncingHealthData) {
      if (kDebugMode)
        print(
            "[DataSyncService] HealthData sync already in progress. Skipping.");
      return;
    }
    if (!_connectivityService.isOnline()) {
      if (kDebugMode)
        print(
            "[DataSyncService] No network connection. Skipping HealthData sync.");
      return;
    }
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode)
        print(
            "[DataSyncService] User not logged in. Skipping HealthData sync.");
      return;
    }

    _isSyncingHealthData = true;
    if (kDebugMode)
      print(
          "[DataSyncService] Starting offline HealthData sync for user: ${currentUser.uid}");

    try {
      int totalHealthDataSyncedInThisRun = 0;
      bool hasMoreHealthData = true;
      // Sử dụng hằng số từ AppConstants
      const int healthDataBatchLimit = AppConstants.firestoreSyncBatchLimit;

      while (hasMoreHealthData && _connectivityService.isOnline()) {
        // Sử dụng hàm getUnsyncedHealthRecords (trả về List<Map<String, dynamic>>)
        final List<Map<String, dynamic>> unsyncedRecordMaps =
            await _localDbService.getUnsyncedHealthRecords(
                limit: healthDataBatchLimit);

        if (unsyncedRecordMaps.isEmpty) {
          hasMoreHealthData = false;
          if (kDebugMode)
            print("[DataSyncService] No more unsynced health records found.");
          break;
        }

        if (kDebugMode)
          print(
              "[DataSyncService] Found ${unsyncedRecordMaps.length} health records to sync in this batch.");
        final WriteBatch batch = _firestoreService.firestoreInstance.batch();
        final List<int> recordIdsInBatchToMark = [];

        for (final recordMap in unsyncedRecordMaps) {
          final recordId = recordMap[LocalDbService.columnId] as int?;
          if (recordId == null) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Skipping health record with null local ID");
            continue;
          }

          try {
            // Chuyển đổi Map từ DB sang HealthData object
            final healthData = HealthData.fromDbMap(recordMap);

            // Chuẩn bị dữ liệu cho Firestore
            final Map<String, dynamic> dataForFirestore =
                healthData.toJsonForFirestore();
            // Thêm timestamp chuẩn của Firestore, LƯU Ý: healthData.timestamp đã là UTC
            dataForFirestore['recordedAt'] =
                Timestamp.fromDate(healthData.timestamp);

            // Tạo document mới trên Firestore
            final docRef = _firestoreService.firestoreInstance
                .collection(AppConstants.usersCollection)
                .doc(currentUser.uid)
                .collection(AppConstants.healthDataSubcollection)
                .doc(); // Firestore tự tạo ID

            batch.set(docRef, dataForFirestore);
            recordIdsInBatchToMark.add(recordId);
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error processing local health record ID $recordId during sync prep: $e");
          }
        }

        if (recordIdsInBatchToMark.isNotEmpty) {
          try {
            if (kDebugMode)
              print(
                  "[DataSyncService] Committing Firestore batch for health data (${recordIdsInBatchToMark.length} records)...");
            await batch.commit();
            if (kDebugMode)
              print(
                  "[DataSyncService] Health data batch committed successfully.");

            // Đánh dấu các bản ghi đã đồng bộ thành công trong SQLite
            final int markedCount = await _localDbService
                .markRecordsAsSynced(recordIdsInBatchToMark);

            if (markedCount >= 0) {
              totalHealthDataSyncedInThisRun += markedCount;
              if (kDebugMode)
                print(
                    "[DataSyncService] Marked $markedCount synced health records locally.");
              if (markedCount < recordIdsInBatchToMark.length) {
                if (kDebugMode)
                  print(
                      "!!! [DataSyncService] Warning: Marked health records count ($markedCount) is less than batch size (${recordIdsInBatchToMark.length}).");
              }
            } else {
              if (kDebugMode)
                print(
                    "!!! [DataSyncService] Error marking local health records as synced (returned $markedCount). Stopping sync for this cycle.");
              hasMoreHealthData = false; // Dừng nếu đánh dấu lỗi
            }
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error committing Firestore health data batch or marking local records: $e");
            hasMoreHealthData =
                false; // Dừng đồng bộ nếu không ghi được lên Firestore hoặc không đánh dấu được
          }
        } else {
          if (kDebugMode)
            print(
                "[DataSyncService] Health data batch was empty after processing records. Stopping for this cycle.");
          hasMoreHealthData = false;
        }

        if (hasMoreHealthData && _connectivityService.isOnline()) {
          await Future.delayed(const Duration(milliseconds: 500)); // Delay nhỏ
        }
      } // Kết thúc while

      if (kDebugMode)
        print(
            "[DataSyncService] HealthData sync cycle finished. Total records marked as synced in this run: $totalHealthDataSyncedInThisRun");
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [DataSyncService] Error during overall HealthData sync process: $e");
    } finally {
      _isSyncingHealthData = false;
      if (kDebugMode)
        print("[DataSyncService] HealthData sync flag reset to false.");
    }
  }

  // TODO: Thêm hàm syncOfflineActivitySegments() tương tự nếu bạn muốn đồng bộ ActivitySegment

  void dispose() {
    if (kDebugMode) print("[DataSyncService] Disposing...");
    _connectivitySubscription?.cancel();
    if (kDebugMode) print("[DataSyncService] Disposed.");
  }
}
