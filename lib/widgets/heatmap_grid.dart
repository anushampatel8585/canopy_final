import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

enum HeatmapRange { week, month, year }

class HeatmapGrid extends StatelessWidget {
  final Habit habit;
  final HeatmapRange range;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final DateTime? displayedMonth;
  final ValueChanged<DateTime>? onMonthChanged;

  const HeatmapGrid({
    super.key,
    required this.habit,
    this.range = HeatmapRange.week,
    this.selectedDate,
    this.onDateSelected,
    this.displayedMonth,
    this.onMonthChanged,
  });

  DateTime _normalized(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    switch (range) {
      case HeatmapRange.week:
        return _buildWeekView();
      case HeatmapRange.month:
        return _buildMonthView();
      case HeatmapRange.year:
        return _buildYearView();
    }
  }

  Widget _buildWeekView() {
    final today = _normalized(DateTime.now());
    // Last 7 days ending today
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final label = weekdayLabels[day.weekday - 1];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            _buildCell(day, size: 36, showDayNumber: true),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMonthView() {
    final month = displayedMonth ?? DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - DateTime.monday;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onMonthChanged == null ? null : () => onMonthChanged!(DateTime(month.year, month.month - 1, 1)),
              icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            ),
            Expanded(child: Center(child: Text('${monthNames[month.month - 1]} ${month.year}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)))),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onMonthChanged == null || (month.year == DateTime.now().year && month.month >= DateTime.now().month) ? null : () => onMonthChanged!(DateTime(month.year, month.month + 1, 1)),
              icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekdayLabels.map((label) => SizedBox(width: 32, child: Center(child: Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w500))))).toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1),
          itemCount: totalCells,
          itemBuilder: (context, i) {
            final dayNumber = i - leading + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
            return _buildCell(DateTime(month.year, month.month, dayNumber), size: 32, showDayNumber: true);
          },
        ),
      ],
    );
  }

  Widget _buildYearView() {
    final today = _normalized(DateTime.now());
    // 14 weeks = 98 days
    const totalDays = 98;
    final days = List.generate(totalDays, (i) => today.subtract(Duration(days: totalDays - 1 - i)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // latest days visible on the right
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate((totalDays / 7).ceil(), (col) {
          final weekDays = days.skip(col * 7).take(7).toList();
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: weekDays.map((day) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildCell(day, size: 16, showDayNumber: false),
                );
              }).toList(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell(DateTime day, {required double size, required bool showDayNumber}) {
    final normDay = _normalized(day);
    final isFuture = habit.isFuture(normDay);
    final isBeforeCreation = habit.isBeforeCreation(normDay);
    final isSelectable = !isFuture && !isBeforeCreation;

    final isSelected = selectedDate != null && _normalized(selectedDate!) == normDay;
    final intensity = habit.intensityFor(normDay);
    final isCompleted = habit.isCompletedOn(normDay);
    final isScheduled = habit.isScheduledOn(normDay);

    Color cellBg;
    if (isFuture) {
      cellBg = AppColors.surfaceHigh.withValues(alpha: 0.3);
    } else if (isBeforeCreation) {
      cellBg = AppColors.surface.withValues(alpha: 0.2);
    } else if (!isScheduled && intensity <= 0) {
      cellBg = AppColors.surface;
    } else {
      cellBg = AppColors.intensity(habit.color, intensity);
    }

    Border border;
    if (isSelected) {
      border = Border.all(color: Colors.white, width: 2.0);
    } else if (isFuture || isBeforeCreation) {
      border = Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.4), width: 1.0);
    } else if (!isScheduled && intensity <= 0) {
      border = Border.all(color: AppColors.borderSubtle, width: 1.0);
    } else {
      border = Border.all(
        color: isCompleted ? habit.color.withValues(alpha: 0.6) : AppColors.border,
        width: 1.0,
      );
    }

    Widget cellContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(size > 20 ? 8 : 4),
        border: border,
      ),
      alignment: Alignment.center,
      child: showDayNumber
          ? Text(
              '${day.day}',
              style: TextStyle(
                fontSize: size > 30 ? 11 : 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isFuture || isBeforeCreation
                    ? AppColors.textTertiary.withValues(alpha: 0.4)
                    : (intensity > 0.5 ? Colors.black : AppColors.textPrimary),
              ),
            )
          : null,
    );

    if (!isSelectable) {
      return cellContent;
    }

    return InkWell(
      onTap: () => onDateSelected?.call(normDay),
      borderRadius: BorderRadius.circular(size > 20 ? 8 : 4),
      child: cellContent,
    );
  }
}
