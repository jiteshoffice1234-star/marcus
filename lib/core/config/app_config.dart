/// Central application configuration.
///
/// # Branding
/// The product name is MARCUS. Everything user-facing that relates to branding
/// is defined here and referenced from this single file — never hard-code a
/// brand name elsewhere. To rebrand:
///
/// 1. Change [AppConfig.appName] (and optionally [AppConfig.tagline]).
/// 2. Update platform launcher names:
///    - android/app/src/main/AndroidManifest.xml (android:label)
///    - ios/Runner/Info.plist (CFBundleDisplayName / CFBundleName)
///    - web/manifest.json + web/index.html (<title>)
/// 3. Replace the icon set in `assets/branding/icon/` (see tool/icon_generator.js).
/// 4. Update the Dart package name in pubspec.yaml + org/applicationId if desired.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Branding (change here)
  // ---------------------------------------------------------------------------
  static const String appName = 'MARCUS';
  static const String tagline = 'From accounting zero to CA Final level';
  static const String shortTagline = 'Learn · Practice · Master';

  /// One-line disclaimer shown in onboarding and the CA Final level.
  static const String qualificationDisclaimer =
      'This app provides accounting education and CA-level learning content. '
      'It is not affiliated with the Institute of Chartered Accountants of India (ICAI) '
      'and does not confer any professional qualification. Official ICAI syllabus and '
      'qualification requirements are separate and must be satisfied through ICAI processes.';

  // ---------------------------------------------------------------------------
  // Backend configuration
  // ---------------------------------------------------------------------------
  // Provided at build/run time via --dart-define. Never commit real keys.
  // When absent, the app runs in fully local demo mode (seeded content, local
  // auth, local persistence) so the product is testable end to end offline.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The AI provider is selected at build time. Never ship provider secrets in
  /// the client — the production implementation must proxy through your server.
  static const String aiProvider = String.fromEnvironment('AI_PROVIDER', defaultValue: 'coach');
  static const String aiEndpoint = String.fromEnvironment('AI_ENDPOINT');
  static const String aiApiKey = String.fromEnvironment('AI_API_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get useRemoteAi =>
      aiProvider != 'coach' && aiEndpoint.isNotEmpty && aiApiKey.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Learning configuration
  // ---------------------------------------------------------------------------
  static const int assessmentQuestionCount = 25;
  static const int defaultDailyGoal = 10;
  static const int xpPerLesson = 20;
  static const int xpPerCorrectQuestion = 5;
  static const int xpPerTestCompleted = 50;
  static const int xpStreakBonus = 10;

  // Spaced-repetition schedule in days (Day 1 → 3 → 7 → 14 → 30).
  static const List<int> revisionScheduleDays = [1, 3, 7, 14, 30];
}
