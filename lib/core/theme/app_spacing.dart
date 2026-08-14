/// Consistent spacing scale and layout constants.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Tighter, squared radii — the precise feel of an accounting instrument.
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  /// Max content width for tablet/desktop layouts.
  static const double contentMaxWidth = 920;

  /// Width beyond which we switch from phone to tablet layout.
  static const double tabletBreakpoint = 760;
}
