import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

const _uuid = Uuid();

/// Seeds the app with a few example habits on first launch, with a short
/// backfilled history, so CANOPY feels alive instead of empty before the
/// full Add Habit flow ships in the next stage.
List<Habit> buildSampleHabits() {
  final now = DateTime.now();

  final hydration = Habit(
    id: _uuid.v4(),
    name: 'Hydration',
    iconKey: 'water',
    colorValue: AppColors.oceanBlue.value,
    fontFamilyKey: 'cleanSans',
    goalType: GoalType.count,
    targetValue: 8,
    targetUnit: 'glasses',
    frequencyType: FrequencyType.daily,
  );

  final coding = Habit(
    id: _uuid.v4(),
    name: 'Coding',
    iconKey: 'coding',
    colorValue: AppColors.aqua.value,
    fontFamilyKey: 'mono',
    goalType: GoalType.duration,
    targetValue: 120,
    targetUnit: 'minutes',
    frequencyType: FrequencyType.daily,
  );

  final meditation = Habit(
    id: _uuid.v4(),
    name: 'Meditation',
    iconKey: 'meditation',
    colorValue: AppColors.lavender.value,
    fontFamilyKey: 'elegant',
    goalType: GoalType.simpleCompletion,
    frequencyType: FrequencyType.daily,
  );

  final reading = Habit(
    id: _uuid.v4(),
    name: 'Reading',
    iconKey: 'reading',
    colorValue: AppColors.emerald.value,
    fontFamilyKey: 'serif',
    goalType: GoalType.count,
    targetValue: 20,
    targetUnit: 'pages',
    frequencyType: FrequencyType.noFixedFrequency,
  );

  for (int i = 1; i <= 6; i++) {
    final day = now.subtract(Duration(days: i));
    hydration.completionHistory.add(
      CompletionEntry(date: day, progressValue: (5 + i % 4).toDouble(), completed: false),
    );
    coding.completionHistory.add(
      CompletionEntry(date: day, progressValue: (60 + i * 10).toDouble(), completed: false),
    );
    if (i % 2 == 0) {
      meditation.completionHistory.add(
        CompletionEntry(date: day, progressValue: 1, completed: true),
      );
    }
    if (i == 2 || i == 4) {
      reading.completionHistory.add(
        CompletionEntry(date: day, progressValue: 22, completed: true),
      );
    }
  }

  return [hydration, coding, meditation, reading];
}
