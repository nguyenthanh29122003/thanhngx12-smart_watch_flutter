// lib/screens/debug/record_activity_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/ble_service.dart';
import '../../models/health_data.dart';
import '../../generated/app_localizations.dart'; // Cho localization (nếu có)

// Định nghĩa các hoạt động bạn muốn thu thập
// Nên có một map từ tên hiển thị sang một ID dạng số hoặc chuỗi ngắn gọn để lưu trong file
enum ActivityToRecord {
  lying,
  sitting,
  standing,
  walking,
  running,
  cycling,
  ascendingStairs,
  descendingStairs,
  // Thêm các hoạt động khác nếu cần
}

// Map để lấy tên hiển thị (và ID nếu cần)
// Bạn có thể mở rộng map này để chứa ID số nếu muốn lưu ID thay vì tên đầy đủ
// Ví dụ: ActivityToRecord.walking: {'displayName': 'Walking', 'id': 4}
const Map<ActivityToRecord, String> activityDisplayNames = {
  ActivityToRecord.lying: 'Lying',
  ActivityToRecord.sitting: 'Sitting',
  ActivityToRecord.standing: 'Standing',
  ActivityToRecord.walking: 'Walking',
  ActivityToRecord.running: 'Running',
  ActivityToRecord.cycling: 'Cycling',
  ActivityToRecord.ascendingStairs: 'Ascending Stairs',
  ActivityToRecord.descendingStairs: 'Descending Stairs',
};

// Map ID hoạt động (quan trọng để khớp với quá trình huấn luyện sau này)
// Nên giữ các ID này nhất quán với những gì bạn đã dùng hoặc sẽ dùng cho model
// Ví dụ, nếu bạn đã dùng ID từ PAMAP2, có thể map lại
const Map<ActivityToRecord, int> activityIds = {
  ActivityToRecord.lying: 1,
  ActivityToRecord.sitting: 2,
  ActivityToRecord.standing: 3,
  ActivityToRecord.walking: 4,
  ActivityToRecord.running: 5,
  ActivityToRecord.cycling: 6,
  ActivityToRecord.ascendingStairs: 12,
  ActivityToRecord.descendingStairs: 13,
};

class RecordActivityScreen extends StatefulWidget {
  const RecordActivityScreen({super.key});

  @override
  State<RecordActivityScreen> createState() => _RecordActivityScreenState();
}

class _RecordActivityScreenState extends State<RecordActivityScreen> {
  bool _isRecording = false;
  ActivityToRecord? _selectedActivity =
      ActivityToRecord.walking; // Hoạt động mặc định
  String _currentFilePath = '';
  IOSink? _fileSink;
  StreamSubscription<HealthData>? _healthDataSubscription;
  int _samplesRecorded = 0;
  String _statusMessage = 'Select an activity and start recording.';

  late BleService _bleService; // Sẽ được khởi tạo trong initState

  @override
  void initState() {
    super.initState();
    // Không dùng Provider.of trong initState nếu context chưa sẵn sàng hoàn toàn
    // Thay vào đó, lấy nó trong didChangeDependencies hoặc khi cần dùng (ví dụ: trong _startRecording)
    // Hoặc dùng addPostFrameCallback nếu muốn lấy sớm
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bleService = Provider.of<BleService>(context, listen: false);
      }
    });
  }

  Future<void> _requestPermissions() async {
    // Đối với Android 10 (API 29) trở lên, không cần quyền WRITE_EXTERNAL_STORAGE
    // để ghi vào thư mục riêng của ứng dụng (qua path_provider).
    // Tuy nhiên, nếu bạn muốn ghi vào thư mục public, bạn sẽ cần MANAGE_EXTERNAL_STORAGE (phức tạp hơn)
    // hoặc MediaStore.
    // Đối với các phiên bản Android cũ hơn, WRITE_EXTERNAL_STORAGE có thể cần.
    // Luôn kiểm tra docs của path_provider và permission_handler cho phiên bản Flutter/Android của bạn.

    // Hiện tại, getApplicationDocumentsDirectory không yêu cầu quyền đặc biệt.
    // Nếu bạn đổi sang getExternalStorageDirectory, bạn sẽ cần xử lý quyền.
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        _updateStatusMessage('Storage permission denied. Cannot record data.');
        throw Exception('Storage permission denied');
      }
    }
    // Đối với iOS, quyền ghi vào thư mục documents thường được cấp sẵn.
  }

  Future<String?> _getFilePath(ActivityToRecord activity) async {
    try {
      await _requestPermissions(); // Đảm bảo có quyền trước khi lấy đường dẫn

      final directory = await getApplicationDocumentsDirectory();
      // Hoặc getExternalStorageDirectory() nếu bạn muốn lưu ở bộ nhớ ngoài và đã xử lý quyền
      // final directory = await getExternalStorageDirectory();
      // if (directory == null) {
      //   _updateStatusMessage('Could not get external storage directory.');
      //   return null;
      // }

      final activityName =
          activityDisplayNames[activity]!.replaceAll(' ', '_').toLowerCase();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'har_data_${activityName}_$timestamp.csv';
      return '${directory.path}/$fileName';
    } catch (e) {
      _updateStatusMessage('Error getting file path: $e');
      print('Error getting file path: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    if (_selectedActivity == null) {
      _updateStatusMessage('Please select an activity first.');
      return;
    }
    if (_isRecording) {
      _updateStatusMessage('Already recording.');
      return;
    }

    try {
      _bleService = Provider.of<BleService>(context, listen: false);

      final filePath = await _getFilePath(_selectedActivity!);
      if (filePath == null) return;

      _currentFilePath = filePath;
      final file = File(_currentFilePath);
      _fileSink = file.openWrite(mode: FileMode.append);

      // Ghi header cho file CSV
      const List<String> header = [
        'timestamp_ms',
        'activity_id',
        'activity_name',
        'ax',
        'ay',
        'az',
        'gx',
        'gy',
        'gz'
      ];
      _fileSink!.writeln(const ListToCsvConverter().convert([header]));
      print('CSV Header written to $_currentFilePath');

      _samplesRecorded = 0;
      _healthDataSubscription =
          _bleService.healthDataStream.listen((HealthData data) async {
        if (!_isRecording || _fileSink == null) return;

        final List<dynamic> row = [
          DateTime.now().millisecondsSinceEpoch,
          activityIds[_selectedActivity!]!,
          activityDisplayNames[_selectedActivity!]!,
          data.ax,
          data.ay,
          data.az,
          data.gx,
          data.gy,
          data.gz,
        ];
        _fileSink!.writeln(const ListToCsvConverter().convert([row]));
        setState(() {
          _samplesRecorded++;
        });

        // Tự động lưu (flush) sau mỗi 100 mẫu
        if (_samplesRecorded % 100 == 0) {
          await _fileSink!.flush();
          _updateStatusMessage(
              'Recording ${activityDisplayNames[_selectedActivity!]}: $_samplesRecorded samples (saved).');
          print('Flushed data at $_samplesRecorded samples');
        }
      }, onError: (error) {
        print('Error on health data stream: $error');
        _updateStatusMessage(
            'Error on data stream: $error. Recording stopped.');
        _stopRecording();
      }, onDone: () {
        print('Health data stream closed.');
        if (_isRecording) {
          _updateStatusMessage('Data stream ended. Recording stopped.');
          _stopRecording();
        }
      });

      setState(() {
        _isRecording = true;
        _statusMessage =
            'Recording ${activityDisplayNames[_selectedActivity!]} to:\n$_currentFilePath';
      });
      print('Started recording to $_currentFilePath');
    } catch (e) {
      print('Error starting recording: $e');
      _updateStatusMessage('Error starting recording: $e');
      _isRecording = false;
      await _fileSink?.close();
      _fileSink = null;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    await _healthDataSubscription?.cancel();
    _healthDataSubscription = null;

    await _fileSink?.flush(); // Flush lần cuối trước khi đóng
    await _fileSink?.close();
    _fileSink = null;

    final message =
        'Recording stopped. $_samplesRecorded samples recorded to:\n$_currentFilePath';
    print(message);
    setState(() {
      _isRecording = false;
      _statusMessage = message;
    });
  }

  void _updateStatusMessage(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
    print("[RecordScreen Status] $message");
  }

  @override
  void dispose() {
    _healthDataSubscription?.cancel();
    _fileSink?.close(); // Đảm bảo file được đóng
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Giả sử bạn có l10n

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.recordActivityTitle ??
            'Record Activity'), // Thêm key dịch
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Dropdown để chọn hoạt động
            DropdownButtonFormField<ActivityToRecord>(
              decoration: InputDecoration(
                labelText: localizations.selectActivityLabel ??
                    'Select Activity', // Thêm key dịch
                border: const OutlineInputBorder(),
              ),
              value: _selectedActivity,
              items: ActivityToRecord.values.map((ActivityToRecord activity) {
                return DropdownMenuItem<ActivityToRecord>(
                  value: activity,
                  child: Text(activityDisplayNames[activity] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: _isRecording
                  ? null
                  : (ActivityToRecord? newValue) {
                      // Vô hiệu hóa khi đang ghi
                      setState(() {
                        _selectedActivity = newValue;
                      });
                    },
            ),
            const SizedBox(height: 20),

            // Nút Start/Stop Recording
            ElevatedButton.icon(
              icon: Icon(_isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_filled_outlined),
              label: Text(_isRecording
                  ? (localizations.stopRecordingButton ?? 'Stop Recording')
                  : (localizations.startRecordingButton ??
                      'Start Recording')), // Thêm key dịch
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.redAccent : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                if (_isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
              },
            ),
            const SizedBox(height: 20),

            // Hiển thị trạng thái
            Text(
              localizations.statusLabel ?? 'Status:', // Thêm key dịch
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusMessage, style: const TextStyle(fontSize: 14)),
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                          '${localizations.samplesRecordedLabel ?? 'Samples Recorded:'} $_samplesRecorded',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold)), // Thêm key dịch
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_currentFilePath.isNotEmpty && !_isRecording)
              TextButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(localizations.viewRecordedDataHint ??
                    'Recorded data path (tap to copy)'), // Thêm key dịch
                onPressed: () async {
                  // await Clipboard.setData(ClipboardData(text: _currentFilePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${localizations.pathCopiedSnackbar ?? 'Path copied (simulated):'} $_currentFilePath')), // Thêm key dịch
                  );
                  print("File path for user: $_currentFilePath");
                  // Bạn có thể dùng package `open_file` để mở thư mục chứa file này,
                  // hoặc hướng dẫn người dùng cách truy cập qua adb pull / file manager của thiết bị.
                },
              )
          ],
        ),
      ),
    );
  }
}

// Fallback localizations nếu AppLocalizations.of(context) là null (ví dụ: context chưa có)
// Chỉ dùng cho mục đích demo, nên đảm bảo AppLocalizations được cung cấp đúng cách
class AppLocalizationsEn {
  String get recordActivityTitle => 'Record Activity';
  String get selectActivityLabel => 'Select Activity';
  String get startRecordingButton => 'Start Recording';
  String get stopRecordingButton => 'Stop Recording';
  String get statusLabel => 'Status:';
  String get samplesRecordedLabel => 'Samples Recorded:';
  String get viewRecordedDataHint => 'Recorded data path (tap to copy)';
  String get pathCopiedSnackbar => 'Path copied (simulated):';
}
