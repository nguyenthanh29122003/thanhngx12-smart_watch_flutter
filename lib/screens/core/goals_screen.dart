// lib/screens/core/goals_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers, Models, Constants và l10n
import '../../providers/goals_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>

// Widget chính của màn hình
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalsTitle)),
      // Sử dụng Consumer2 để lắng nghe cả hai provider
      body: Consumer2<GoalsProvider, DashboardProvider>(
        builder: (context, goals, dashboard, child) {
          final bool isLoading = (goals.isLoadingGoal ||
              dashboard.historyStatus != HistoryStatus.loaded);

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                context.read<GoalsProvider>().loadDailyGoal(),
                context.read<DashboardProvider>().fetchHealthHistory()
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 150.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (dashboard.historyStatus == HistoryStatus.error)
                  Center(
                      child: Text(
                          dashboard.historyError ?? l10n.chartCouldNotLoad,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))
                else ...[
                  // --- Nội dung chính ---
                  _MainGoalCard(
                    goal: goals.currentStepGoal,
                    steps: dashboard.todayTotalSteps,
                  ),
                  const SizedBox(height: 32),
                  _SectionTitle(l10n.otherGoalsTitle),
                  const SizedBox(height: 12),
                  _PlaceholderGoalCard(
                    icon: Icons.hotel_outlined,
                    title: l10n.sleepGoalTitle,
                    progressText: l10n.comingSoon,
                  ),
                  _PlaceholderGoalCard(
                    icon: Icons.local_fire_department_outlined,
                    title: l10n.caloriesGoalTitle,
                    progressText: l10n.comingSoon,
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// WIDGET CON ĐÃ TÁCH RA VÀ SỬA LỖI
// ================================================================

// --- CARD MỤC TIÊU CHÍNH (Đã chuyển thành StatefulWidget) ---
class _MainGoalCard extends StatefulWidget {
  final int goal;
  final int steps;

  const _MainGoalCard({required this.goal, required this.steps});

  @override
  State<_MainGoalCard> createState() => _MainGoalCardState();
}

class _MainGoalCardState extends State<_MainGoalCard> {
  // Controller được quản lý bên trong state của widget này
  final _goalDialogController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _goalDialogController.dispose();
    super.dispose();
  }

  // --- Hàm DIALOG đã được chuyển vào đây để đảm bảo context an toàn ---
  Future<void> _showSetGoalDialog() async {
    // context ở đây là context của _MainGoalCardState, không phải của GoalsScreen
    final goalsProvider = context.read<GoalsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _goalDialogController.text = goalsProvider.currentStepGoal.toString();

    final int? newGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: theme.colorScheme.surface,
        title: Text(l10n.setGoalDialogTitle),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _goalDialogController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.newGoalLabel,
              prefixIcon:
                  Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.pleaseEnterNumber;
              final number = int.tryParse(value);
              if (number == null) return l10n.invalidNumber;
              if (number <= 0) return l10n.goalGreaterThanZero;
              if (number > 50000) return l10n.goalTooHigh;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext)
                    .pop(int.tryParse(_goalDialogController.text));
              }
            },
            child: Text(l10n.saveGoalButton),
          ),
        ],
      ),
    );

    if (newGoal != null && newGoal != goalsProvider.currentStepGoal) {
      final success = await goalsProvider.updateDailyGoal(newGoal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? l10n.goalSavedSuccess
                : (goalsProvider.goalError ?? l10n.goalSavedError)),
            backgroundColor: success ? Colors.green : theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Hàm quote cũng được chuyển vào đây
  String _getMotivationalQuote(double progress) {
    // context có thể được truy cập trực tiếp vì hàm này nằm trong State
    final l10n = AppLocalizations.of(context)!;
    final List<String> quotes;
    if (progress >= 1.0) {
      quotes = [l10n.quoteGoalAchieved1, l10n.quoteGoalAchieved2];
    } else if (progress > 0.75) {
      quotes = [l10n.quoteAlmostThere1, l10n.quoteAlmostThere2];
    } else if (progress > 0.25) {
      quotes = [l10n.quoteGoodStart1, l10n.quoteGoodStart2];
    } else {
      quotes = [l10n.quoteKeepGoing1, l10n.quoteKeepGoing2];
    }
    return (quotes..shuffle()).first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double progress =
        (widget.goal > 0) ? (widget.steps / widget.goal).clamp(0.0, 1.0) : 0.0;
    final bool goalAchieved = progress >= 1.0;

    return Card(
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showSetGoalDialog, // Gọi hàm nội bộ, đã an toàn
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.dailyStepGoalCardTitle,
                      style: theme.textTheme.titleMedium),
                  Icon(Icons.edit_outlined,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      size: 22)
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 14,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goalAchieved
                            ? Colors.green.shade500
                            : theme.colorScheme.primary,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            NumberFormat.decimalPattern().format(widget.steps),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: goalAchieved
                                  ? Colors.green.shade600
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "/ ${NumberFormat.decimalPattern().format(widget.goal)}",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withOpacity(0.7),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _getMotivationalQuote(progress),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TIÊU ĐỀ SECTION ---
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

// --- CARD PLACEHOLDER CHO CÁC MỤC TIÊU KHÁC ---
class _PlaceholderGoalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String progressText;

  const _PlaceholderGoalCard(
      {required this.icon, required this.title, required this.progressText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, color: theme.colorScheme.secondary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(progressText,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
        trailing: const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.comingSoon)));
        },
      ),
    );
  }
}
