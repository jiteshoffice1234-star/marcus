import 'package:flutter/material.dart';

/// Typography scale — the IBM Plex family, the ledger direction.
///
/// Three roles, one family DNA:
///  * [kSerif] — display. Used with restraint: the wordmark, big headings,
///    results, the moments that should carry gravitas.
///  * [kSans] — the working UI voice: labels, body, controls.
///  * [kMono] — figures. Every money amount, number, timer and statement
///    line is set in Plex Mono so figures align like a day-book column.
///
/// All styles use only declared font weights (400/500/600/700).
class AppTypography {
  AppTypography._();

  /// Registered font families (see pubspec.yaml).
  static const String kSans = 'PlexSans';
  static const String kSerif = 'PlexSerif';
  static const String kMono = 'PlexMono';

  // Display — Plex Serif, used sparingly.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: kSerif,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: -0.4,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: kSerif,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: kSerif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.28,
  );

  // UI — Plex Sans.
  static const TextStyle title = TextStyle(
    fontFamily: kSans,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: kSans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.2,
  );

  /// Stamped column heads — mono overline, like the DR/CR heads of a ledger.
  static const TextStyle overline = TextStyle(
    fontFamily: kMono,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: kSans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Large figures (dashboards, results) — Plex Mono, inherently tabular.
  static const TextStyle number = TextStyle(
    fontFamily: kMono,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Inline figures (money, ratios, timers) — the ledger column voice.
  static const TextStyle figures = TextStyle(
    fontFamily: kMono,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
