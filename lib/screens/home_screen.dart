import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/habit_card.dart';
import 'add_habit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Winding down?';
  }

  String _formattedDate() {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  double _overallProgress(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    final total = habits.fold<double>(
      0,
      (sum, habit) => sum + habit.todayProgressRatio,
    );
    return total / habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<HabitRepository>();

    if (repo.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final habits = repo.habits;
    final overall = _overallProgress(habits);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.appName,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _greeting(),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedDate(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _OverallProgressCard(
                  progress: overall,
                  habitCount: habits.length,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Habits',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const _AddHabitButton(),
              ],
            ),
          ),
        ),
        if (habits.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyHomeState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.separated(
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final habit = habits[i];

                return HabitCard(
                  habit: habit,
                  onIncrement: () => _adjust(context, habit, 1),
                  onDecrement: () => _adjust(context, habit, -1),
                  onToggleComplete: () => _toggleComplete(context, habit),
                  onTap: () => _editHabit(context, habit),
                );
              },
            ),
          ),
      ],
    );
  }

  void _editHabit(BuildContext context, Habit habit) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddHabitScreen(habit: habit),
      ),
    );
  }

  
  void _adjust(BuildContext context, Habit habit, int direction) {
    final step = habit.goalType == GoalType.duration ? 15.0 : 1.0;
    final target = habit.targetValue;

    final rawValue = habit.todayProgress + direction * step;

    final double newValue;

    if ((habit.goalType == GoalType.count ||
            habit.goalType == GoalType.duration) &&
        target != null && target > 0) {
      // Measured goals must stay between zero and their configured target.
      newValue = rawValue.clamp(0.0, target).toDouble();
    } else {
      newValue = rawValue.clamp(0.0, double.infinity).toDouble();
    }

    final completed = target != null && newValue >= target;

    context.read<HabitRepository>().setTodayProgress(
          habit.id,
          progressValue: newValue,
          completed: completed,
        );
  }


  void _toggleComplete(BuildContext context, Habit habit) {
    final nowCompleted = !habit.isCompletedToday;

    context.read<HabitRepository>().setTodayProgress(
      habit.id,
      progressValue: nowCompleted ? 1 : 0,
      completed: nowCompleted,
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final double progress;
  final int habitCount;

  const _OverallProgressCard({
    required this.progress,
    required this.habitCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 5,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.aqua,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Progress",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  habitCount == 0
                      ? 'Add your first habit to get started'
                      : '$habitCount habit${habitCount == 1 ? '' : 's'} tracked today',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddHabitButton extends StatelessWidget {
  const _AddHabitButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddHabitScreen(),
          ),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.aqua,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }
}

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.spa_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button above to start building your routine.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}