// lib/screens/core/goals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';

// <<< THÊM CÁC IMPORT MỚI >>>
import '../../providers/goals_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';

// <<< CHUYỂN THÀNH STATELESSWIDGET ĐỂ ĐƠN GIẢN HÓA >>>
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  // --- HÀM HIỂN THỊ DIALOG ĐÃ ĐƯỢC CẬP NHẬT ---
  // Chúng ta chuyển nó ra ngoài và nhận BuildContext để có thể gọi từ StatelessWidget
  Future<void> _showSetGoalDialog(BuildContext context) async {
    // Sử dụng context.read để lấy provider mà không cần lắng nghe thay đổi trong dialog
    final goalsProvider = context.read<GoalsProvider>();
    final l10n = AppLocalizations.of(context)!;

    final formKey = GlobalKey<FormState>();
    // Lấy giá trị mục tiêu hiện tại từ provider để điền vào controller
    final TextEditingController goalDialogController =
        TextEditingController(text: goalsProvider.currentStepGoal.toString());

    int? newGoal = await showDialog<int>(
      context: context,
      barrierDismissible: false, // Ngăn đóng khi nhấn ra ngoài
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.setGoalDialogTitle),
        contentPadding: const EdgeInsets.all(20.0),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: goalDialogController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: l10n.newGoalLabel,
              prefixIcon: const Icon(Icons.flag_outlined),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.pleaseEnterNumber;
              final number = int.tryParse(value);
              if (number == null) return l10n.invalidNumber;
              if (number <= 0) return l10n.goalGreaterThanZero;
              if (number > 99999)
                return l10n.goalTooHigh; // Tăng giới hạn nếu muốn
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final enteredGoal = int.tryParse(goalDialogController.text);
                Navigator.of(dialogContext).pop(enteredGoal);
              }
            },
            child: Text(l10n.saveGoalButton),
          ),
        ],
      ),
    );

    // Xử lý sau khi dialog đóng
    if (newGoal != null && newGoal != goalsProvider.currentStepGoal) {
      // Gọi provider để cập nhật mục tiêu mới lên Firestore
      final success = await goalsProvider.updateDailyGoal(newGoal);

      // Hiển thị SnackBar dựa trên kết quả
      // Kiểm tra `mounted` bằng cách đảm bảo context vẫn còn trong cây widget
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? l10n.goalSavedSuccess
                : goalsProvider.goalError ?? l10n.goalSavedError),
            backgroundColor:
                success ? Colors.green : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    // Dọn dẹp controller
    goalDialogController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // <<< SỬ DỤNG CONTEXT.WATCH ĐỂ LẮNG NGHE CÁC PROVIDER >>>
    final goalsProvider = context.watch<GoalsProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    // Xác định trạng thái loading tổng thể từ cả hai provider
    final bool isLoading = (goalsProvider.isLoadingGoal) ||
        (dashboardProvider.historyStatus == HistoryStatus.loading);

    // Lấy dữ liệu đã được xử lý từ các provider
    final int currentStepGoal = goalsProvider.currentStepGoal;
    final int todaySteps = dashboardProvider.todayTotalSteps;

    // Tính toán tiến độ dựa trên dữ liệu từ provider
    final double progressPercent = (currentStepGoal > 0)
        ? (todaySteps / currentStepGoal).clamp(0.0, 1.0)
        : 0.0;
    final bool goalAchieved = progressPercent >= 1.0;
    final int remainingSteps =
        (currentStepGoal - todaySteps).clamp(0, currentStepGoal);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalsTitle)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                print("[GoalsScreen] Pull to refresh triggered.");
                // Tải lại cả hai nguồn dữ liệu
                await Future.wait([
                  goalsProvider.loadDailyGoal(),
                  dashboardProvider.fetchHealthHistory()
                ]);
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.dailyStepGoalCardTitle,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              IconButton(
                                icon: Icon(Icons.edit_note,
                                    color: Theme.of(context).primaryColor),
                                tooltip: l10n.setNewGoalTooltip,
                                // Gọi hàm helper _showSetGoalDialog
                                onPressed: () => _showSetGoalDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          // Vòng tròn Tiến độ (dữ liệu lấy từ provider)
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
                                Text(
                                  "$todaySteps", // Dữ liệu từ DashboardProvider
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "/ $currentStepGoal ${l10n.stepsUnit}", // Dữ liệu từ GoalsProvider
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
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            animation: true,
                            animateFromLastPercent: true,
                            animationDuration: 600,
                          ),
                          const SizedBox(height: 25),

                          Text(
                            goalAchieved
                                ? l10n.goalAchievedMessage
                                : l10n.goalRemainingMessage('$remainingSteps'),
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
                  // Placeholder cho các mục tiêu khác
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(l10n.activityTimeGoalTitle),
                      subtitle: Text(l10n.activityTimeGoalProgress),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Logic cho mục tiêu khác sẽ được thêm ở đây trong tương lai
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('This feature is coming soon!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
