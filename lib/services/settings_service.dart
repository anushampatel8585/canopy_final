import 'package:shared_preferences/shared_preferences.dart';

/// Manages local user preferences and global notification toggles.
class SettingsService {
  static const String _keyUserName = 'canopy_setting_user_name';
  static const String _keyRemindersEnabled = 'canopy_setting_reminders_enabled';
  static const String _keyMissedAlertsEnabled = 'canopy_setting_missed_alerts_enabled';
  static const String _keyEveningCheckinTime = 'canopy_setting_evening_checkin_time';
  static const String _keyAnimationsEnabled = 'canopy_setting_animations_enabled';
  static const String _keyHapticsEnabled = 'canopy_setting_haptics_enabled';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  String _userName = 'CANOPY User';
  bool _remindersEnabled = false;
  bool _missedHabitAlertsEnabled = false;
  String _eveningCheckinTime = '20:30'; // 8:30 PM default
  bool _animationsEnabled = true;
  bool _hapticsEnabled = true;

  String get userName => _userName;
  bool get remindersEnabled => _remindersEnabled;
  bool get missedHabitAlertsEnabled => _missedHabitAlertsEnabled;
  String get eveningCheckinTime => _eveningCheckinTime;
  bool get animationsEnabled => _animationsEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  /// Loads all settings from SharedPreferences into memory.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_keyUserName) ?? 'CANOPY User';
    _remindersEnabled = prefs.getBool(_keyRemindersEnabled) ?? false;
    _missedHabitAlertsEnabled = prefs.getBool(_keyMissedAlertsEnabled) ?? false;
    _eveningCheckinTime = prefs.getString(_keyEveningCheckinTime) ?? '20:30';
    _animationsEnabled = prefs.getBool(_keyAnimationsEnabled) ?? true;
    _hapticsEnabled = prefs.getBool(_keyHapticsEnabled) ?? true;
  }

  Future<void> setUserName(String value) async {
    _userName = value.trim().isEmpty ? 'CANOPY User' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, _userName);
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersEnabled, value);
  }

  Future<void> setMissedHabitAlertsEnabled(bool value) async {
    _missedHabitAlertsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMissedAlertsEnabled, value);
  }

  Future<void> setEveningCheckinTime(String value) async {
    _eveningCheckinTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEveningCheckinTime, value);
  }

  Future<void> setAnimationsEnabled(bool value) async {
    _animationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnimationsEnabled, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHapticsEnabled, value);
  }

  Map<String, dynamic> toJson() => {
        'userName': _userName,
        'remindersEnabled': _remindersEnabled,
        'missedHabitAlertsEnabled': _missedHabitAlertsEnabled,
        'eveningCheckinTime': _eveningCheckinTime,
        'animationsEnabled': _animationsEnabled,
        'hapticsEnabled': _hapticsEnabled,
      };

  Future<void> restoreFromJson(Map<String, dynamic> json) async {
    if (json.containsKey('userName') && json['userName'] is String) {
      await setUserName(json['userName'] as String);
    }
    if (json.containsKey('remindersEnabled') && json['remindersEnabled'] is bool) {
      await setRemindersEnabled(json['remindersEnabled'] as bool);
    }
    if (json.containsKey('missedHabitAlertsEnabled') && json['missedHabitAlertsEnabled'] is bool) {
      await setMissedHabitAlertsEnabled(json['missedHabitAlertsEnabled'] as bool);
    }
    if (json.containsKey('eveningCheckinTime') && json['eveningCheckinTime'] is String) {
      await setEveningCheckinTime(json['eveningCheckinTime'] as String);
    }
    if (json.containsKey('animationsEnabled') && json['animationsEnabled'] is bool) {
      await setAnimationsEnabled(json['animationsEnabled'] as bool);
    }
    if (json.containsKey('hapticsEnabled') && json['hapticsEnabled'] is bool) {
      await setHapticsEnabled(json['hapticsEnabled'] as bool);
    }
  }
}
