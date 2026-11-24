import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

/// Row of activity blocks (GitHub/LeetCode-style), showing the last [days]
/// days of a habit's history. Used inside habit cards now; Stats/Streaks
/// will reuse this same visual language at a larger scale in a later stage.
class ActivityStrip extends StatelessWidget {
  final Habit habit;
  final int days;
  final double blockSize;

  const ActivityStrip({
    super.key,
    required this.habit,
    this.days = 7,
    this.blockSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final blocks = List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return _ActivityBlock(
        color: habit.color,
        intensity: habit.intensityFor(day),
        size: blockSize,
      );
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          blocks[i],
          if (i != blocks.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ActivityBlock extends StatelessWidget {
  final Color color;
  final double intensity;
  final double size;

  const _ActivityBlock({
    required this.color,
    required this.intensity,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.intensity(color, intensity),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
    );
  }
}
