import 'package:flutter/material.dart';

/// A single selectable accent color, shown in the (future) color picker.
class HabitColorOption {
  final String name;
  final Color color;
  const HabitColorOption(this.name, this.color);
}

class AppColors {
  AppColors._();

  // ---- Core background / surface system (black stays dominant) ----
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0D0D);
  static const Color surfaceElevated = Color(0xFF161616);
  static const Color surfaceHigh = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF262626);
  static const Color borderSubtle = Color(0xFF1A1A1A);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textTertiary = Color(0xFF6B6B6B);

  // ---- Curated habit accent palette (muted, not neon) ----
  static const Color aqua = Color(0xFF5FD8C9);
  static const Color deepAqua = Color(0xFF2E8C82);
  static const Color oceanBlue = Color(0xFF3E7CB1);
  static const Color midnightBlue = Color(0xFF2C3E63);
  static const Color lightBlue = Color(0xFF8FC1E3);
  static const Color lavender = Color(0xFFB6A6D9);
  static const Color deepPurple = Color(0xFF5B4B8A);
  static const Color violet = Color(0xFF7C5CBF);
  static const Color sageGreen = Color(0xFF8FA985);
  static const Color emerald = Color(0xFF3F9E72);
  static const Color softPink = Color(0xFFD9A6B3);
  static const Color rose = Color(0xFFC26B7D);
  static const Color coral = Color(0xFFD98266);
  static const Color orange = Color(0xFFD98F4E);
  static const Color brown = Color(0xFF8A6A50);
  static const Color maroon = Color(0xFF7A3B42);
  static const Color burgundy = Color(0xFF5C2331);

  /// Every habit accent color, ready to feed a color picker. Add a new
  /// entry here to make a color selectable everywhere in the app.
  static const List<HabitColorOption> habitPalette = [
    HabitColorOption('Aqua', aqua),
    HabitColorOption('Deep Aqua', deepAqua),
    HabitColorOption('Ocean Blue', oceanBlue),
    HabitColorOption('Midnight Blue', midnightBlue),
    HabitColorOption('Light Blue', lightBlue),
    HabitColorOption('Lavender', lavender),
    HabitColorOption('Deep Purple', deepPurple),
    HabitColorOption('Violet', violet),
    HabitColorOption('Sage Green', sageGreen),
    HabitColorOption('Emerald', emerald),
    HabitColorOption('Soft Pink', softPink),
    HabitColorOption('Rose', rose),
    HabitColorOption('Coral', coral),
    HabitColorOption('Orange', orange),
    HabitColorOption('Brown', brown),
    HabitColorOption('Maroon', maroon),
    HabitColorOption('Burgundy', burgundy),
  ];

  /// Blends a habit's accent color into a near-black surface based on
  /// [intensity] (0.0 = empty block, 1.0 = strongest). Powers every
  /// activity block in the app.
  static Color intensity(Color base, double intensity) {
    if (intensity <= 0) return surfaceElevated;
    final clamped = intensity.clamp(0.15, 1.0);
    return Color.lerp(surfaceElevated, base, clamped) ?? base;
  }
}
