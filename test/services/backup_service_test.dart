import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canopy/models/habit.dart';
import 'package:canopy/services/backup_service.dart';
import 'package:canopy/services/habit_repository.dart';
import 'package:canopy/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService & Settings Persistence Tests', () {
    late BackupService backupService;
    late HabitRepository habitRepository;
    late SettingsService settingsService;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fiveDaysAgo = today.subtract(const Duration(days: 5));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backupService = BackupService();
      settingsService = SettingsService();
      await settingsService.init();

      habitRepository = HabitRepository();
      // Load sample habits
      await habitRepository.load();
    });

    test('1. Valid backup generation includes schemaVersion, appVersion, exportedAt, settings, and habits', () {
      final jsonString = backupService.createBackupJson(
        habits: habitRepository.habits,
        settings: settingsService,
      );

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], equals(1));
      expect(decoded['appVersion'], isNotEmpty);
      expect(decoded['exportedAt'], isNotNull);
      expect(decoded['settings'], isA<Map<String, dynamic>>());
      expect(decoded['habits'], isA<List>());
      expect((decoded['habits'] as List).length, equals(habitRepository.habits.length));
    });

    test('2. Settings are properly included in generated backup', () async {
      await settingsService.setUserName('Jane Doe');
      await settingsService.setEveningCheckinTime('21:45');
      await settingsService.setHapticsEnabled(false);
      await settingsService.setRemindersEnabled(true);
      await settingsService.setMissedHabitAlertsEnabled(true);

      final jsonString = backupService.createBackupJson(
        habits: habitRepository.habits,
        settings: settingsService,
      );

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final settingsJson = decoded['settings'] as Map<String, dynamic>;

      expect(settingsJson['userName'], equals('Jane Doe'));
      expect(settingsJson['eveningCheckinTime'], equals('21:45'));
      expect(settingsJson['hapticsEnabled'], isFalse);
      expect(settingsJson['remindersEnabled'], isTrue);
      expect(settingsJson['missedHabitAlertsEnabled'], isTrue);
    });

    test('3. All habit fields and full completion history are preserved in backup', () async {
      final customHabit = Habit(
        id: 'backup-habit-1',
        name: 'Deep Reading',
        iconKey: 'book',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        goalType: GoalType.duration,
        targetValue: 45.0,
        targetUnit: 'min',
        frequencyType: FrequencyType.specificDays,
        selectedDays: [1, 3, 5],
        reminderEnabled: true,
        reminderTimes: ['08:00', '20:00'],
        createdAt: fiveDaysAgo,
        completionHistory: [
          CompletionEntry(
            date: fiveDaysAgo,
            progressValue: 45.0,
            completed: true,
          ),
          CompletionEntry(
            date: today.subtract(const Duration(days: 2)),
            progressValue: 30.0,
            completed: false,
          ),
        ],
      );

      await habitRepository.replaceHabits([customHabit]);

      final jsonString = backupService.createBackupJson(
        habits: habitRepository.habits,
        settings: settingsService,
      );

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final habitsList = decoded['habits'] as List;
      expect(habitsList.length, equals(1));

      final habitMap = habitsList.first as Map<String, dynamic>;
      expect(habitMap['id'], equals('backup-habit-1'));
      expect(habitMap['name'], equals('Deep Reading'));
      expect(habitMap['goalType'], equals('duration'));
      expect(habitMap['targetValue'], equals(45.0));
      expect(habitMap['targetUnit'], equals('min'));
      expect(habitMap['frequencyType'], equals('specificDays'));
      expect(habitMap['selectedDays'], equals([1, 3, 5]));
      expect(habitMap['reminderEnabled'], isTrue);
      expect(habitMap['reminderTimes'], equals(['08:00', '20:00']));

      final historyList = habitMap['completionHistory'] as List;
      expect(historyList.length, equals(2));
    });

    test('4. Valid backup restoration successfully restores habits and settings', () async {
      final newHabit = Habit(
        id: 'restored-habit-1',
        name: 'Morning Walk',
        iconKey: 'directions_walk',
        colorValue: 0xFF5FD8C9,
        fontFamilyKey: 'modernSans',
        createdAt: fiveDaysAgo,
        completionHistory: [
          CompletionEntry(
            date: today,
            progressValue: 1.0,
            completed: true,
          ),
        ],
      );

      await settingsService.setUserName('Original User');
      await settingsService.setEveningCheckinTime('20:00');

      final backupJson = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'appVersion': '1.0.0',
        'settings': {
          'userName': 'Restored User',
          'eveningCheckinTime': '22:15',
          'remindersEnabled': true,
          'missedHabitAlertsEnabled': true,
          'animationsEnabled': true,
          'hapticsEnabled': false,
        },
        'habits': [newHabit.toJson()],
      });

      final result = await backupService.restoreBackup(
        backupJson,
        habitRepository: habitRepository,
        settingsService: settingsService,
      );

      expect(result.isSuccess, isTrue);
      expect(result.restoredHabitCount, equals(1));
      expect(habitRepository.habits.length, equals(1));
      expect(habitRepository.habits.first.id, equals('restored-habit-1'));
      expect(habitRepository.habits.first.name, equals('Morning Walk'));
      expect(habitRepository.habits.first.isCompletedOn(today), isTrue);

      expect(settingsService.userName, equals('Restored User'));
      expect(settingsService.eveningCheckinTime, equals('22:15'));
      expect(settingsService.hapticsEnabled, isFalse);
    });

    test('5. Rejects malformed JSON cleanly without throwing unhandled exceptions', () async {
      const malformedJson = '{ "schemaVersion": 1, "settings": ... bad json }';

      final validation = backupService.validateBackupJson(malformedJson);
      expect(validation.isValid, isFalse);
      expect(validation.error, contains('Malformed JSON format'));

      final restoreResult = await backupService.restoreBackup(
        malformedJson,
        habitRepository: habitRepository,
        settingsService: settingsService,
      );
      expect(restoreResult.isSuccess, isFalse);
      expect(restoreResult.message, contains('Malformed JSON format'));
    });

    test('6. Rejects backups missing required root fields', () async {
      // Missing habits list
      final missingHabits = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {},
      });

      final val1 = backupService.validateBackupJson(missingHabits);
      expect(val1.isValid, isFalse);
      expect(val1.error, contains('Missing or invalid habits list'));

      // Missing settings
      final missingSettings = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'habits': [],
      });

      final val2 = backupService.validateBackupJson(missingSettings);
      expect(val2.isValid, isFalse);
      expect(val2.error, contains('Missing or invalid settings block'));

      // Missing exportedAt
      final missingExportedAt = jsonEncode({
        'schemaVersion': 1,
        'settings': {},
        'habits': [],
      });

      final val3 = backupService.validateBackupJson(missingExportedAt);
      expect(val3.isValid, isFalse);
      expect(val3.error, contains('Missing or invalid exportedAt'));
    });

    test('7. Rejects unsupported schemaVersion cleanly', () async {
      final unsupportedSchema = jsonEncode({
        'schemaVersion': 999,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {},
        'habits': [],
      });

      final validation = backupService.validateBackupJson(unsupportedSchema);
      expect(validation.isValid, isFalse);
      expect(validation.error, contains('Unsupported schemaVersion (999)'));
    });

    test('8. Rejects corrupted habit data cleanly', () async {
      final corruptedHabitJson = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {},
        'habits': [
          {
            'name': 'Corrupted Habit (Missing ID)',
            'iconKey': 'star',
            'colorValue': 0xFF123456,
            'createdAt': DateTime.now().toIso8601String(),
          }
        ],
      });

      final validation = backupService.validateBackupJson(corruptedHabitJson);
      expect(validation.isValid, isFalse);
      expect(validation.error, contains('missing a valid id'));
    });

    test('9. Failed import leaves existing habits and settings completely unchanged', () async {
      final initialHabitCount = habitRepository.habits.length;
      final initialUserName = settingsService.userName;
      final initialCheckinTime = settingsService.eveningCheckinTime;

      final invalidBackupJson = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {
          'userName': 'Should Not Change',
        },
        'habits': [
          {
            'id': 'bad-1',
            // Missing name, iconKey, etc.
          }
        ],
      });

      final restoreResult = await backupService.restoreBackup(
        invalidBackupJson,
        habitRepository: habitRepository,
        settingsService: settingsService,
      );

      expect(restoreResult.isSuccess, isFalse);
      // Verify in-memory state is identical
      expect(habitRepository.habits.length, equals(initialHabitCount));
      expect(settingsService.userName, equals(initialUserName));
      expect(settingsService.eveningCheckinTime, equals(initialCheckinTime));
    });

    test('10. SettingsService persistence: userName, hapticsEnabled, eveningCheckinTime persist across restarts', () async {
      await settingsService.setUserName('Alice Smith');
      await settingsService.setHapticsEnabled(false);
      await settingsService.setEveningCheckinTime('19:45');
      await settingsService.setAnimationsEnabled(false);
      await settingsService.setRemindersEnabled(true);
      await settingsService.setMissedHabitAlertsEnabled(true);

      // Create a fresh instance and initialize from SharedPreferences
      final reloadedSettings = SettingsService();
      await reloadedSettings.init();

      expect(reloadedSettings.userName, equals('Alice Smith'));
      expect(reloadedSettings.hapticsEnabled, isFalse);
      expect(reloadedSettings.eveningCheckinTime, equals('19:45'));
      expect(reloadedSettings.animationsEnabled, isFalse);
      expect(reloadedSettings.remindersEnabled, isTrue);
      expect(reloadedSettings.missedHabitAlertsEnabled, isTrue);
    });

    test('11. HabitRepository.replaceHabits() replaces all habits and saves to storage', () async {
      final replacementHabits = [
        Habit(
          id: 'solo-habit',
          name: 'Solo Habit',
          iconKey: 'check',
          colorValue: 0xFF5FD8C9,
          fontFamilyKey: 'modernSans',
        ),
      ];

      await habitRepository.replaceHabits(replacementHabits);
      expect(habitRepository.habits.length, equals(1));
      expect(habitRepository.habits.first.id, equals('solo-habit'));

      // Reloading from storage verifies persistence
      await habitRepository.load();
      expect(habitRepository.habits.length, equals(1));
      expect(habitRepository.habits.first.id, equals('solo-habit'));
    });
  });
}
