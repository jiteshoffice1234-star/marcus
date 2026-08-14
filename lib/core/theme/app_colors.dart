import 'package:flutter/material.dart';

/// Design-system colors — "The Ledger" direction.
///
/// The palette is taken from the accountant's own world: cool green-tinted
/// ledger paper, green-black ink, deep ledger green bindings, the classic
/// red ink used to mark corrections (reserved for mistakes/errors), and
/// brass for seals and stamps (streaks, achievements). Money figures are
/// always typeset in Plex Mono so every number reads like a line in a
/// day book. Semantic tokens are referenced by the theme so surfaces never
/// hard-code raw hex values.
class AppColors {
  AppColors._();

  // Brand — ledger green
  static const Color green900 = Color(0xFF14301F);
  static const Color green800 = Color(0xFF1C4130);
  static const Color green700 = Color(0xFF255641);
  static const Color green600 = Color(0xFF2E6B4E);
  static const Color green500 = Color(0xFF3E8E63);
  static const Color green400 = Color(0xFF5FA87E);
  static const Color green300 = Color(0xFF8CC3A4);
  static const Color green200 = Color(0xFFBBDCC8);
  static const Color green100 = Color(0xFFDEEEE4);

  // Semantic accents
  /// Success / progress — a settled, verified green.
  static const Color emerald = Color(0xFF3E8E63);
  static const Color emeraldDark = Color(0xFF255641);

  /// Streaks / achievements — brass seal.
  static const Color amber = Color(0xFFA87B2F);

  /// Mistakes / errors — the accountant's red correction ink.
  static const Color coral = Color(0xFFC0452F);

  /// Informational accent — slate blue.
  static const Color sky = Color(0xFF4E7A8C);

  /// Secondary accent — ink violet.
  static const Color violet = Color(0xFF6B5B8C);

  // Neutral surfaces (light) — cool ledger paper + ink
  static const Color surfaceLight = Color(0xFFF3F6F2);
  static const Color cardLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1B2B23);
  static const Color textSecondaryLight = Color(0xFF5C6F65);
  static const Color textTertiaryLight = Color(0xFF83948B);
  static const Color dividerLight = Color(0xFFDDE5DF);

  // Neutral surfaces (dark) — ink on dark paper
  static const Color surfaceDark = Color(0xFF0E1512);
  static const Color cardDark = Color(0xFF151D18);
  static const Color cardDarkElevated = Color(0xFF1B2620);
  static const Color textPrimaryDark = Color(0xFFE6EEE8);
  static const Color textSecondaryDark = Color(0xFFA9BCB0);
  static const Color textTertiaryDark = Color(0xFF7C8F84);
  static const Color dividerDark = Color(0xFF24312A);

  // Difficulty accents — the scale rises from calm green to red ink,
  // so the hardest material is marked with the correction ink.
  static const Color diffBeginner = Color(0xFF3E8E63);
  static const Color diffEasy = Color(0xFF4E7A8C);
  static const Color diffIntermediate = Color(0xFFA87B2F);
  static const Color diffAdvanced = Color(0xFF6B5B8C);
  static const Color diffCaFinal = Color(0xFFC0452F);
}
