import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../theme/app_colors.dart';
import '../theme/icon_registry.dart';

class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitRepository>().habits;
    final sorted = [...habits]..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    final bestOverall =
        habits.fold<int>(0, (best, h) => h.bestStreak > best ? h.bestStreak : best);
    final currentOverall =
        habits.fold<int>(0, (best, h) => h.currentStreak > best ? h.currentStreak : best);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Streaks', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Longest active streak',
                        value: '$currentOverall',
                        color: AppColors.aqua,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Best streak ever',
                        value: '$bestOverall',
                        color: AppColors.violet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (sorted.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('Your habit streaks will show up here.',
                  style: TextStyle(color: AppColors.textTertiary)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverList.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _StreakRow(habit: sorted[i]),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: color, size: 18),
              const SizedBox(width: 6),
              Text(value,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final Habit habit;
  const _StreakRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: habit.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(IconRegistry.iconFor(habit.iconKey), color: habit.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Best: ${habit.bestStreak} days',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${habit.currentStreak}',
            style: TextStyle(color: habit.color, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          const Text('days', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
