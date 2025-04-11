// // lib/screens/core/dashboard_screen.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Để định dạng ngày giờ
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart'; // Vẫn cần để chào hỏi user
// import '../../providers/ble_provider.dart'; // Lấy dữ liệu và trạng thái BLE
// import '../../services/ble_service.dart'; // Cần cho enum BleConnectionStatus và class HealthData

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});

//   // Hàm helper để lấy text và màu cho trạng thái BLE
//   Widget _buildBleStatusChip(BleConnectionStatus status) {
//     String text;
//     Color color;
//     IconData icon;

//     switch (status) {
//       case BleConnectionStatus.connected:
//         text = 'Connected';
//         color = Colors.green;
//         icon = Icons.bluetooth_connected;
//         break;
//       case BleConnectionStatus.connecting:
//       case BleConnectionStatus.discovering_services:
//         text = 'Connecting...';
//         color = Colors.orange;
//         icon = Icons.bluetooth_searching;
//         break;
//       case BleConnectionStatus.disconnected:
//         text = 'Disconnected';
//         color = Colors.grey;
//         icon = Icons.bluetooth_disabled;
//         break;
//       case BleConnectionStatus.scanning:
//         text = 'Scanning...';
//         color = Colors.blue;
//         icon = Icons.bluetooth_searching;
//         break;
//       case BleConnectionStatus.error:
//         text = 'Error';
//         color = Colors.red;
//         icon = Icons.error_outline;
//         break;
//       default:
//         text = 'Unknown';
//         color = Colors.grey;
//         icon = Icons.bluetooth;
//     }
//     return Chip(
//       avatar: Icon(icon, color: Colors.white, size: 18),
//       label: Text(text, style: const TextStyle(color: Colors.white)),
//       backgroundColor: color,
//       padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Lấy thông tin user từ AuthProvider
//     final user = context.watch<AuthProvider>().user;

//     // Sử dụng Consumer để lắng nghe BleProvider
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard'),
//         automaticallyImplyLeading: false,
//         actions: [
//           // Hiển thị trạng thái BLE trên AppBar
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: Center(
//               // Dùng ValueListenableBuilder để chỉ rebuild chip này khi status thay đổi
//               child: ValueListenableBuilder<BleConnectionStatus>(
//                 valueListenable:
//                     context
//                         .read<BleProvider>()
//                         .connectionStatus, // Dùng read vì chỉ cần listenable
//                 builder: (context, status, child) {
//                   return _buildBleStatusChip(status);
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Padding(
//         // Thêm Padding cho dễ nhìn
//         padding: const EdgeInsets.all(16.0),
//         child: Consumer<BleProvider>(
//           // Dùng Consumer để rebuild khi data thay đổi
//           builder: (context, bleProvider, child) {
//             final latestData =
//                 bleProvider.latestHealthData; // Dữ liệu mới nhất (có thể null)
//             final connectionStatus =
//                 bleProvider.connectionStatus.value; // Trạng thái hiện tại

//             // Định dạng ngày giờ
//             final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
//             final String timestampStr =
//                 latestData != null
//                     ? formatter.format(
//                       latestData.timestamp.toLocal(),
//                     ) // Chuyển sang giờ địa phương
//                     : 'N/A';

//             return ListView(
//               // Sử dụng ListView để dễ dàng thêm các Card/Widget sau
//               children: [
//                 // --- Lời chào ---
//                 if (user != null)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 20.0),
//                     child: Text(
//                       'Welcome, ${user.displayName ?? user.email ?? 'User'}!',
//                       style: Theme.of(context).textTheme.headlineSmall,
//                       textAlign: TextAlign.center,
//                     ),
//                   ),

//                 // --- Card Dữ liệu Realtime ---
//                 Card(
//                   elevation: 4.0,
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Realtime Data',
//                           style: Theme.of(context).textTheme.titleLarge,
//                         ),
//                         const SizedBox(height: 10),
//                         if (connectionStatus ==
//                             BleConnectionStatus.connected) ...[
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceAround,
//                             children: [
//                               _buildDataPoint(
//                                 icon: Icons.favorite,
//                                 label: 'Heart Rate',
//                                 // Hiển thị --- nếu hr là -1 hoặc data là null
//                                 value:
//                                     (latestData?.hr ?? -1) >= 0
//                                         ? '${latestData!.hr}'
//                                         : '---',
//                                 unit: 'bpm',
//                                 context: context,
//                               ),
//                               _buildDataPoint(
//                                 icon: Icons.opacity, // Hoặc Icons.air
//                                 label: 'SpO2',
//                                 // Hiển thị --- nếu spo2 là -1 hoặc data là null
//                                 value:
//                                     (latestData?.spo2 ?? -1) >= 0
//                                         ? '${latestData!.spo2}'
//                                         : '---',
//                                 unit: '%',
//                                 context: context,
//                               ),
//                               _buildDataPoint(
//                                 icon: Icons.directions_walk,
//                                 label: 'Steps',
//                                 value: latestData?.steps?.toString() ?? '---',
//                                 unit: '', // Không có đơn vị
//                                 context: context,
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 15),
//                           Center(
//                             // Căn giữa timestamp
//                             child: Text(
//                               'Last updated: $timestampStr',
//                               style: Theme.of(context).textTheme.bodySmall,
//                             ),
//                           ),
//                         ] else if (connectionStatus ==
//                                 BleConnectionStatus.connecting ||
//                             connectionStatus ==
//                                 BleConnectionStatus.discovering_services) ...[
//                           const Center(
//                             child: Padding(
//                               padding: EdgeInsets.symmetric(vertical: 20.0),
//                               child: Column(
//                                 children: [
//                                   CircularProgressIndicator(),
//                                   SizedBox(height: 10),
//                                   Text("Connecting to device..."),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ] else ...[
//                           // Hiển thị thông báo khi không kết nối
//                           Center(
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 20.0,
//                               ),
//                               child: Text(
//                                 connectionStatus == BleConnectionStatus.error
//                                     ? 'Connection error. Please check device or scan again.'
//                                     : 'Device disconnected. Please connect via device selection screen.',
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   color: Theme.of(context).colorScheme.error,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 20),

//                 // --- Placeholder cho Biểu đồ ---
//                 const Card(
//                   elevation: 4.0,
//                   child: SizedBox(
//                     height: 200, // Chiều cao cố định cho biểu đồ
//                     child: Center(child: Text('History Charts Area')),
//                   ),
//                 ),

//                 const SizedBox(height: 20),

//                 // --- Placeholder cho Mục tiêu ---
//                 Card(
//                   elevation: 2.0,
//                   child: ListTile(
//                     leading: const Icon(Icons.flag_outlined),
//                     title: const Text('Daily Goal Progress'),
//                     subtitle: const Text('Steps: --- / ---'), // Sẽ cập nhật sau
//                     trailing: const Icon(Icons.chevron_right),
//                     onTap: () {
//                       // TODO: Điều hướng đến màn hình Goals
//                       // Nên thực hiện qua BottomNavBar thay vì ở đây
//                     },
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   // Widget helper để hiển thị một điểm dữ liệu
//   Widget _buildDataPoint({
//     required IconData icon,
//     required String label,
//     required String value,
//     required String unit,
//     required BuildContext context,
//   }) {
//     return Column(
//       children: [
//         Icon(icon, size: 30.0, color: Theme.of(context).primaryColor),
//         const SizedBox(height: 5.0),
//         Text(
//           value,
//           style: Theme.of(
//             context,
//           ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//         ),
//         if (unit.isNotEmpty)
//           Text(unit, style: Theme.of(context).textTheme.bodySmall),
//         const SizedBox(height: 2.0),
//         Text(label, style: Theme.of(context).textTheme.bodyMedium),
//       ],
//     );
//   }
// }

// // lib/screens/core/dashboard_screen.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Để định dạng ngày giờ
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/ble_provider.dart';
// import '../../services/ble_service.dart';

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});

//   // Hàm helper để lấy text và màu cho trạng thái BLE (giữ nguyên)
//   Widget _buildBleStatusChip(BleConnectionStatus status) {
//     // ... (code hàm này giữ nguyên như trước) ...
//     String text;
//     Color color;
//     IconData icon;

//     switch (status) {
//       case BleConnectionStatus.connected:
//         text = 'Connected';
//         color = Colors.green;
//         icon = Icons.bluetooth_connected;
//         break;
//       case BleConnectionStatus.connecting:
//       case BleConnectionStatus.discovering_services:
//         text = 'Connecting...';
//         color = Colors.orange;
//         icon = Icons.bluetooth_searching;
//         break;
//       case BleConnectionStatus.disconnected:
//         text = 'Disconnected';
//         color = Colors.grey;
//         icon = Icons.bluetooth_disabled;
//         break;
//       case BleConnectionStatus.scanning:
//         text = 'Scanning...';
//         color = Colors.blue;
//         icon = Icons.bluetooth_searching;
//         break;
//       case BleConnectionStatus.error:
//         text = 'Error';
//         color = Colors.red;
//         icon = Icons.error_outline;
//         break;
//       default:
//         text = 'Unknown';
//         color = Colors.grey;
//         icon = Icons.bluetooth;
//     }
//     return Chip(
//       avatar: Icon(icon, color: Colors.white, size: 18),
//       label: Text(text, style: const TextStyle(color: Colors.white)),
//       backgroundColor: color,
//       padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = context.watch<AuthProvider>().user;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard (Full Data)'), // Đổi title
//         automaticallyImplyLeading: false,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: Center(
//               child: ValueListenableBuilder<BleConnectionStatus>(
//                 valueListenable: context.read<BleProvider>().connectionStatus,
//                 builder: (context, status, child) {
//                   return _buildBleStatusChip(status);
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Consumer<BleProvider>(
//           builder: (context, bleProvider, child) {
//             final latestData = bleProvider.latestHealthData;
//             final connectionStatus = bleProvider.connectionStatus.value;
//             final DateFormat formatter = DateFormat(
//               'dd/MM/yyyy HH:mm:ss.SSS',
//             ); // Thêm milli giây
//             final String timestampStr =
//                 latestData != null
//                     ? formatter.format(latestData.timestamp.toLocal())
//                     : 'N/A';

//             return ListView(
//               // Dùng ListView để chứa nhiều dòng Text
//               children: [
//                 if (user != null)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 20.0),
//                     child: Text(
//                       'Welcome, ${user.displayName ?? user.email ?? 'User'}!',
//                       style: Theme.of(context).textTheme.headlineSmall,
//                       textAlign: TextAlign.center,
//                     ),
//                   ),

//                 // --- Hiển thị trạng thái kết nối chi tiết hơn ---
//                 Text(
//                   'BLE Status: ${connectionStatus.toString().split('.').last}',
//                   textAlign: TextAlign.center,
//                 ),
//                 Text(
//                   'Last updated: $timestampStr',
//                   textAlign: TextAlign.center,
//                   style: Theme.of(context).textTheme.bodySmall,
//                 ),
//                 const Divider(height: 20),

//                 // --- Hiển thị tất cả dữ liệu nếu đã kết nối và có data ---
//                 if (connectionStatus == BleConnectionStatus.connected &&
//                     latestData != null) ...[
//                   _buildDataRow(
//                     'Timestamp:',
//                     timestampStr,
//                   ), // Hiển thị lại timestamp đã format
//                   _buildDataRow(
//                     'Heart Rate (hr):',
//                     (latestData.hr >= 0 ? '${latestData.hr} bpm' : '---'),
//                   ),
//                   _buildDataRow(
//                     'SpO2:',
//                     (latestData.spo2 >= 0 ? '${latestData.spo2} %' : '---'),
//                   ),
//                   _buildDataRow('Steps:', latestData.steps.toString()),
//                   _buildDataRow(
//                     'Accel X (ax):',
//                     latestData.ax.toStringAsFixed(3),
//                   ), // Định dạng 3 chữ số thập phân
//                   _buildDataRow(
//                     'Accel Y (ay):',
//                     latestData.ay.toStringAsFixed(3),
//                   ),
//                   _buildDataRow(
//                     'Accel Z (az):',
//                     latestData.az.toStringAsFixed(3),
//                   ),
//                   _buildDataRow(
//                     'Gyro X (gx):',
//                     latestData.gx.toStringAsFixed(3),
//                   ),
//                   _buildDataRow(
//                     'Gyro Y (gy):',
//                     latestData.gy.toStringAsFixed(3),
//                   ),
//                   _buildDataRow(
//                     'Gyro Z (gz):',
//                     latestData.gz.toStringAsFixed(3),
//                   ),
//                   _buildDataRow('IR Value (ir):', latestData.ir.toString()),
//                   _buildDataRow('Red Value (red):', latestData.red.toString()),
//                   _buildDataRow('WiFi Connected:', latestData.wifi.toString()),
//                 ] else if (connectionStatus == BleConnectionStatus.connecting ||
//                     connectionStatus ==
//                         BleConnectionStatus.discovering_services) ...[
//                   const Center(
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(vertical: 40.0),
//                       child: Column(
//                         children: [
//                           CircularProgressIndicator(),
//                           SizedBox(height: 15),
//                           Text("Connecting / Discovering..."),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ] else ...[
//                   // Thông báo khi không kết nối hoặc không có dữ liệu
//                   Center(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 40.0),
//                       child: Text(
//                         connectionStatus == BleConnectionStatus.error
//                             ? 'Connection error. Check device/permissions.'
//                             : 'Device disconnected. Go back to connect.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Theme.of(context).colorScheme.error,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   // Widget helper để hiển thị một hàng dữ liệu (Label: Value)
//   Widget _buildDataRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Căn đều 2 bên
//         children: [
//           Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
//           Text(value),
//         ],
//       ),
//     );
//   }
// }

// lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Để định dạng ngày giờ
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Hàm helper để lấy text và màu cho trạng thái BLE (giữ nguyên)
  Widget _buildBleStatusChip(BleConnectionStatus status) {
    // ... (code hàm này giữ nguyên như trước) ...
    String text;
    Color color;
    IconData icon;

    switch (status) {
      case BleConnectionStatus.connected:
        text = 'Connected';
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.discovering_services:
        text = 'Connecting...';
        color = Colors.orange;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        text = 'Disconnected';
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionStatus.scanning:
        text = 'Scanning...';
        color = Colors.blue;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        text = 'Error';
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        text = 'Unknown';
        color = Colors.grey;
        icon = Icons.bluetooth;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final DateFormat formatter = DateFormat(
      'HH:mm:ss - dd/MM',
    ); // Định dạng giờ gọn hơn

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'), // Quay lại title gọn
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ValueListenableBuilder<BleConnectionStatus>(
                valueListenable: context.read<BleProvider>().connectionStatus,
                builder: (context, status, child) {
                  return _buildBleStatusChip(status);
                },
              ),
            ),
          ),
        ],
      ),
      body: Consumer<BleProvider>(
        // Dùng Consumer để rebuild khi BLE thay đổi
        builder: (context, bleProvider, child) {
          final latestData = bleProvider.latestHealthData;
          final connectionStatus = bleProvider.connectionStatus.value;
          final String timestampStr =
              latestData != null
                  ? formatter.format(latestData.timestamp.toLocal())
                  : '--:--:--';

          // --- Nội dung chính dựa trên trạng thái kết nối ---
          Widget bodyContent;
          if (connectionStatus == BleConnectionStatus.connected) {
            if (latestData != null) {
              // --- Giao diện khi Đã Kết Nối và có Dữ Liệu ---
              bodyContent = ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Card Chỉ Số Chính ---
                  _buildMainMetricsCard(context, latestData, timestampStr),
                  const SizedBox(height: 16),
                  // --- Card Cảm Biến Chuyển Động (IMU) ---
                  _buildImuCard(context, latestData),
                  const SizedBox(height: 16),
                  // --- Card Cảm Biến Khác & Trạng thái ---
                  _buildOtherSensorsCard(context, latestData),
                  const SizedBox(height: 16),
                  // --- Placeholder Biểu Đồ ---
                  _buildPlaceholderCard(
                    context,
                    title: 'History Charts',
                    height: 200,
                  ),
                  const SizedBox(height: 16),
                  // --- Placeholder Mục Tiêu ---
                  _buildPlaceholderCard(
                    context,
                    title: 'Daily Goals',
                    height: 80,
                  ),
                ],
              );
            } else {
              // --- Đã Kết Nối nhưng Chưa có Dữ Liệu ---
              bodyContent = const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text("Connected. Waiting for data..."),
                  ],
                ),
              );
            }
          } else if (connectionStatus == BleConnectionStatus.connecting ||
              connectionStatus == BleConnectionStatus.discovering_services) {
            // --- Giao diện khi Đang Kết Nối ---
            bodyContent = const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Connecting / Setting up device..."),
                ],
              ),
            );
          } else {
            // --- Giao diện khi Ngắt Kết Nối hoặc Lỗi ---
            bodyContent = Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Text(
                  connectionStatus == BleConnectionStatus.error
                      ? 'Connection error.\nPlease check device/permissions or scan again.'
                      : 'Device disconnected.\nPlease go back to select and connect a device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          // Trả về Scaffold với nội dung đã chọn
          // (Chúng ta đã có Scaffold ở ngoài, chỉ cần trả về bodyContent)
          // Đã sửa: Không cần Scaffold lồng nhau
          return bodyContent;
        },
      ),
    );
  }

  // --- Helper Widgets cho các Card ---

  Widget _buildMainMetricsCard(
    BuildContext context,
    HealthData data,
    String timestampStr,
  ) {
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Metrics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Căn đỉnh cho các cột
              children: [
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.favorite,
                  label: 'Heart Rate',
                  value: (data.hr >= 0) ? data.hr.toString() : '---',
                  unit: 'bpm',
                  color: Colors.red.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.opacity,
                  label: 'SpO2',
                  value: (data.spo2 >= 0) ? data.spo2.toString() : '---',
                  unit: '%',
                  color: Colors.blue.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.directions_walk,
                  label: 'Steps',
                  value: data.steps.toString(),
                  unit: '',
                  color: Colors.orange.shade400,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                'Last updated: $timestampStr',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImuCard(BuildContext context, HealthData data) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Motion Sensors (IMU)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3, // 3 cột
              shrinkWrap: true, // Co lại để vừa trong ListView
              physics:
                  const NeverScrollableScrollPhysics(), // Không cho GridView cuộn riêng
              childAspectRatio: 2.5, // Tỉ lệ chiều rộng/cao của mỗi ô
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
              children: [
                _buildSensorValueTile('ax', data.ax.toStringAsFixed(2)),
                _buildSensorValueTile('ay', data.ay.toStringAsFixed(2)),
                _buildSensorValueTile('az', data.az.toStringAsFixed(2)),
                _buildSensorValueTile('gx', data.gx.toStringAsFixed(2)),
                _buildSensorValueTile('gy', data.gy.toStringAsFixed(2)),
                _buildSensorValueTile('gz', data.gz.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherSensorsCard(BuildContext context, HealthData data) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other Sensors & Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSensorValueTile('IR', data.ir.toString()),
                _buildSensorValueTile('Red', data.red.toString()),
                Column(
                  children: [
                    Text('WiFi', style: Theme.of(context).textTheme.bodySmall),
                    Icon(
                      data.wifi ? Icons.wifi : Icons.wifi_off,
                      color: data.wifi ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(
    BuildContext context, {
    required String title,
    double height = 100,
  }) {
    return Card(
      elevation: 2.0,
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }

  // --- Widget con để hiển thị từng chỉ số chính ---
  Widget _buildMetricDisplay({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    Color? color, // Màu sắc tùy chọn cho icon/text
  }) {
    final primaryColor = color ?? Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min, // Để cột co lại theo nội dung
      children: [
        Icon(icon, size: 36.0, color: primaryColor),
        const SizedBox(height: 8.0),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor, // Sử dụng màu nhấn mạnh
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: primaryColor),
          ),
        const SizedBox(height: 4.0),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  // --- Widget con cho các ô giá trị cảm biến trong GridView ---
  Widget _buildSensorValueTile(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
