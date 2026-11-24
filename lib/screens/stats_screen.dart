import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/heatmap_grid.dart';
import '../widgets/past_date_log_sheet.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  HeatmapRange _range = HeatmapRange.week;
  final Map<String, DateTime> _selectedDates = {};
  final Map<String, DateTime> _displayedMonths = {};

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitRepository>().habits;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stats', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 16),
                _RangeSelector(
                  range: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textTertiary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Each habit has its own selected date. Tap a day to edit that habit’s log.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (habits.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Add a habit to see your statistics here.',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverList.separated(
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final habit = habits[i];
                final selectedDate = _selectedDates[habit.id] ?? _today();
                final displayedMonth = _displayedMonths[habit.id] ?? _currentMonth();
                return _HabitStatsCard(
                  habit: habit,
                  range: _range,
                  selectedDate: selectedDate,
                  displayedMonth: displayedMonth,
                  onMonthChanged: (month) => setState(() {
                    _displayedMonths[habit.id] = month;
                  }),
                  onDateSelected: (date) {
                    setState(() => _selectedDates[habit.id] = date);
                    PastDateLogSheet.show(context, habit: habit, date: date);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HabitStatsCard extends StatelessWidget {
  final Habit habit;
  final HeatmapRange range;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime displayedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _HabitStatsCard({
    required this.habit,
    required this.range,
    required this.selectedDate,
    required this.onDateSelected,
    required this.displayedMonth,
    required this.onMonthChanged,
  });

  String _selectedDaySummary() {
    if (habit.isFuture(selectedDate)) return 'Future date';
    if (habit.isBeforeCreation(selectedDate)) return 'Before habit created';

    final isCompleted = habit.isCompletedOn(selectedDate);
    final progress = habit.progressFor(selectedDate);

    switch (habit.goalType) {
      case GoalType.simpleCompletion:
        return isCompleted ? 'Completed ✓' : 'Not completed';
      case GoalType.count:
        final target = habit.targetValue?.toInt() ?? 0;
        final unit = habit.targetUnit ?? '';
        return '${progress.toInt()} / $target $unit ${isCompleted ? '✓' : ''}';
      case GoalType.duration:
        final target = habit.targetValue?.toInt() ?? 0;
        return '${progress.toInt()}m / ${target}m ${isCompleted ? '✓' : ''}';
      case GoalType.custom:
        return isCompleted ? 'Done ✓' : 'Incomplete';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(habit.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${habit.currentStreak} day streak',
                style: TextStyle(color: habit.color, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HeatmapGrid(
            habit: habit,
            range: range,
            selectedDate: selectedDate,
            displayedMonth: displayedMonth,
            onMonthChanged: onMonthChanged,
            onDateSelected: onDateSelected,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedDaySummary(),
                    style: TextStyle(
                      color: habit.isCompletedOn(selectedDate) ? habit.color : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!habit.isFuture(selectedDate) && !habit.isBeforeCreation(selectedDate))
                  InkWell(
                    onTap: () => onDateSelected(selectedDate),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Edit Log',
                        style: TextStyle(
                          color: habit.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: 'Best streak', value: '${habit.bestStreak}'),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Logged days',
                value: '${habit.completionHistory.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final HeatmapRange range;
  final ValueChanged<HeatmapRange> onChanged;
  const _RangeSelector({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: HeatmapRange.values.map((r) {
          final selected = r == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surfaceHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  r.name[0].toUpperCase() + r.name.substring(1),
                  style: TextStyle(
                    color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

