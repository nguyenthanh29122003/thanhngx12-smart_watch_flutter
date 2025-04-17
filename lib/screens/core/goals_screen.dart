// lib/screens/core/goals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // <<< THÊM IMPORT NÀY
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../app_constants.dart';
import '../../providers/dashboard_provider.dart'; // <<< THÊM IMPORT NÀY
// import '../../providers/ble_provider.dart'; // <<< KHÔNG CẦN NỮA

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

// Thêm 'with WidgetsBindingObserver' để lắng nghe vòng đời app
class _GoalsScreenState extends State<GoalsScreen> with WidgetsBindingObserver {
  // State cho mục tiêu (đọc từ SharedPreferences)
  int _currentStepGoal = AppConstants.defaultDailyStepGoal;
  bool _isLoadingGoal = true; // Trạng thái tải mục tiêu

  // State cho tổng số bước hôm nay (tính từ DashboardProvider)
  int _todaySteps = 0;
  bool _isLoadingTodaySteps = true; // Trạng thái tính toán/chờ dữ liệu

  // Controller cho dialog sửa mục tiêu
  final TextEditingController _goalDialogController = TextEditingController();

  // Listener cho DashboardProvider
  VoidCallback? _dashboardListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Đăng ký theo dõi vòng đời

    _loadStepGoalFromPrefs(); // Tải mục tiêu từ SharedPreferences

    // Lắng nghe DashboardProvider sau khi widget build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);
        _dashboardListener = () {
          if (mounted) {
            _calculateTodaySteps(
                dashboardProvider); // Tính lại bước khi provider thay đổi
          }
        };
        dashboardProvider.addListener(_dashboardListener!); // Đăng ký listener

        // Tính toán lần đầu nếu dữ liệu đã sẵn sàng
        if (dashboardProvider.historyStatus != HistoryStatus.initial &&
            dashboardProvider.historyStatus != HistoryStatus.loading) {
          _calculateTodaySteps(dashboardProvider);
        } else {
          // Nếu chưa sẵn sàng, đặt trạng thái đang chờ
          if (mounted) setState(() => _isLoadingTodaySteps = true);
        }
      }
    });
    print("[GoalsScreen] initState completed.");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Hủy đăng ký theo dõi
    _goalDialogController.dispose(); // Hủy controller

    // Hủy đăng ký listener DashboardProvider
    try {
      // Dùng try-read hoặc lưu lại instance provider nếu context không an toàn
      Provider.of<DashboardProvider>(context, listen: false)
          .removeListener(_dashboardListener!);
      print("[GoalsScreen] Removed dashboard listener.");
    } catch (e) {
      print("Error removing dashboard listener in GoalsScreen dispose: $e");
    }
    super.dispose();
  }

  // Hàm được gọi khi trạng thái vòng đời App thay đổi
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print(
          "[GoalsScreen] App Resumed - Reloading goal and recalculating steps.");
      // Tải lại mục tiêu từ prefs và tính lại số bước khi app quay lại
      _loadStepGoalFromPrefs();
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      _calculateTodaySteps(dashboardProvider);
    }
  }

  // Hàm tải mục tiêu từ SharedPreferences
  Future<void> _loadStepGoalFromPrefs() async {
    if (!mounted) return;
    // Có thể không cần setState isLoadingGoal ở đây nếu chỉ muốn loading lần đầu
    // setState(() => _isLoadingGoal = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getInt(AppConstants.prefKeyDailyStepGoal);
      if (mounted) {
        setState(() {
          _currentStepGoal = savedGoal ?? AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false; // Đánh dấu đã tải xong mục tiêu
        });
        print("[GoalsScreen] Loaded step goal from Prefs: $_currentStepGoal");
      }
    } catch (e) {
      print("!!! [GoalsScreen] Error loading step goal from Prefs: $e");
      if (mounted) {
        setState(() {
          _currentStepGoal = AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false;
        });
      }
    }
  }

  // Hàm lưu mục tiêu vào SharedPreferences
  Future<void> _saveStepGoalToPrefs(int newGoal) async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.prefKeyDailyStepGoal, newGoal);
      if (mounted) {
        setState(() {
          _currentStepGoal = newGoal; // Cập nhật state cục bộ ngay lập tức
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('New step goal saved!'),
              backgroundColor: Colors.green), // TODO: Dịch
        );
        print("[GoalsScreen] Saved step goal to Prefs: $newGoal");
      }
    } catch (e) {
      print("!!! [GoalsScreen] Error saving step goal to Prefs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save new goal.'),
              backgroundColor: Colors.redAccent), // TODO: Dịch
        );
      }
    }
  }

  // Hàm hiển thị dialog để đặt mục tiêu mới
  Future<void> _showSetGoalDialog() async {
    if (!mounted) return;
    final formKey = GlobalKey<FormState>();
    _goalDialogController.text = _currentStepGoal.toString();

    int? newGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Daily Step Goal'), // TODO: Dịch
        contentPadding: const EdgeInsets.all(20.0),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _goalDialogController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: const InputDecoration(
              labelText: 'New Goal (e.g., 10000)', // TODO: Dịch
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please enter a number'; // TODO: Dịch
              final number = int.tryParse(value);
              if (number == null) return 'Invalid number'; // TODO: Dịch
              if (number <= 0) return 'Goal must be > 0'; // TODO: Dịch
              if (number > 99999) return 'Goal seems too high!'; // TODO: Dịch
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'), // TODO: Dịch
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final enteredGoal = int.tryParse(_goalDialogController.text);
                Navigator.of(dialogContext).pop(enteredGoal);
              }
            },
            child: const Text('Save Goal'), // TODO: Dịch
          ),
        ],
      ),
    );

    // Nếu người dùng nhập và lưu mục tiêu mới
    if (newGoal != null && newGoal != _currentStepGoal) {
      await _saveStepGoalToPrefs(newGoal); // Gọi hàm lưu vào SharedPreferences
    }
  }

  // Hàm tính toán tổng số bước hôm nay từ dữ liệu của DashboardProvider
  void _calculateTodaySteps(DashboardProvider dashboardProvider) {
    // Chỉ tính nếu provider không còn đang tải dữ liệu lịch sử
    if (dashboardProvider.historyStatus == HistoryStatus.loading ||
        dashboardProvider.historyStatus == HistoryStatus.initial) {
      print("[GoalsScreen] Waiting for DashboardProvider to load history...");
      if (mounted)
        setState(() => _isLoadingTodaySteps = true); // Đảm bảo vẫn là loading
      return;
    }

    if (mounted && !_isLoadingTodaySteps) {
      // Nếu đã tính rồi thì không cần tính lại trừ khi có lý do (ví dụ qua ngày mới)
      // Logic kiểm tra qua ngày mới có thể thêm ở didChangeAppLifecycleState hoặc dùng Timer
      // return;
    }

    print(
        "[GoalsScreen] Calculating today's steps using DashboardProvider data...");
    setStateIfMounted(() => _isLoadingTodaySteps = true); // Bắt đầu tính

    final List<HourlyStepsData> hourlyStepsList =
        dashboardProvider.hourlyStepsData;
    int calculatedSteps = 0;

    if (hourlyStepsList.isNotEmpty) {
      final nowLocal = DateTime.now();
      final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      for (var hourlyData in hourlyStepsList) {
        final dataHourLocal = hourlyData.hourStart.toLocal();
        if (!dataHourLocal.isBefore(todayStart) &&
            dataHourLocal.isBefore(todayEnd)) {
          calculatedSteps += hourlyData.steps;
        }
      }
    } else {
      print("[GoalsScreen] Hourly steps data from DashboardProvider is empty.");
    }

    // Cập nhật state an toàn
    setStateIfMounted(() {
      _todaySteps = calculatedSteps;
      _isLoadingTodaySteps = false; // Đánh dấu đã tính xong
      print("[GoalsScreen] Calculation complete. Today's steps: $_todaySteps");
    });
  }

  // Hàm helper để gọi setState một cách an toàn
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tính toán tiến độ dựa trên state cục bộ
    final double progressPercent = (_currentStepGoal > 0)
        ? (_todaySteps / _currentStepGoal).clamp(0.0, 1.0)
        : 0.0;
    final bool goalAchieved = progressPercent >= 1.0;
    final int remainingSteps =
        (_currentStepGoal - _todaySteps).clamp(0, _currentStepGoal);

    // Trạng thái loading tổng thể (cho cả mục tiêu và tính toán bước)
    final bool isLoading = _isLoadingGoal || _isLoadingTodaySteps;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Goals')), // TODO: Dịch
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              // <<< Thêm RefreshIndicator để tải lại thủ công >>>
              onRefresh: () async {
                print("[GoalsScreen] Pull to refresh triggered.");
                // Tải lại mục tiêu và yêu cầu DashboardProvider tải lại lịch sử
                // (việc này sẽ trigger listener và tính lại steps)
                await _loadStepGoalFromPrefs();
                await Provider.of<DashboardProvider>(context, listen: false)
                    .fetchHealthHistory();
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Card Mục tiêu Bước chân ---
                  Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        children: [
                          // Tiêu đề và nút sửa
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Daily Step Goal',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge), // TODO: Dịch
                              IconButton(
                                icon: Icon(Icons.edit_note,
                                    color: Theme.of(context).primaryColor),
                                tooltip: 'Set New Goal', // TODO: Dịch
                                onPressed: _showSetGoalDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // --- Vòng tròn Tiến độ ---
                          CircularPercentIndicator(
                            radius: 110.0,
                            lineWidth: 14.0,
                            percent: progressPercent,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  goalAchieved
                                      ? Icons.check_circle
                                      : Icons.directions_walk,
                                  size: 40.0,
                                  color: goalAchieved
                                      ? Colors.green
                                      : Theme.of(context).primaryColor,
                                ),
                                const SizedBox(height: 8),
                                // Hiển thị số bước hôm nay
                                Text(
                                  "$_todaySteps", // <<< Sử dụng _todaySteps
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "/ $_currentStepGoal steps", // Sử dụng mục tiêu
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            linearGradient: LinearGradient(
                              colors: goalAchieved
                                  ? [
                                      Colors.green.shade400,
                                      Colors.green.shade600
                                    ]
                                  : [
                                      Theme.of(context).primaryColorLight,
                                      Theme.of(context).primaryColorDark
                                    ],
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            animation: true,
                            animateFromLastPercent: true,
                            animationDuration: 600,
                          ),
                          const SizedBox(height: 25),
                          // --- Thông báo phụ ---
                          Text(
                            goalAchieved
                                ? 'Goal Achieved! Great job! 🎉' // TODO: Dịch
                                : '$remainingSteps steps remaining', // <<< Sử dụng remainingSteps
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: goalAchieved
                                      ? Colors.green
                                      : Colors.blueGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // --- Placeholder cho các mục tiêu khác ---
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text("Activity Time Goal"), // TODO: Dịch
                      subtitle: const Text(
                          "Progress: ... / ... minutes"), // TODO: Dịch
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {/* ... */},
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
