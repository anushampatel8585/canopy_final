import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canopy/models/habit.dart';
import 'package:canopy/services/notification_service.dart';
import 'package:canopy/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService - ID Generation', () {
    test('generateNotificationId generates valid positive 32-bit integers', () {
      const habitId = 'test-habit-123';
      const timeString = '08:30';

      final id = NotificationService.generateNotificationId(habitId, timeString, 0);

      expect(id, isNonNegative);
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('generateNotificationId is deterministic', () {
      const habitId = 'habit-abc';
      const time = '14:15';

      final id1 = NotificationService.generateNotificationId(habitId, time, 1);
      final id2 = NotificationService.generateNotificationId(habitId, time, 1);

      expect(id1, equals(id2));
    });

    test('different times and weekdays produce distinct notification IDs', () {
      const habitId = 'habit-xyz';

      final idMorning = NotificationService.generateNotificationId(habitId, '08:00', 0);
      final idEvening = NotificationService.generateNotificationId(habitId, '20:00', 0);
      final idMonday = NotificationService.generateNotificationId(habitId, '08:00', 1);
      final idTuesday = NotificationService.generateNotificationId(habitId, '08:00', 2);

      final idSet = {idMorning, idEvening, idMonday, idTuesday};
      expect(idSet.length, equals(4));
    });
  });

  group('SettingsService - Persistence & Defaults', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default values properly', () async {
      final settings = SettingsService();
      await settings.init();

      expect(settings.remindersEnabled, isFalse);
      expect(settings.missedHabitAlertsEnabled, isFalse);
      expect(settings.eveningCheckinTime, equals('20:30'));
      expect(settings.animationsEnabled, isTrue);
    });

    test('persists and updates settings properly', () async {
      final settings = SettingsService();
      await settings.init();

      await settings.setRemindersEnabled(true);
      expect(settings.remindersEnabled, isTrue);

      await settings.setMissedHabitAlertsEnabled(true);
      expect(settings.missedHabitAlertsEnabled, isTrue);

      await settings.setEveningCheckinTime('21:00');
      expect(settings.eveningCheckinTime, equals('21:00'));

      await settings.setAnimationsEnabled(false);
      expect(settings.animationsEnabled, isFalse);
    });
  });

  group('Habit Model - Reminder Serialization', () {
    test('Habit properly serializes and deserializes reminder fields', () {
      final habit = Habit(
        id: 'h1',
        name: 'Meditation',
        iconKey: 'meditation',
        colorValue: 0xFF4AE3B5,
        fontFamilyKey: 'cleanSans',
        reminderEnabled: true,
        reminderTimes: ['07:00', '21:30'],
        frequencyType: FrequencyType.specificDays,
        selectedDays: [1, 3, 5],
      );

      final json = habit.toJson();
      expect(json['reminderEnabled'], isTrue);
      expect(json['reminderTimes'], equals(['07:00', '21:30']));
      expect(json['selectedDays'], equals([1, 3, 5]));

      final restored = Habit.fromJson(json);
      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderTimes, equals(['07:00', '21:30']));
      expect(restored.selectedDays, equals([1, 3, 5]));
    });
  });
}
