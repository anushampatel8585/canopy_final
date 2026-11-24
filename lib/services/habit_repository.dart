import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'habit_storage_service.dart';
import 'notification_service.dart';
import 'sample_data.dart';

/// Single source of truth for habit data. Screens read this via
/// `context.watch<HabitRepository>()` / `context.read<HabitRepository>()`
/// and never talk to storage directly.
class HabitRepository extends ChangeNotifier {
  final HabitStorageService _storage = HabitStorageService();
  final NotificationService _notifications = NotificationService();
  List<Habit> _habits = [];
  bool _isLoading = true;

  List<Habit> get habits => List.unmodifiable(_habits);
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final hasStoredHabits = await _storage.hasStoredHabits();
    _habits = await _storage.loadHabits();

    // Seed examples only on first launch. An intentionally empty list after
    // deleting the last habit must remain empty on later launches.
    if (!hasStoredHabits) {
      _habits = buildSampleHabits();
      await _storage.saveHabits(_habits);
    }

    // Restore scheduled habit reminders and the optional evening check-in.
    await _notifications.syncAllHabitNotifications(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
    notifyListeners();
    await _storage.saveHabits(_habits);
    await _notifications.syncAllHabitNotifications(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  Future<void> updateHabit(Habit updated) async {
    final index = _habits.indexWhere((h) => h.id == updated.id);
    if (index == -1) return;
    final oldHabit = _habits[index];
    await _notifications.cancelHabitReminders(oldHabit);

    _habits[index] = updated;
    notifyListeners();
    await _storage.saveHabits(_habits);

    // The global reminders setting remains authoritative; editing a habit
    // must never enable it implicitly.
    await _notifications.syncAllHabitNotifications(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  Future<void> deleteHabit(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return;

    _habits.removeAt(index);
    notifyListeners();
    await _storage.saveHabits(_habits);

    // Reconcile all ordinary reminders against the remaining habits. A full
    // sync also removes stale reminder IDs that cannot be derived from the
    // deleted habit's current reminder-time list.
    await _notifications.syncAllHabitNotifications(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  /// Replaces the current in-memory habits atomically, persists them,
  /// notifies listeners, and resyncs active notifications.
  Future<void> replaceHabits(List<Habit> newHabits) async {
    final oldHabits = List<Habit>.from(_habits);
    await _notifications.cancelAllHabitReminders(oldHabits);
    _habits = List.from(newHabits);
    notifyListeners();
    await _storage.saveHabits(_habits);
    await _notifications.syncAllHabitNotifications(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  /// Records progress for a habit on a specific date and persists it immediately.
  /// Protects against future dates and dates prior to habit creation.
  Future<void> setProgress(
    String habitId,
    DateTime date, {
    required double progressValue,
    required bool completed,
  }) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final habit = _habits[index];

    // Keep count goals within their configured target even if progress is
    // updated by a caller other than the Home screen.
    var safeProgress = progressValue < 0 ? 0.0 : progressValue;
    var safeCompleted = completed;
    final target = habit.targetValue;
    if ((habit.goalType == GoalType.count || habit.goalType == GoalType.duration) &&
        target != null && target > 0) {
      safeProgress = safeProgress.clamp(0.0, target).toDouble();
      if (safeProgress >= target) safeCompleted = true;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Future dates are not allowed
    if (normalizedDate.isAfter(normalizedToday)) return;

    // Dates before habit creation are not allowed
    final normalizedCreated =
        DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    if (normalizedDate.isBefore(normalizedCreated)) return;

    final newEntry = CompletionEntry(
      date: normalizedDate,
      progressValue: safeProgress,
      completed: safeCompleted,
    );

    habit.completionHistory.removeWhere((e) => e.normalizedDate == normalizedDate);
    if (safeProgress > 0 || safeCompleted) {
      habit.completionHistory.add(newEntry);
    }

    notifyListeners();
    await _storage.saveHabits(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  /// Removes any progress log for a habit on a given date.
  Future<void> removeProgress(String habitId, DateTime date) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final habit = _habits[index];
    final normalizedDate = DateTime(date.year, date.month, date.day);

    habit.completionHistory.removeWhere((e) => e.normalizedDate == normalizedDate);

    notifyListeners();
    await _storage.saveHabits(_habits);
    await _notifications.scheduleMissedHabitCheckin(_habits);
  }

  /// Records today's progress for a habit. (Compatibility wrapper)
  Future<void> setTodayProgress(
    String habitId, {
    required double progressValue,
    required bool completed,
  }) =>
      setProgress(
        habitId,
        DateTime.now(),
        progressValue: progressValue,
        completed: completed,
      );
}
