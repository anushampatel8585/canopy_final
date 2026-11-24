import 'package:flutter/material.dart';

enum GoalType { simpleCompletion, count, duration, custom }

enum FrequencyType { daily, specificDays, custom, noFixedFrequency }

extension GoalTypeLabel on GoalType {
  String get label {
    switch (this) {
      case GoalType.simpleCompletion:
        return 'Simple Completion';
      case GoalType.count:
        return 'Count';
      case GoalType.duration:
        return 'Duration';
      case GoalType.custom:
        return 'Custom / Flexible';
    }
  }
}

extension FrequencyTypeLabel on FrequencyType {
  String get label {
    switch (this) {
      case FrequencyType.daily:
        return 'Every day';
      case FrequencyType.specificDays:
        return 'Specific days';
      case FrequencyType.custom:
        return 'Custom schedule';
      case FrequencyType.noFixedFrequency:
        return 'No fixed frequency';
    }
  }
}

/// One recorded day of progress for a habit.
class CompletionEntry {
  final DateTime date;
  final double progressValue;
  final bool completed;

  CompletionEntry({
    required this.date,
    required this.progressValue,
    required this.completed,
  });

  DateTime get normalizedDate => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'progressValue': progressValue,
        'completed': completed,
      };

  factory CompletionEntry.fromJson(Map<String, dynamic> json) {
    return CompletionEntry(
      date: DateTime.parse(json['date'] as String),
      progressValue: (json['progressValue'] as num).toDouble(),
      completed: json['completed'] as bool,
    );
  }
}

class Habit {
  final String id;
  String name;
  String iconKey;
  int colorValue;
  String fontFamilyKey;
  int fontWeightIndex; // index into FontWeight.values (0..8)
  bool isItalic;

  GoalType goalType;
  double? targetValue; // used for count / duration
  String? targetUnit; // e.g. "glasses", "pages", "minutes"

  FrequencyType frequencyType;
  List<int> selectedDays; // DateTime.weekday values: 1=Mon ... 7=Sun
  String? customSchedule;

  bool reminderEnabled;
  List<String> reminderTimes; // "HH:mm"

  final DateTime createdAt;
  List<CompletionEntry> completionHistory;

  Habit({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.fontFamilyKey,
    this.fontWeightIndex = 3,
    this.isItalic = false,
    this.goalType = GoalType.simpleCompletion,
    this.targetValue,
    this.targetUnit,
    this.frequencyType = FrequencyType.daily,
    List<int>? selectedDays,
    this.customSchedule,
    this.reminderEnabled = false,
    List<String>? reminderTimes,
    DateTime? createdAt,
    List<CompletionEntry>? completionHistory,
  })  : selectedDays = selectedDays ?? [],
        reminderTimes = reminderTimes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        completionHistory = completionHistory ?? [];

  Color get color => Color(colorValue);

  // ---- Everything below is calculated, never hard-coded ----

  DateTime _normalized(DateTime d) => DateTime(d.year, d.month, d.day);

  CompletionEntry? entryFor(DateTime day) {
    final target = _normalized(day);
    for (final entry in completionHistory) {
      if (entry.normalizedDate == target) return entry;
    }
    return null;
  }

  double progressFor(DateTime day) => entryFor(day)?.progressValue ?? 0.0;

  bool isCompletedOn(DateTime day) {
    final entry = entryFor(day);
    if (entry == null) return false;
    return _isCompletionCounted(entry);
  }

  double progressRatioFor(DateTime day) {
    if (goalType == GoalType.simpleCompletion) {
      return isCompletedOn(day) ? 1.0 : 0.0;
    }
    if (targetValue == null || targetValue == 0) {
      return isCompletedOn(day) ? 1.0 : 0.0;
    }
    return (progressFor(day) / targetValue!).clamp(0.0, 1.0);
  }

  bool isScheduledOn(DateTime day) {
    if (frequencyType == FrequencyType.specificDays) {
      if (selectedDays.isEmpty) return true;
      return selectedDays.contains(day.weekday);
    }
    return true;
  }

  bool isBeforeCreation(DateTime day) {
    return _normalized(day).isBefore(_normalized(createdAt));
  }

  bool isFuture(DateTime day) {
    return _normalized(day).isAfter(_normalized(DateTime.now()));
  }

  CompletionEntry? get todayEntry => entryFor(DateTime.now());

  double get todayProgress => progressFor(DateTime.now());

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  double get todayProgressRatio => progressRatioFor(DateTime.now());

  /// Current streak counted backward from today. If today isn't completed
  /// yet, checking starts from the most recent scheduled day before today.
  int get currentStreak {
    int streak = 0;
    final now = DateTime.now();
    DateTime cursor = _normalized(now);
    final normCreated = _normalized(createdAt);

    if (isScheduledOn(cursor) && !isCompletedOn(cursor)) {
      cursor = _previousScheduledDay(cursor);
    } else if (!isScheduledOn(cursor)) {
      cursor = _previousScheduledDay(cursor);
    }

    while (cursor.isAfter(normCreated) || cursor.isAtSameMomentAs(normCreated)) {
      if (isScheduledOn(cursor)) {
        if (isCompletedOn(cursor)) {
          streak++;
        } else {
          break;
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _previousScheduledDay(DateTime from) {
    DateTime cur = from.subtract(const Duration(days: 1));
    while (!isScheduledOn(cur) && cur.year > 2000) {
      cur = cur.subtract(const Duration(days: 1));
    }
    return cur;
  }

  /// Longest streak ever found in the full completion history.
  int get bestStreak {
    if (completionHistory.isEmpty) return 0;
    final completedDays = completionHistory
        .where(_isCompletionCounted)
        .map((e) => e.normalizedDate)
        .toSet()
        .toList()
      ..sort();

    if (completedDays.isEmpty) return 0;

    if (frequencyType != FrequencyType.specificDays || selectedDays.isEmpty) {
      int best = 0;
      int running = 0;
      DateTime? previous;

      for (final day in completedDays) {
        if (previous != null && day.difference(previous).inDays == 1) {
          running++;
        } else {
          running = 1;
        }
        best = running > best ? running : best;
        previous = day;
      }
      return best;
    } else {
      DateTime cursor = completedDays.first;
      final end = completedDays.last;
      int best = 0;
      int running = 0;

      while (cursor.isBefore(end) || cursor.isAtSameMomentAs(end)) {
        if (isScheduledOn(cursor)) {
          if (isCompletedOn(cursor)) {
            running++;
            best = running > best ? running : best;
          } else {
            running = 0;
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      return best;
    }
  }

  bool _isCompletionCounted(CompletionEntry entry) {
    if (goalType == GoalType.simpleCompletion) return entry.completed;
    if (targetValue == null) return entry.completed;
    return entry.progressValue >= targetValue!;
  }

  /// Intensity (0.0–1.0) for a given day, used to shade activity blocks.
  double intensityFor(DateTime day) {
    final entry = entryFor(day);
    if (entry == null) return 0.0;
    if (goalType == GoalType.simpleCompletion) {
      return entry.completed ? 1.0 : 0.0;
    }
    if (targetValue == null || targetValue == 0) {
      return entry.completed ? 1.0 : 0.0;
    }
    return (entry.progressValue / targetValue!).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'fontFamilyKey': fontFamilyKey,
        'fontWeightIndex': fontWeightIndex,
        'isItalic': isItalic,
        'goalType': goalType.name,
        'targetValue': targetValue,
        'targetUnit': targetUnit,
        'frequencyType': frequencyType.name,
        'selectedDays': selectedDays,
        'customSchedule': customSchedule,
        'reminderEnabled': reminderEnabled,
        'reminderTimes': reminderTimes,
        'createdAt': createdAt.toIso8601String(),
        'completionHistory': completionHistory.map((e) => e.toJson()).toList(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
      colorValue: json['colorValue'] as int,
      fontFamilyKey: json['fontFamilyKey'] as String,
      fontWeightIndex: json['fontWeightIndex'] as int? ?? 3,
      isItalic: json['isItalic'] as bool? ?? false,
      goalType: GoalType.values.firstWhere(
        (e) => e.name == json['goalType'],
        orElse: () => GoalType.simpleCompletion,
      ),
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      targetUnit: json['targetUnit'] as String?,
      frequencyType: FrequencyType.values.firstWhere(
        (e) => e.name == json['frequencyType'],
        orElse: () => FrequencyType.daily,
      ),
      selectedDays: (json['selectedDays'] as List?)?.cast<int>() ?? [],
      customSchedule: json['customSchedule'] as String?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderTimes: (json['reminderTimes'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      completionHistory: (json['completionHistory'] as List? ?? [])
          .map((e) => CompletionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
