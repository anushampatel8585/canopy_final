import 'package:flutter/material.dart';

class IconOption {
  final String key;
  final IconData icon;
  final String label;
  const IconOption(this.key, this.icon, this.label);
}

/// Central, extensible icon catalog, grouped for the (future) icon picker.
/// Add an entry to any category below to make a new icon selectable
/// everywhere in the app — habits reference icons by their string [key],
/// never by IconData directly, so this stays swappable and serializable.
class IconRegistry {
  IconRegistry._();

  static const Map<String, List<IconOption>> categories = {
    'Health': [
      IconOption('water', Icons.water_drop_rounded, 'Water'),
      IconOption('heart', Icons.favorite_rounded, 'Heart'),
      IconOption('running', Icons.directions_run_rounded, 'Running'),
      IconOption('walking', Icons.directions_walk_rounded, 'Walking'),
      IconOption('gym', Icons.fitness_center_rounded, 'Gym'),
      IconOption('food', Icons.restaurant_rounded, 'Food'),
      IconOption('sleep', Icons.bedtime_rounded, 'Sleep'),
      IconOption('meditation', Icons.self_improvement_rounded, 'Meditation'),
    ],
    'Study / Work': [
      IconOption('book', Icons.menu_book_rounded, 'Book'),
      IconOption('reading', Icons.auto_stories_rounded, 'Reading'),
      IconOption('coding', Icons.code_rounded, 'Coding'),
      IconOption('laptop', Icons.laptop_mac_rounded, 'Laptop'),
      IconOption('writing', Icons.edit_note_rounded, 'Writing'),
      IconOption('education', Icons.school_rounded, 'Education'),
      IconOption('math', Icons.functions_rounded, 'Mathematics'),
    ],
    'Lifestyle': [
      IconOption('morning', Icons.wb_twilight_rounded, 'Morning'),
      IconOption('night', Icons.nightlight_round, 'Night'),
      IconOption('cleaning', Icons.cleaning_services_rounded, 'Cleaning'),
      IconOption('music', Icons.music_note_rounded, 'Music'),
      IconOption('journaling', Icons.book_rounded, 'Journaling'),
      IconOption('travel', Icons.flight_takeoff_rounded, 'Travel'),
      IconOption('selfcare', Icons.spa_rounded, 'Self-care'),
    ],
    'General': [
      IconOption('star', Icons.star_rounded, 'Star'),
      IconOption('target', Icons.track_changes_rounded, 'Target'),
      IconOption('fire', Icons.local_fire_department_rounded, 'Fire'),
      IconOption('trophy', Icons.emoji_events_rounded, 'Trophy'),
      IconOption('lightning', Icons.bolt_rounded, 'Lightning'),
      IconOption('brain', Icons.psychology_rounded, 'Brain'),
      IconOption('calendar', Icons.calendar_month_rounded, 'Calendar'),
      IconOption('clock', Icons.access_time_rounded, 'Clock'),
      IconOption('check', Icons.check_circle_rounded, 'Check'),
      IconOption('goal', Icons.flag_rounded, 'Goal'),
    ],
  };

  static IconData iconFor(String key) {
    for (final list in categories.values) {
      for (final option in list) {
        if (option.key == key) return option.icon;
      }
    }
    return Icons.circle_rounded;
  }

  static String labelFor(String key) {
    for (final list in categories.values) {
      for (final option in list) {
        if (option.key == key) return option.label;
      }
    }
    return 'Habit';
  }
}
