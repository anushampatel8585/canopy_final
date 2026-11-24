import 'dart:convert';
import '../config/app_config.dart';
import '../models/habit.dart';
import 'habit_repository.dart';
import 'settings_service.dart';

class BackupValidationResult {
  final bool isValid;
  final String? error;
  final int habitCount;
  final int totalLoggedDays;
  final DateTime? exportedAt;
  final Map<String, dynamic>? parsedSettings;
  final List<Habit>? parsedHabits;

  const BackupValidationResult.valid({
    required this.habitCount,
    required this.totalLoggedDays,
    required this.exportedAt,
    required this.parsedSettings,
    required this.parsedHabits,
  })  : isValid = true,
        error = null;

  const BackupValidationResult.invalid(this.error)
      : isValid = false,
        habitCount = 0,
        totalLoggedDays = 0,
        exportedAt = null,
        parsedSettings = null,
        parsedHabits = null;
}

class BackupRestoreResult {
  final bool isSuccess;
  final String message;
  final int restoredHabitCount;

  const BackupRestoreResult.success(this.restoredHabitCount)
      : isSuccess = true,
        message = 'Successfully restored $restoredHabitCount habits.';

  const BackupRestoreResult.failure(this.message)
      : isSuccess = false,
        restoredHabitCount = 0;
}

class BackupService {
  static const int currentSchemaVersion = 1;

  /// Creates a structured JSON backup string from current habits and settings.
  String createBackupJson({
    required List<Habit> habits,
    required SettingsService settings,
  }) {
    final Map<String, dynamic> backupData = {
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': AppConfig.appVersion,
      'settings': settings.toJson(),
      'habits': habits.map((h) => h.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Calculates the total number of logged habit entries across all habits.
  int getTotalLoggedDays(List<Habit> habits) {
    return habits.fold<int>(0, (sum, h) => sum + h.completionHistory.length);
  }

  /// Validates a raw backup JSON string completely before any state changes are made.
  BackupValidationResult validateBackupJson(String rawJson) {
    if (rawJson.trim().isEmpty) {
      return const BackupValidationResult.invalid('Backup data is empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (e) {
      return BackupValidationResult.invalid('Malformed JSON format: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      return const BackupValidationResult.invalid('Backup data must be a JSON object.');
    }

    final root = decoded;

    // Check schemaVersion
    if (!root.containsKey('schemaVersion') || root['schemaVersion'] is! int) {
      return const BackupValidationResult.invalid('Missing or invalid schemaVersion.');
    }

    final schemaVersion = root['schemaVersion'] as int;
    if (schemaVersion != currentSchemaVersion) {
      return BackupValidationResult.invalid(
        'Unsupported schemaVersion ($schemaVersion). Expected version $currentSchemaVersion.',
      );
    }

    // Check exportedAt
    if (!root.containsKey('exportedAt') || root['exportedAt'] is! String) {
      return const BackupValidationResult.invalid('Missing or invalid exportedAt timestamp.');
    }

    DateTime? exportedAt;
    try {
      exportedAt = DateTime.parse(root['exportedAt'] as String);
    } catch (_) {
      return const BackupValidationResult.invalid('Invalid date format for exportedAt.');
    }

    // Check settings
    if (!root.containsKey('settings') || root['settings'] is! Map) {
      return const BackupValidationResult.invalid('Missing or invalid settings block in backup.');
    }
    final settingsMap = Map<String, dynamic>.from(root['settings'] as Map);

    // Check habits
    if (!root.containsKey('habits') || root['habits'] is! List) {
      return const BackupValidationResult.invalid('Missing or invalid habits list in backup.');
    }

    final rawHabits = root['habits'] as List;
    final List<Habit> parsedHabits = [];
    int totalLoggedDays = 0;

    for (int i = 0; i < rawHabits.length; i++) {
      final item = rawHabits[i];
      if (item is! Map) {
        return BackupValidationResult.invalid('Habit at index $i is not a valid object.');
      }

      final habitMap = Map<String, dynamic>.from(item);

      // Validate required habit fields
      if (!habitMap.containsKey('id') || habitMap['id'] is! String || (habitMap['id'] as String).isEmpty) {
        return BackupValidationResult.invalid('Habit at index $i is missing a valid id.');
      }
      if (!habitMap.containsKey('name') || habitMap['name'] is! String) {
        return BackupValidationResult.invalid('Habit at index $i is missing a valid name.');
      }
      if (!habitMap.containsKey('iconKey') || habitMap['iconKey'] is! String) {
        return BackupValidationResult.invalid('Habit at index $i is missing an iconKey.');
      }
      if (!habitMap.containsKey('colorValue') || habitMap['colorValue'] is! int) {
        return BackupValidationResult.invalid('Habit at index $i is missing a colorValue.');
      }
      if (!habitMap.containsKey('createdAt') || habitMap['createdAt'] is! String) {
        return BackupValidationResult.invalid('Habit at index $i is missing a createdAt timestamp.');
      }

      try {
        final habit = Habit.fromJson(habitMap);
        parsedHabits.add(habit);
        totalLoggedDays += habit.completionHistory.length;
      } catch (e) {
        return BackupValidationResult.invalid('Failed to parse habit at index $i: $e');
      }
    }

    return BackupValidationResult.valid(
      habitCount: parsedHabits.length,
      totalLoggedDays: totalLoggedDays,
      exportedAt: exportedAt,
      parsedSettings: settingsMap,
      parsedHabits: parsedHabits,
    );
  }

  /// Restores a validated backup atomically.
  /// If validation fails, leaves existing data completely untouched and returns failure.
  Future<BackupRestoreResult> restoreBackup(
    String rawJson, {
    required HabitRepository habitRepository,
    required SettingsService settingsService,
  }) async {
    final validation = validateBackupJson(rawJson);
    if (!validation.isValid) {
      return BackupRestoreResult.failure(validation.error ?? 'Validation failed.');
    }

    try {
      // 1. Restore settings
      if (validation.parsedSettings != null) {
        await settingsService.restoreFromJson(validation.parsedSettings!);
      }

      // 2. Atomically replace habits
      if (validation.parsedHabits != null) {
        await habitRepository.replaceHabits(validation.parsedHabits!);
      }

      return BackupRestoreResult.success(validation.habitCount);
    } catch (e) {
      return BackupRestoreResult.failure('Failed to apply restored data: $e');
    }
  }
}
