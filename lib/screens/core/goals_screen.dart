// lib/screens/core/goals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_constants.dart';
import '../../providers/ble_provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter/services.dart'; // <<< Import để giới hạn input

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _currentStepGoal = AppConstants.defaultDailyStepGoal;
  bool _isLoadingGoal = true;
  final TextEditingController _goalDialogController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStepGoal();
  }

  @override
  void dispose() {
    _goalDialogController.dispose();
    super.dispose();
  }

  Future<void> _loadStepGoal() async {
    if (!mounted) return; // Kiểm tra trước
    setState(() {
      _isLoadingGoal = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getInt(AppConstants.prefKeyDailyStepGoal);
      if (mounted) {
        setState(() {
          _currentStepGoal = savedGoal ?? AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false;
        });
      }
    } catch (e) {
      print("Error loading step goal: $e");
      if (mounted)
        setState(() {
          _isLoadingGoal = false;
        });
    }
  }

  Future<void> _saveStepGoal(int newGoal) async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.prefKeyDailyStepGoal, newGoal);
      setState(() {
        _currentStepGoal = newGoal;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          /* SnackBar success */
          const SnackBar(
            content: Text('New step goal saved!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      print("Error saving step goal: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          /* SnackBar error */
          const SnackBar(
            content: Text('Failed to save new goal.'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<void> _showSetGoalDialog() async {
    if (!mounted) return;
    final formKey = GlobalKey<FormState>();
    _goalDialogController.text = _currentStepGoal.toString();

    int? newGoal = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Set Daily Step Goal'),
            contentPadding: const EdgeInsets.all(20.0), // Thêm padding
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: _goalDialogController,
                keyboardType: TextInputType.number,
                // <<< Giới hạn chỉ nhập số và độ dài >>>
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Chỉ cho phép số
                  LengthLimitingTextInputFormatter(
                    7,
                  ), // Giới hạn 7 chữ số (tránh số quá lớn)
                ],
                decoration: InputDecoration(
                  labelText: 'New Goal (e.g., 10000)', // Thêm ví dụ
                  prefixIcon: const Icon(
                    Icons.flag_outlined,
                  ), // Icon phù hợp hơn
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter a number';
                  final number = int.tryParse(value);
                  if (number == null) return 'Invalid number';
                  if (number <= 0) return 'Goal must be > 0';
                  if (number > 50000)
                    return 'Goal seems too high!'; // Giới hạn hợp lý
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                // <<< Dùng ElevatedButton cho nút Save >>>
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final enteredGoal = int.tryParse(
                      _goalDialogController.text,
                    );
                    Navigator.of(context).pop(enteredGoal);
                  }
                },
                child: const Text('Save Goal'),
              ),
            ],
          ),
    );

    if (newGoal != null && newGoal != _currentStepGoal) {
      await _saveStepGoal(newGoal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestData = context.watch<BleProvider>().latestHealthData;
    final latestSteps = latestData?.steps ?? 0;
    final progressPercent =
        (_currentStepGoal > 0)
            ? (latestSteps / _currentStepGoal).clamp(0.0, 1.0)
            : 0.0;
    final bool goalAchieved = progressPercent >= 1.0;
    final int remainingSteps = (_currentStepGoal - latestSteps).clamp(
      0,
      _currentStepGoal,
    ); // Số bước còn lại (không âm)

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Goals')),
      body:
          _isLoadingGoal
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                // <<< Dùng ListView để có thể thêm nội dung sau >>>
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Card Mục tiêu Bước chân ---
                  Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ), // Bo góc Card
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            // Tiêu đề và nút sửa
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Step Goal',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              IconButton(
                                // Nút sửa mục tiêu
                                icon: Icon(
                                  Icons.edit_note,
                                  color: Theme.of(context).primaryColor,
                                ),
                                tooltip: 'Set New Goal',
                                onPressed: _showSetGoalDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // --- Vòng tròn Tiến độ ---
                          CircularPercentIndicator(
                            radius: 110.0, // Tăng kích thước
                            lineWidth: 14.0,
                            percent: progressPercent,
                            center: Column(
                              // Nội dung ở giữa
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  // Icon bước chân
                                  goalAchieved
                                      ? Icons.check_circle
                                      : Icons.directions_walk,
                                  size: 40.0,
                                  color:
                                      goalAchieved
                                          ? Colors.green
                                          : Theme.of(context).primaryColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "$latestSteps",
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "/ $_currentStepGoal steps",
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            // <<< Thêm Gradient cho đẹp mắt >>>
                            linearGradient: LinearGradient(
                              colors:
                                  goalAchieved
                                      ? [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ] // Màu khi hoàn thành
                                      : [
                                        Theme.of(context).primaryColorLight,
                                        Theme.of(context).primaryColorDark,
                                      ], // Màu gradient mặc định
                            ),
                            // progressColor: Theme.of(context).primaryColor, // Không cần khi dùng gradient
                            backgroundColor:
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant, // Màu nền nhạt hơn
                            animation: true,
                            animateFromLastPercent:
                                true, // Animation mượt hơn khi update
                            animationDuration: 600,
                          ),
                          const SizedBox(height: 25),
                          // --- Thông báo phụ ---
                          Text(
                            goalAchieved
                                ? 'Goal Achieved! Great job! 🎉'
                                : '$remainingSteps steps remaining',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color:
                                  goalAchieved ? Colors.green : Colors.blueGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Placeholder cho các mục tiêu khác ---
                  // Ví dụ: Card Mục tiêu Thời gian Hoạt động
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.timer_outlined),
                      title: Text("Activity Time Goal"),
                      subtitle: Text("Progress: ... / ... minutes"),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        /* ... */
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
