import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppFontFamily {
  modernSans,
  cleanSans,
  rounded,
  elegant,
  serif,
  mono,
  bold,
  handwritten,
}

class AppFontOption {
  final AppFontFamily family;
  final String label;
  final TextStyle Function({FontWeight? fontWeight, FontStyle? fontStyle}) builder;

  const AppFontOption({
    required this.family,
    required this.label,
    required this.builder,
  });
}

/// Central, extensible font registry. To add a new font later: add one
/// entry here (pick any family from google_fonts) — every screen that
/// uses AppFonts.style() picks it up automatically, no other file changes.
class AppFonts {
  AppFonts._();

  static final Map<AppFontFamily, AppFontOption> registry = {
    AppFontFamily.modernSans: AppFontOption(
      family: AppFontFamily.modernSans,
      label: 'Inter',
      builder: ({fontWeight, fontStyle}) =>
          GoogleFonts.inter(fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.cleanSans: AppFontOption(
      family: AppFontFamily.cleanSans,
      label: 'Space Grotesk',
      builder: ({fontWeight, fontStyle}) =>
          GoogleFonts.spaceGrotesk(fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.rounded: AppFontOption(
      family: AppFontFamily.rounded,
      label: 'Condensed',
      builder: ({fontWeight, fontStyle}) =>
          GoogleFonts.robotoCondensed(fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.elegant: AppFontOption(
      family: AppFontFamily.elegant,
      label: 'Elegant',
      builder: ({fontWeight, fontStyle}) => GoogleFonts.cormorantGaramond(
          fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.serif: AppFontOption(
      family: AppFontFamily.serif,
      label: 'Serif',
      builder: ({fontWeight, fontStyle}) =>
          GoogleFonts.ptSerif(fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.mono: AppFontOption(
      family: AppFontFamily.mono,
      label: 'Mono',
      builder: ({fontWeight, fontStyle}) => GoogleFonts.jetBrainsMono(
          fontWeight: fontWeight, fontStyle: fontStyle),
    ),
    AppFontFamily.bold: AppFontOption(
      family: AppFontFamily.bold,
      label: 'Bold',
      builder: ({fontWeight, fontStyle}) => GoogleFonts.poppins(
          fontWeight: fontWeight ?? FontWeight.w700, fontStyle: fontStyle),
    ),
    AppFontFamily.handwritten: AppFontOption(
      family: AppFontFamily.handwritten,
      label: 'Soft / Handwritten',
      builder: ({fontWeight, fontStyle}) =>
          GoogleFonts.caveat(fontWeight: fontWeight, fontStyle: fontStyle),
    ),
  };

  static TextStyle style(
    AppFontFamily family, {
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? fontSize,
    Color? color,
  }) {
    final option = registry[family] ?? registry[AppFontFamily.modernSans]!;
    return option
        .builder(fontWeight: fontWeight, fontStyle: fontStyle)
        .copyWith(fontSize: fontSize, color: color);
  }

  static String labelFor(AppFontFamily family) =>
      registry[family]?.label ?? 'Inter';
}
