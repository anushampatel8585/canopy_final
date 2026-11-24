import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

/// Saves and loads habits from local device storage.
///
/// This is intentionally simple (SharedPreferences + JSON) for the first
/// functional version. loadHabits()/saveHabits() are the ONLY seam the
/// rest of the app talks to — swapping this for Cloud Firestore later
/// means rewriting just this file.
class HabitStorageService {
  static const _habitsKey = 'canopy_habits_v1';

  Future<bool> hasStoredHabits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_habitsKey);
  }

  Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_habitsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((item) => Habit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(habits.map((h) => h.toJson()).toList());
    await prefs.setString(_habitsKey, encoded);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep an explicit empty list so first-launch sample habits are not
    // recreated after the user intentionally resets or deletes all habits.
    await prefs.setString(_habitsKey, '[]');
  }
}
