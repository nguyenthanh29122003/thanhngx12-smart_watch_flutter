// lib/services/data_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'connectivity_service.dart';
import 'firestore_service.dart';
import 'local_db_service.dart';
import '../models/health_data.dart';
import '../models/activity_segment.dart';
import '../app_constants.dart';

class DataSyncService {
  final ConnectivityService _connectivityService;
  final LocalDbService _localDbService;
  final FirestoreService _firestoreService;
  final AuthService _authService;

  StreamSubscription? _connectivitySubscription;
  bool _isSyncingHealthData = false;
  bool _isSyncingActivitySegments = false; // Cờ mới
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

    if (!_wasOffline && _authService.currentUser != null) {
      if (kDebugMode)
        print(
            "[DataSyncService] App started online and user logged in. Triggering initial sync checks...");
      Future.delayed(const Duration(seconds: 8), () {
        // Delay chung, có thể tách ra
        syncOfflineHealthData();
        syncOfflineActivitySegments();
      });
    }
  }

  void _handleNetworkChange(NetworkStatus status) {
    if (kDebugMode)
      print(
          "[DataSyncService] _handleNetworkChange received: $status. Current _wasOffline: $_wasOffline");
    final bool isCurrentlyOnline = (status == NetworkStatus.online);

    if (isCurrentlyOnline && _wasOffline) {
      if (kDebugMode)
        print("[DataSyncService] Network came ONLINE from OFFLINE.");
      _wasOffline = false;
      if (_authService.currentUser != null) {
        if (kDebugMode)
          print(
              "[DataSyncService] Triggering ALL data sync due to network change...");
        syncOfflineHealthData();
        syncOfflineActivitySegments();
      } else {
        if (kDebugMode)
          print(
              "[DataSyncService] Network online, but user not logged in. Sync deferred.");
      }
    } else if (!isCurrentlyOnline) {
      if (!_wasOffline && kDebugMode)
        print("[DataSyncService] Network went OFFLINE.");
      _wasOffline = true;
    }
  }

  // --- Đồng bộ HealthData (Giữ nguyên như phiên bản trước bạn đã có) ---
  Future<void> syncOfflineHealthData() async {
    if (_isSyncingHealthData) {
      if (kDebugMode)
        print(
            "[DataSyncService] HealthData sync already in progress. Skipping.");
      return;
    }
    if (!_connectivityService.isOnline() || _authService.currentUser == null) {
      if (kDebugMode)
        print(
            "[DataSyncService] Pre-conditions not met for HealthData sync (Network: ${_connectivityService.isOnline()}, User: ${_authService.currentUser != null}).");
      return;
    }
    final currentUser = _authService.currentUser!;
    _isSyncingHealthData = true;
    if (kDebugMode)
      print(
          "[DataSyncService] Starting offline HealthData sync for user: ${currentUser.uid}");

    try {
      int totalHealthDataSyncedInThisRun = 0;
      bool hasMoreHealthData = true;
      const int healthDataBatchLimit = AppConstants.firestoreSyncBatchLimit;

      while (hasMoreHealthData && _connectivityService.isOnline()) {
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
          if (recordId == null) continue;
          try {
            final healthData = HealthData.fromDbMap(recordMap);
            final Map<String, dynamic> dataForFirestore =
                healthData.toJsonForFirestore();
            dataForFirestore['recordedAt'] =
                Timestamp.fromDate(healthData.timestamp.toUtc());
            final docRef = _firestoreService.firestoreInstance
                .collection(AppConstants.usersCollection)
                .doc(currentUser.uid)
                .collection(AppConstants.healthDataSubcollection)
                .doc();
            batch.set(docRef, dataForFirestore);
            recordIdsInBatchToMark.add(recordId);
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error processing local health record ID $recordId for sync: $e");
          }
        }

        if (recordIdsInBatchToMark.isNotEmpty) {
          try {
            await batch.commit();
            if (kDebugMode)
              print(
                  "[DataSyncService] Health data batch committed successfully.");
            final int markedCount =
                await _localDbService.markHealthRecordsAsSynced(
                    recordIdsInBatchToMark); // Đổi tên hàm
            if (markedCount >= 0) {
              totalHealthDataSyncedInThisRun += markedCount;
              if (kDebugMode)
                print(
                    "[DataSyncService] Marked $markedCount synced health records locally.");
              if (markedCount < recordIdsInBatchToMark.length && kDebugMode) {
                print(
                    "!!! [DataSyncService] Warning: Marked health records count ($markedCount) is less than batch size (${recordIdsInBatchToMark.length}).");
              }
            } else {
              if (kDebugMode)
                print(
                    "!!! [DataSyncService] Error marking local health records as synced (returned $markedCount). Stopping sync.");
              hasMoreHealthData = false;
            }
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error committing Firestore health data batch or marking local: $e");
            hasMoreHealthData = false;
          }
        } else {
          if (kDebugMode)
            print(
                "[DataSyncService] Health data batch was empty after processing. Stopping.");
          hasMoreHealthData = false;
        }
        if (hasMoreHealthData && _connectivityService.isOnline())
          await Future.delayed(const Duration(milliseconds: 200));
      }
      if (kDebugMode)
        print(
            "[DataSyncService] HealthData sync cycle finished. Total marked: $totalHealthDataSyncedInThisRun");
    } catch (e) {
      if (kDebugMode)
        print("!!! [DataSyncService] Error during HealthData sync: $e");
    } finally {
      _isSyncingHealthData = false;
      if (kDebugMode)
        print("[DataSyncService] HealthData sync flag reset to false.");
    }
  }

  // --- HÀM ĐỒNG BỘ ACTIVITY SEGMENT (ĐÃ CUNG CẤP Ở TRÊN) ---
  Future<void> syncOfflineActivitySegments() async {
    if (_isSyncingActivitySegments) {
      if (kDebugMode)
        print(
            "[DataSyncService] ActivitySegment sync already in progress. Skipping.");
      return;
    }
    if (!_connectivityService.isOnline() || _authService.currentUser == null) {
      if (kDebugMode)
        print(
            "[DataSyncService] Pre-conditions not met for ActivitySegment sync (Network: ${_connectivityService.isOnline()}, User: ${_authService.currentUser != null}).");
      return;
    }
    final currentUser = _authService.currentUser!;

    _isSyncingActivitySegments = true;
    if (kDebugMode)
      print(
          "[DataSyncService] Starting offline ActivitySegment sync for user: ${currentUser.uid}");

    try {
      int totalSegmentsSyncedInThisRun = 0;
      bool hasMoreSegments = true;
      const int segmentBatchLimit = AppConstants.firestoreSyncBatchLimit;

      while (hasMoreSegments && _connectivityService.isOnline()) {
        final List<ActivitySegment> unsyncedSegments =
            await _localDbService.getUnsyncedActivitySegments(
                limit: segmentBatchLimit, userId: currentUser.uid);

        if (unsyncedSegments.isEmpty) {
          hasMoreSegments = false;
          if (kDebugMode)
            print(
                "[DataSyncService] No more unsynced activity segments found.");
          break;
        }

        if (kDebugMode)
          print(
              "[DataSyncService] Found ${unsyncedSegments.length} activity segments to sync in this batch.");
        final WriteBatch batch = _firestoreService.firestoreInstance.batch();
        final List<int> segmentIdsInBatchToMark = [];

        for (final segment in unsyncedSegments) {
          if (segment.id == null) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Skipping activity segment with null local ID: ${segment.activityName}");
            continue;
          }
          try {
            final Map<String, dynamic> dataForFirestore =
                segment.toJsonForFirestore();
            final docRef = _firestoreService.firestoreInstance
                .collection(AppConstants.usersCollection)
                .doc(currentUser.uid)
                .collection(AppConstants.activitySegmentsSubcollection)
                .doc();
            batch.set(docRef, dataForFirestore);
            segmentIdsInBatchToMark.add(segment.id!);
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error processing local activity segment ID ${segment.id} for sync: $e");
          }
        }

        if (segmentIdsInBatchToMark.isNotEmpty) {
          try {
            await batch.commit();
            if (kDebugMode)
              print(
                  "[DataSyncService] Activity segment batch committed successfully.");
            final int markedCount = await _localDbService
                .markActivitySegmentsAsSynced(segmentIdsInBatchToMark);
            if (markedCount >= 0) {
              totalSegmentsSyncedInThisRun += markedCount;
              if (kDebugMode)
                print(
                    "[DataSyncService] Marked $markedCount synced activity segments locally.");
              if (markedCount < segmentIdsInBatchToMark.length && kDebugMode) {
                print(
                    "!!! [DataSyncService] Warning: Marked activity segments count ($markedCount) is less than batch size (${segmentIdsInBatchToMark.length}).");
              }
            } else {
              if (kDebugMode)
                print(
                    "!!! [DataSyncService] Error marking local activity segments as synced (returned $markedCount). Stopping sync.");
              hasMoreSegments = false;
            }
          } catch (e) {
            if (kDebugMode)
              print(
                  "!!! [DataSyncService] Error committing Firestore activity segment batch or marking local: $e");
            hasMoreSegments = false;
          }
        } else {
          if (kDebugMode)
            print(
                "[DataSyncService] Activity segment batch was empty after processing. Stopping.");
          hasMoreSegments = false;
        }
        if (hasMoreSegments && _connectivityService.isOnline())
          await Future.delayed(const Duration(milliseconds: 200));
      }
      if (kDebugMode)
        print(
            "[DataSyncService] ActivitySegment sync cycle finished. Total marked: $totalSegmentsSyncedInThisRun");
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [DataSyncService] Error during overall ActivitySegment sync process: $e");
    } finally {
      _isSyncingActivitySegments = false;
      if (kDebugMode)
        print("[DataSyncService] ActivitySegment sync flag reset to false.");
    }
  }
  // --------------------------------------------------------------

  void dispose() {
    if (kDebugMode) print("[DataSyncService] Disposing...");
    _connectivitySubscription?.cancel();
    if (kDebugMode) print("[DataSyncService] Disposed.");
  }
}
