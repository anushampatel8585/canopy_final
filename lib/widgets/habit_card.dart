import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/icon_registry.dart';
import 'activity_strip.dart';

/// A single habit's card. The subtitle and the action control both adapt
/// to the habit's goal type — count habits get +/- buttons, duration
/// habits get the same in larger steps, simple-completion habits get a
/// single toggle.
class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggleComplete;
  final VoidCallback onTap;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggleComplete,
    required this.onTap,
  });

  AppFontFamily get _font => AppFontFamily.values.firstWhere(
        (f) => f.name == habit.fontFamilyKey,
        orElse: () => AppFontFamily.modernSans,
      );

  @override
  Widget build(BuildContext context) {
    final color = habit.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: IconRegistry.iconFor(habit.iconKey), color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: AppFonts.style(
                          _font,
                          fontWeight: FontWeight.values[habit.fontWeightIndex],
                          fontStyle: habit.isItalic ? FontStyle.italic : FontStyle.normal,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                _StreakPill(streak: habit.currentStreak, color: color),
              ],
            ),
            if (habit.frequencyType == FrequencyType.custom &&
                (habit.customSchedule?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Schedule: ${habit.customSchedule!.trim()}',
                  softWrap: true,
                  textWidthBasis: TextWidthBasis.parent,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ActivityStrip(habit: habit),
                _buildAction(color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    switch (habit.goalType) {
      case GoalType.simpleCompletion:
        return habit.isCompletedToday ? 'Completed today' : 'Not completed yet';
      case GoalType.count:
        final target = habit.targetValue?.toInt() ?? 0;
        final unit = habit.targetUnit ?? '';
        return '${habit.todayProgress.toInt()} / $target $unit';
      case GoalType.duration:
        final target = habit.targetValue ?? 0;
        return '${_formatMinutes(habit.todayProgress)} / ${_formatMinutes(target)}';
      case GoalType.custom:
        return habit.isCompletedToday ? 'Done today' : 'Tap to log progress';
    }
  }

  String _formatMinutes(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toInt();
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    return '${m}m';
  }

  Widget _buildAction(Color color) {
    if (habit.goalType == GoalType.count || habit.goalType == GoalType.duration) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconButton(icon: Icons.remove_rounded, color: color, onTap: onDecrement),
          const SizedBox(width: 8),
          _RoundIconButton(
            icon: Icons.add_rounded,
            color: color,
            onTap: onIncrement,
            filled: true,
          ),
        ],
      );
    }
    return _RoundIconButton(
      icon: habit.isCompletedToday ? Icons.check_rounded : Icons.circle_outlined,
      color: color,
      onTap: onToggleComplete,
      filled: habit.isCompletedToday,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  final Color color;
  const _StreakPill({required this.streak, required this.color});

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _RoundIconButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.black : color),
      ),
    );
  }
}
