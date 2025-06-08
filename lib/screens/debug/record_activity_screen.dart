// lib/screens/debug/record_activity_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:open_filex/open_filex.dart'; // Optional: to open file/directory

import '../../services/ble_service.dart';
import '../../models/health_data.dart';
import '../../generated/app_localizations.dart';
import '../../services/activity_recognition_service.dart'
    show HAR_ACTIVITY_LABELS; // Import HAR_ACTIVITY_LABELS

class RecordActivityScreen extends StatefulWidget {
  const RecordActivityScreen({super.key});

  @override
  State<RecordActivityScreen> createState() => _RecordActivityScreenState();
}

class _RecordActivityScreenState extends State<RecordActivityScreen> {
  bool _isRecording = false;
  int? _selectedActivityId;
  String? _selectedActivityDisplayName;

  String _currentFilePath = '';
  IOSink? _fileSink;
  StreamSubscription<HealthData>? _healthDataSubscription;
  int _samplesRecorded = 0;
  String _statusMessage = '';

  BleService? _bleService;

  late List<DropdownMenuItem<int>> _activityDropdownItems;
  late Map<int, String> _idToDisplayNameMap;

  @override
  void initState() {
    super.initState();
    _idToDisplayNameMap = HAR_ACTIVITY_LABELS;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _statusMessage = l10n.recordScreenInitialStatus;
        });

        _activityDropdownItems = _idToDisplayNameMap.entries.map((entry) {
          return DropdownMenuItem<int>(
            value: entry.key,
            child: Text(_getLocalizedActivityName(entry.value, l10n)),
          );
        }).toList();

        if (_activityDropdownItems.isNotEmpty) {
          _selectedActivityId = _activityDropdownItems.first.value;
          _selectedActivityDisplayName =
              _idToDisplayNameMap[_selectedActivityId!];
        }
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bleService == null) {
      _bleService = Provider.of<BleService>(context, listen: false);
    }
  }

  String _getLocalizedActivityName(String activityKey, AppLocalizations l10n) {
    switch (activityKey) {
      case 'Standing':
        return l10n.activityStanding;
      case 'Lying':
        return l10n.activityLying;
      case 'Sitting':
        return l10n.activitySitting;
      case 'Walking':
        return l10n.activityWalking;
      case 'Running':
        return l10n.activityRunning;
      default:
        return l10n.activityUnknown;
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted && mounted) {
        // Thêm kiểm tra mounted
        _updateStatusMessage(
            AppLocalizations.of(context)!.permissionDeniedStorage);
        return false;
      }
    }
    return true;
  }

  Future<String?> _getFilePath() async {
    if (_selectedActivityId == null || _selectedActivityDisplayName == null) {
      if (mounted) {
        // Thêm kiểm tra mounted
        _updateStatusMessage(
            AppLocalizations.of(context)!.recordScreenSelectActivityFirst);
      }
      return null;
    }

    if (!await _requestPermissions()) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final activityNameSafe =
          _selectedActivityDisplayName!.replaceAll(' ', '_').toLowerCase();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'sensor_data_${activityNameSafe}_${_selectedActivityId}_$timestamp.csv';
      return '${directory.path}/$fileName';
    } catch (e) {
      if (mounted) {
        // Thêm kiểm tra mounted
        _updateStatusMessage(
            AppLocalizations.of(context)!.errorGettingPath(e.toString()));
      }
      print('Error getting file path: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    if (!mounted) return; // Kiểm tra mounted ở đầu hàm
    final l10n = AppLocalizations.of(context)!;

    if (_selectedActivityId == null || _selectedActivityDisplayName == null) {
      _updateStatusMessage(l10n.recordScreenSelectActivityFirst);
      return;
    }
    if (_isRecording) {
      _updateStatusMessage(l10n.recordScreenAlreadyRecording);
      return;
    }
    if (_bleService == null ||
        _bleService!.connectionStatus.value != BleConnectionStatus.connected) {
      _updateStatusMessage(l10n.wifiConfigDeviceNotConnectedError);
      return;
    }

    final filePath = await _getFilePath();
    if (filePath == null) return;

    setState(() => _isRecording = true);
    _updateStatusMessage(l10n.recordScreenRecordingTo(filePath));

    try {
      _currentFilePath = filePath;
      final file = File(_currentFilePath);
      _fileSink = file.openWrite(mode: FileMode.append);

      const List<String> header = [
        'timestamp_ms_device',
        'timestamp_ms_phone',
        'activity_id',
        'activity_name',
        'ax',
        'ay',
        'az',
        'gx',
        'gy',
        'gz',
      ];
      _fileSink!.writeln(const ListToCsvConverter().convert([header]));
      print('CSV Header written to $_currentFilePath');

      _samplesRecorded = 0;
      _healthDataSubscription =
          _bleService!.healthDataStream.listen((HealthData data) async {
        if (!_isRecording || _fileSink == null || !mounted)
          return; // Kiểm tra mounted ở đây nữa

        final List<dynamic> row = [
          data.timestamp.millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
          _selectedActivityId!,
          _selectedActivityDisplayName!,
          data.ax,
          data.ay,
          data.az,
          data.gx,
          data.gy,
          data.gz,
        ];
        _fileSink!.writeln(const ListToCsvConverter().convert([row]));

        setStateIfMounted(() {
          _samplesRecorded++;
        });

        if (_samplesRecorded % 100 == 0) {
          await _fileSink!.flush();
          final l10nForFlush =
              AppLocalizations.of(context)!; // Lấy lại l10n nếu cần
          if (_selectedActivityDisplayName != null) {
            _updateStatusMessage(l10nForFlush.recordScreenSamplesRecorded(
                _selectedActivityDisplayName!, _samplesRecorded.toString()));
          } else {
            _updateStatusMessage(l10nForFlush.recordScreenSamplesRecorded(
                l10nForFlush.activityUnknown, _samplesRecorded.toString()));
          }
          print('Flushed data at $_samplesRecorded samples');
        }
      }, onError: (error) {
        if (!mounted) return; // Kiểm tra mounted
        print('Error on health data stream: $error');
        final l10nOnError = AppLocalizations.of(context)!;
        _updateStatusMessage(
            l10nOnError.recordScreenStreamError(error.toString()));
        _stopRecording();
      }, onDone: () {
        if (!mounted) return; // Kiểm tra mounted
        print('Health data stream closed.');
        if (_isRecording) {
          final l10nOnDone = AppLocalizations.of(context)!;
          _updateStatusMessage(l10nOnDone.recordScreenStreamEnded);
          _stopRecording();
        }
      });
    } catch (e) {
      if (!mounted) return; // Kiểm tra mounted
      print('Error starting recording: $e');
      final l10nOnCatch = AppLocalizations.of(context)!;
      _updateStatusMessage(l10nOnCatch.recordScreenStartError(e.toString()));
      setState(() => _isRecording = false);
      await _fileSink?.close();
      _fileSink = null;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || !mounted) return; // Kiểm tra isRecording và mounted

    await _healthDataSubscription?.cancel();
    _healthDataSubscription = null;

    if (_fileSink != null) {
      // Kiểm tra _fileSink không null trước khi thao tác
      await _fileSink!.flush();
      await _fileSink!.close();
      _fileSink = null;
    }

    final l10n = AppLocalizations.of(context)!;
    final message = l10n.recordScreenStopMessage(
        _samplesRecorded.toString(), _currentFilePath);
    print(message);
    setStateIfMounted(() {
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

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _healthDataSubscription?.cancel();
    if (_fileSink != null) {
      _fileSink!
          .flush()
          .then((_) => _fileSink!.close().catchError((e) {
                // Thêm catchError
                print("Error closing fileSink in dispose: $e");
              }))
          .catchError((e) {
        print("Error flushing fileSink in dispose: $e");
      });
      _fileSink = null;
    }
    super.dispose();
  }

  // Build method giữ nguyên
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_activityDropdownItems == null || _activityDropdownItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recordActivityTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_statusMessage.isEmpty && mounted) {
      _statusMessage = l10n.recordScreenInitialStatus;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordActivityTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: l10n.selectActivityLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.directions_run),
              ),
              value: _selectedActivityId,
              items: _activityDropdownItems,
              onChanged: _isRecording
                  ? null
                  : (int? newId) {
                      setState(() {
                        _selectedActivityId = newId;
                        _selectedActivityDisplayName =
                            newId != null ? _idToDisplayNameMap[newId] : null;
                      });
                    },
              validator: (value) {
                if (value == null) {
                  return l10n.recordScreenSelectActivityValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(_isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_filled_outlined),
              label: Text(_isRecording
                  ? l10n.stopRecordingButton
                  : l10n.startRecordingButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording
                    ? Colors.redAccent
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            Text(
              l10n.statusLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(_statusMessage,
                      style: const TextStyle(fontSize: 14)),
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${l10n.samplesRecordedLabel}: $_samplesRecorded',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_currentFilePath.isNotEmpty && !_isRecording)
              TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(l10n.copyFilePathButton),
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: _currentFilePath));
                  if (mounted) {
                    // Kiểm tra mounted trước khi dùng context
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              l10n.filePathCopiedSuccess(_currentFilePath))),
                    );
                  }
                  print("File path copied: $_currentFilePath");
                },
              )
          ],
        ),
      ),
    );
  }
}
