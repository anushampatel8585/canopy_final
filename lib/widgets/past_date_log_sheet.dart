import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../theme/app_colors.dart';
import '../theme/icon_registry.dart';

class PastDateLogSheet extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const PastDateLogSheet({
    super.key,
    required this.habit,
    required this.date,
  });

  static Future<void> show(BuildContext context, {required Habit habit, required DateTime date}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PastDateLogSheet(habit: habit, date: date),
    );
  }

  String _formattedDate(DateTime d) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final dateStr = '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    return isToday ? 'Today • $dateStr' : dateStr;
  }

  String _formatMinutes(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toInt();
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    // Watch repository to reactively update the sheet if values change
    final habits = context.watch<HabitRepository>().habits;
    final currentHabit = habits.firstWhere((h) => h.id == habit.id, orElse: () => habit);
    final isCompleted = currentHabit.isCompletedOn(date);
    final progress = currentHabit.progressFor(date);
    final hasEntry = currentHabit.entryFor(date) != null;
    final color = currentHabit.color;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(IconRegistry.iconFor(currentHabit.iconKey), color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentHabit.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        _formattedDate(date),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildControls(context, currentHabit, progress, isCompleted, color),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasEntry)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        context.read<HabitRepository>().removeProgress(currentHabit.id, date);
                      },
                      child: const Text('Clear log'),
                    ),
                  ),
                if (hasEntry) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceHigh,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    Habit habit,
    double progress,
    bool isCompleted,
    Color color,
  ) {
    if (habit.goalType == GoalType.count || habit.goalType == GoalType.duration) {
      final isDuration = habit.goalType == GoalType.duration;
      final step = isDuration ? 15.0 : 1.0;
      final target = habit.targetValue ?? 0;
      final unit = habit.targetUnit ?? '';

      final displayCurrent = isDuration ? _formatMinutes(progress) : '${progress.toInt()}';
      final displayTarget = isDuration ? _formatMinutes(target) : '${target.toInt()} $unit';

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCompleted ? 'Target Completed ✓' : 'Progress',
                style: TextStyle(
                  color: isCompleted ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '$displayCurrent / $displayTarget',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.remove_rounded,
                color: color,
                onTap: () {
                  final newProgress = (progress - step).clamp(0.0, double.infinity).toDouble();
                  final nowCompleted = target > 0 && newProgress >= target;
                  context.read<HabitRepository>().setProgress(
                        habit.id,
                        date,
                        progressValue: newProgress,
                        completed: nowCompleted,
                      );
                },
              ),
              const SizedBox(width: 24),
              _ActionButton(
                icon: Icons.add_rounded,
                color: color,
                filled: true,
                onTap: () {
                  final newProgress = (progress + step).toDouble();
                  final nowCompleted = target > 0 && newProgress >= target;
                  context.read<HabitRepository>().setProgress(
                        habit.id,
                        date,
                        progressValue: newProgress,
                        completed: nowCompleted,
                      );
                },
              ),
            ],
          ),
        ],
      );
    }

    // Simple completion / Custom
    return InkWell(
      onTap: () {
        final nowCompleted = !isCompleted;
        context.read<HabitRepository>().setProgress(
              habit.id,
              date,
              progressValue: nowCompleted ? 1.0 : 0.0,
              completed: nowCompleted,
            );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isCompleted ? color.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCompleted ? color : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isCompleted ? color : AppColors.textTertiary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isCompleted ? 'Completed on this day' : 'Mark as completed',
              style: TextStyle(
                color: isCompleted ? color : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 24, color: filled ? Colors.black : color),
      ),
    );
  }
}
