import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.aqua,
        secondary: AppColors.violet,
        error: AppColors.rose,
        onSurface: AppColors.textPrimary,
      ),
      canvasColor: AppColors.background,
      splashColor: Colors.white.withOpacity(0.03),
      highlightColor: Colors.white.withOpacity(0.02),
      dividerColor: AppColors.border,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
        ),
        titleTextStyle: AppFonts.style(
          AppFontFamily.modernSans,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.aqua.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return AppFonts.style(
            AppFontFamily.cleanSans,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: selected ? AppColors.aqua : AppColors.textTertiary,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.aqua,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.aqua,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? AppColors.aqua
              : AppColors.textTertiary,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? AppColors.aqua.withOpacity(0.35)
              : AppColors.surfaceHigh,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displaySmall: AppFonts.style(AppFontFamily.modernSans,
          fontWeight: FontWeight.w700, fontSize: 32, color: AppColors.textPrimary),
      headlineSmall: AppFonts.style(AppFontFamily.modernSans,
          fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.textPrimary),
      titleLarge: AppFonts.style(AppFontFamily.modernSans,
          fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary),
      titleMedium: AppFonts.style(AppFontFamily.cleanSans,
          fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
      bodyLarge: AppFonts.style(AppFontFamily.cleanSans,
          fontWeight: FontWeight.w400, fontSize: 15, color: AppColors.textPrimary),
      bodyMedium: AppFonts.style(AppFontFamily.cleanSans,
          fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.textSecondary),
      bodySmall: AppFonts.style(AppFontFamily.cleanSans,
          fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.textTertiary),
      labelLarge: AppFonts.style(AppFontFamily.cleanSans,
          fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
    );
  }
}
