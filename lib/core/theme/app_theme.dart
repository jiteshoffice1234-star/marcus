import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app's [ThemeData] for light and dark mode.
///
/// The design goal: premium, minimal, high readability, strong hierarchy —
/// suitable for serious accounting students, not a playful consumer app.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light).copyWith(
        scaffoldBackgroundColor: AppColors.surfaceLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.indigo600,
          onPrimary: Colors.white,
          secondary: AppColors.emerald,
          onSecondary: Colors.white,
          surface: AppColors.cardLight,
          onSurface: AppColors.textPrimaryLight,
          error: AppColors.coral,
          onError: Colors.white,
          outline: AppColors.dividerLight,
        ),
        cardColor: AppColors.cardLight,
        dividerColor: AppColors.dividerLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: AppTypography.title,
        ),
        textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.cardLight,
          indicatorColor: AppColors.indigo100,
          labelTextStyle: WidgetStatePropertyAll(
            AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.indigo600
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      );

  static ThemeData dark() => _base(Brightness.dark).copyWith(
        scaffoldBackgroundColor: AppColors.surfaceDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.indigo400,
          onPrimary: AppColors.indigo900,
          secondary: AppColors.emerald,
          onSecondary: AppColors.surfaceDark,
          surface: AppColors.cardDark,
          onSurface: AppColors.textPrimaryDark,
          error: AppColors.coral,
          onError: Colors.white,
          outline: AppColors.dividerDark,
        ),
        cardColor: AppColors.cardDark,
        dividerColor: AppColors.dividerDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: AppTypography.title,
        ),
        textTheme: _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.cardDark,
          indicatorColor: AppColors.indigo800,
          labelTextStyle: WidgetStatePropertyAll(
            AppTypography.caption.copyWith(color: AppColors.textSecondaryDark),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.indigo400
                  : AppColors.textTertiaryDark,
            ),
          ),
        ),
      );

  static ThemeData _base(Brightness brightness) {
    final scheme = brightness == Brightness.dark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const ['Roboto', 'Helvetica', 'Arial'],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          textStyle: AppTypography.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          textStyle: AppTypography.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppTypography.label),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? AppColors.cardDarkElevated
            : AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
            color: brightness == Brightness.dark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
            color: brightness == Brightness.dark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.indigo500, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark ? AppColors.cardDark : AppColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: brightness == Brightness.dark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.dark
            ? AppColors.cardDarkElevated
            : AppColors.indigo100.withValues(alpha: 0.5),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
        labelStyle: AppTypography.caption.copyWith(
          color: brightness == Brightness.dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.indigo500,
        linearTrackColor: brightness == Brightness.dark
            ? AppColors.cardDarkElevated
            : AppColors.indigo100,
      ),
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.dark ? AppColors.dividerDark : AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? AppColors.cardDarkElevated : AppColors.indigo900,
        contentTextStyle: AppTypography.bodySmall.copyWith(color: Colors.white),
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: primary),
        displayMedium: AppTypography.displayMedium.copyWith(color: primary),
        headlineMedium: AppTypography.headline.copyWith(color: primary),
        titleLarge: AppTypography.title.copyWith(color: primary),
        titleMedium: AppTypography.subtitle.copyWith(color: primary),
        bodyLarge: AppTypography.body.copyWith(color: primary),
        bodyMedium: AppTypography.bodySmall.copyWith(color: secondary),
        labelLarge: AppTypography.label.copyWith(color: primary),
      );
}
