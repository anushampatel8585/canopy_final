import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canopy/models/habit.dart';
import 'package:canopy/services/habit_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 - Past-Date Logging & Streak Calculation Tests', () {
    late HabitRepository repository;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fiveDaysAgo = today.subtract(const Duration(days: 5));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = HabitRepository();
      await repository.load();
    });

    test('1. Past-date insertion: correctly adds a new CompletionEntry on a past date', () async {
      final habit = Habit(
        id: 'test-habit-1',
        name: 'Morning Meditation',
        iconKey: 'sparkles',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: fiveDaysAgo,
      );
      await repository.addHabit(habit);

      final threeDaysAgo = today.subtract(const Duration(days: 3));
      await repository.setProgress(habit.id, threeDaysAgo, progressValue: 1.0, completed: true);

      final updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.isCompletedOn(threeDaysAgo), isTrue);
      expect(updatedHabit.progressFor(threeDaysAgo), 1.0);
      expect(updatedHabit.entryFor(threeDaysAgo), isNotNull);
    });

    test('2. Updating an existing date: modifies progress without duplicate entries', () async {
      final habit = Habit(
        id: 'test-habit-2',
        name: 'Drink Water',
        iconKey: 'water_drop',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        goalType: GoalType.count,
        targetValue: 8.0,
        createdAt: fiveDaysAgo,
      );
      await repository.addHabit(habit);

      final twoDaysAgo = today.subtract(const Duration(days: 2));
      await repository.setProgress(habit.id, twoDaysAgo, progressValue: 4.0, completed: false);
      var updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.completionHistory.length, 1);
      expect(updatedHabit.progressFor(twoDaysAgo), 4.0);
      expect(updatedHabit.isCompletedOn(twoDaysAgo), isFalse);

      // Update same date to 8.0 (completed)
      await repository.setProgress(habit.id, twoDaysAgo, progressValue: 8.0, completed: true);
      updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.completionHistory.length, 1);
      expect(updatedHabit.progressFor(twoDaysAgo), 8.0);
      expect(updatedHabit.isCompletedOn(twoDaysAgo), isTrue);
    });

    test('3. Removing a date: removes progress and updates completionHistory', () async {
      final habit = Habit(
        id: 'test-habit-3',
        name: 'Reading',
        iconKey: 'book',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: fiveDaysAgo,
      );
      await repository.addHabit(habit);

      final yesterday = today.subtract(const Duration(days: 1));
      await repository.setProgress(habit.id, yesterday, progressValue: 1.0, completed: true);
      var updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.isCompletedOn(yesterday), isTrue);

      await repository.removeProgress(habit.id, yesterday);
      updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.isCompletedOn(yesterday), isFalse);
      expect(updatedHabit.entryFor(yesterday), isNull);
    });

    test('4. Backfilling a streak: inserting a missing day merges gaps and increases currentStreak & bestStreak', () async {
      final habit = Habit(
        id: 'test-habit-4',
        name: 'Workout',
        iconKey: 'fitness',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: today.subtract(const Duration(days: 10)),
      );
      await repository.addHabit(habit);

      final day1 = today.subtract(const Duration(days: 3));
      final day2 = today.subtract(const Duration(days: 2));
      final day3 = today.subtract(const Duration(days: 1));

      // Log day1 and day3 (day2 is missing)
      await repository.setProgress(habit.id, day1, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, day3, progressValue: 1.0, completed: true);

      var updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.currentStreak, 1); // only day3 is contiguous to today
      expect(updatedHabit.bestStreak, 1);

      // Backfill missing day2
      await repository.setProgress(habit.id, day2, progressValue: 1.0, completed: true);
      updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.currentStreak, 3);
      expect(updatedHabit.bestStreak, 3);
    });

    test('5. Removing a middle streak entry: breaks streak into distinct segments', () async {
      final habit = Habit(
        id: 'test-habit-5',
        name: 'Journaling',
        iconKey: 'edit',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: today.subtract(const Duration(days: 10)),
      );
      await repository.addHabit(habit);

      final day1 = today.subtract(const Duration(days: 4));
      final day2 = today.subtract(const Duration(days: 3));
      final day3 = today.subtract(const Duration(days: 2));
      final day4 = today.subtract(const Duration(days: 1));

      await repository.setProgress(habit.id, day1, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, day2, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, day3, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, day4, progressValue: 1.0, completed: true);

      var updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.currentStreak, 4);
      expect(updatedHabit.bestStreak, 4);

      // Remove middle entry (day2)
      await repository.removeProgress(habit.id, day2);
      updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.currentStreak, 2); // only day3 and day4 remain contiguous
      expect(updatedHabit.bestStreak, 2);
    });

    test('6. Specific-day streak behavior: preserves streak across unscheduled days', () async {
      // Find a Monday 14 days ago
      DateTime mon = today.subtract(Duration(days: (today.weekday - 1) + 14));
      DateTime wed = mon.add(const Duration(days: 2));
      DateTime fri = mon.add(const Duration(days: 4));

      final habit = Habit(
        id: 'test-habit-6',
        name: 'Gym Mon-Wed-Fri',
        iconKey: 'fitness',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        frequencyType: FrequencyType.specificDays,
        selectedDays: [1, 3, 5], // Mon, Wed, Fri
        createdAt: mon,
      );
      await repository.addHabit(habit);

      // Log Mon, Wed, Fri
      await repository.setProgress(habit.id, mon, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, wed, progressValue: 1.0, completed: true);
      await repository.setProgress(habit.id, fri, progressValue: 1.0, completed: true);

      final updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      // Tuesday and Thursday were unscheduled, so all 3 scheduled days form a continuous streak of 3
      expect(updatedHabit.bestStreak, 3);
    });

    test('7. Future-date protection: rejects progress on dates after today', () async {
      final habit = Habit(
        id: 'test-habit-7',
        name: 'Future Task',
        iconKey: 'check',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: fiveDaysAgo,
      );
      await repository.addHabit(habit);

      final tomorrow = today.add(const Duration(days: 1));
      await repository.setProgress(habit.id, tomorrow, progressValue: 1.0, completed: true);

      final updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.entryFor(tomorrow), isNull);
      expect(updatedHabit.isCompletedOn(tomorrow), isFalse);
    });

    test('8. Pre-creation-date protection: rejects progress on dates before createdAt', () async {
      final habit = Habit(
        id: 'test-habit-8',
        name: 'Recent Habit',
        iconKey: 'star',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: today.subtract(const Duration(days: 2)),
      );
      await repository.addHabit(habit);

      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      await repository.setProgress(habit.id, fiveDaysAgo, progressValue: 1.0, completed: true);

      final updatedHabit = repository.habits.firstWhere((h) => h.id == habit.id);
      expect(updatedHabit.entryFor(fiveDaysAgo), isNull);
      expect(updatedHabit.isCompletedOn(fiveDaysAgo), isFalse);
    });

    test('9. Serialization: accurately preserves modified past-date completion history across JSON', () async {
      final pastDate = today.subtract(const Duration(days: 3));
      final habit = Habit(
        id: 'test-habit-9',
        name: 'Serialization Test',
        iconKey: 'save',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        goalType: GoalType.duration,
        targetValue: 60.0,
        createdAt: fiveDaysAgo,
        completionHistory: [
          CompletionEntry(date: pastDate, progressValue: 45.0, completed: false),
          CompletionEntry(date: today, progressValue: 60.0, completed: true),
        ],
      );

      final json = habit.toJson();
      final reconstructed = Habit.fromJson(json);

      expect(reconstructed.completionHistory.length, 2);
      expect(reconstructed.progressFor(pastDate), 45.0);
      expect(reconstructed.isCompletedOn(pastDate), isFalse);
      expect(reconstructed.progressRatioFor(pastDate), 0.75);
      expect(reconstructed.progressFor(today), 60.0);
      expect(reconstructed.isCompletedOn(today), isTrue);
      expect(reconstructed.progressRatioFor(today), 1.0);
    });
  });
}
