import 'package:flutter/material.dart';

/// Design-system colors for a premium academic + finance interface.
///
/// Palette: deep indigo (trust/finance), emerald (growth/progress),
/// amber (streaks/energy), coral (errors/attention). Semantic tokens are
/// referenced by the theme so surfaces never hard-code raw hex values.
class AppColors {
  AppColors._();

  // Brand
  static const Color indigo900 = Color(0xFF1A2245);
  static const Color indigo800 = Color(0xFF232C5B);
  static const Color indigo700 = Color(0xFF2D3A7A);
  static const Color indigo600 = Color(0xFF3D4E9E);
  static const Color indigo500 = Color(0xFF4C5FC0);
  static const Color indigo400 = Color(0xFF6F7FD4);
  static const Color indigo300 = Color(0xFF9AA6E4);
  static const Color indigo200 = Color(0xFFC2CAF0);
  static const Color indigo100 = Color(0xFFE1E5F8);

  // Semantic accents
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF0E9F6E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color coral = Color(0xFFEF4444);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color violet = Color(0xFF8B5CF6);

  // Neutral surfaces (light)
  static const Color surfaceLight = Color(0xFFF7F8FC);
  static const Color cardLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF141A2E);
  static const Color textSecondaryLight = Color(0xFF5A6480);
  static const Color textTertiaryLight = Color(0xFF8A93AC);
  static const Color dividerLight = Color(0xFFE6E9F2);

  // Neutral surfaces (dark)
  static const Color surfaceDark = Color(0xFF0E1226);
  static const Color cardDark = Color(0xFF171D38);
  static const Color cardDarkElevated = Color(0xFF1E2547);
  static const Color textPrimaryDark = Color(0xFFF2F4FF);
  static const Color textSecondaryDark = Color(0xFFB3BCD6);
  static const Color textTertiaryDark = Color(0xFF7C86A6);
  static const Color dividerDark = Color(0xFF2A3157);

  // Difficulty accents (stars → CA Final)
  static const Color diffBeginner = Color(0xFF10B981);
  static const Color diffEasy = Color(0xFF0EA5E9);
  static const Color diffIntermediate = Color(0xFFF59E0B);
  static const Color diffAdvanced = Color(0xFF8B5CF6);
  static const Color diffCaFinal = Color(0xFFEF4444);
}
