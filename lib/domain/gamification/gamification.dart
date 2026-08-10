/// A rank definition (title + XP threshold), e.g. from levels.json `ranks`.
class RankDef {
  const RankDef({required this.key, required this.title, required this.minXp});

  final String key;
  final String title;
  final int minXp;
}

RankDef rankForXp(List<RankDef> ranks, int xp) {
  RankDef current = ranks.first;
  for (final rank in ranks) {
    if (xp >= rank.minXp) current = rank;
  }
  return current;
}

RankDef? nextRank(List<RankDef> ranks, int xp) {
  for (final rank in ranks) {
    if (xp < rank.minXp) return rank;
  }
  return null;
}

/// Pure streak arithmetic. Days are compared by calendar date.
class StreakState {
  const StreakState({required this.current, required this.longest});

  final int current;
  final int longest;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime a, DateTime b) =>
    _dateOnly(b).difference(_dateOnly(a)).inDays;

/// Updates a streak given the previous state and the last active day.
/// Returns the new streak state (current, longest).
StreakState updateStreak({
  required int current,
  required int longest,
  DateTime? lastActiveDate,
  required DateTime now,
}) {
  if (lastActiveDate == null) {
    // First ever activity: a one-day streak, and the longest is at least 1.
    return StreakState(current: 1, longest: longest < 1 ? 1 : longest);
  }
  final days = _daysBetween(lastActiveDate, now);
  if (days <= 0) {
    // Same day (or clock skew) — streak unchanged.
    return StreakState(current: current, longest: longest);
  }
  if (days == 1) {
    final newCurrent = current + 1;
    return StreakState(
      current: newCurrent,
      longest: newCurrent > longest ? newCurrent : longest,
    );
  }
  // Gap of 2+ days — streak resets.
  return StreakState(current: 1, longest: longest);
}

/// A snapshot of learner stats used to evaluate achievements.
class StatsSnapshot {
  const StatsSnapshot({
    this.questionsSolved = 0,
    this.correctAnswers = 0,
    this.lessonsCompleted = 0,
    this.testsCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.mistakesResolved = 0,
    this.levelsCompleted = 0,
    this.totalXp = 0,
  });

  final int questionsSolved;
  final int correctAnswers;
  final int lessonsCompleted;
  final int testsCompleted;
  final int currentStreak;
  final int longestStreak;
  final int mistakesResolved;
  final int levelsCompleted;
  final int totalXp;

  double get accuracy =>
      questionsSolved == 0 ? 0 : correctAnswers / questionsSolved;
}

class AchievementDef {
  const AchievementDef({
    required this.slug,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.condition,
  });

  final String slug;
  final String title;
  final String description;
  final String icon;
  final int xpReward;

  /// Evaluates the achievement against stats; returns true when unlocked.
  final bool Function(StatsSnapshot stats) condition;
}

/// Professional gamification catalog — measurable, no childish mechanics.
class AchievementCatalog {
  AchievementCatalog._();

  // `final`, not `const`: achievement conditions are closures.
  static final List<AchievementDef> all = [
    AchievementDef(
      slug: 'first_step',
      title: 'First Step',
      description: 'Answer your first question.',
      icon: 'step',
      xpReward: 25,
      condition: (s) => s.questionsSolved >= 1,
    ),
    AchievementDef(
      slug: 'hundred_questions',
      title: 'Century',
      description: 'Solve 100 questions.',
      icon: 'questions',
      xpReward: 100,
      condition: (s) => s.questionsSolved >= 100,
    ),
    AchievementDef(
      slug: 'five_hundred_questions',
      title: 'Marathoner',
      description: 'Solve 500 questions.',
      icon: 'questions',
      xpReward: 250,
      condition: (s) => s.questionsSolved >= 500,
    ),
    AchievementDef(
      slug: 'accuracy_90',
      title: 'Precision',
      description: 'Reach 90% accuracy over your first 50 questions.',
      icon: 'target',
      xpReward: 150,
      condition: (s) => s.questionsSolved >= 50 && s.accuracy >= 0.90,
    ),
    AchievementDef(
      slug: 'seven_day_streak',
      title: 'Discipline',
      description: 'Maintain a 7-day streak.',
      icon: 'streak',
      xpReward: 120,
      condition: (s) => s.currentStreak >= 7,
    ),
    AchievementDef(
      slug: 'thirty_day_streak',
      title: 'Iron Resolve',
      description: 'Maintain a 30-day streak.',
      icon: 'streak',
      xpReward: 400,
      condition: (s) => s.currentStreak >= 30,
    ),
    AchievementDef(
      slug: 'first_lesson',
      title: 'Curious',
      description: 'Complete your first lesson.',
      icon: 'lesson',
      xpReward: 30,
      condition: (s) => s.lessonsCompleted >= 1,
    ),
    AchievementDef(
      slug: 'ten_lessons',
      title: 'Steady Study',
      description: 'Complete 10 lessons.',
      icon: 'lesson',
      xpReward: 100,
      condition: (s) => s.lessonsCompleted >= 10,
    ),
    AchievementDef(
      slug: 'first_test',
      title: 'Exam Ready',
      description: 'Submit your first test.',
      icon: 'test',
      xpReward: 60,
      condition: (s) => s.testsCompleted >= 1,
    ),
    AchievementDef(
      slug: 'mock_exam',
      title: 'Mock Warrior',
      description: 'Complete a CA Final mock examination.',
      icon: 'mock',
      xpReward: 200,
      condition: (s) => s.testsCompleted >= 5,
    ),
    AchievementDef(
      slug: 'mistake_slayer',
      title: 'Mistake Slayer',
      description: 'Resolve 10 recorded mistakes in revision.',
      icon: 'fix',
      xpReward: 150,
      condition: (s) => s.mistakesResolved >= 10,
    ),
    AchievementDef(
      slug: 'level_clear',
      title: 'Level Cleared',
      description: 'Complete a full curriculum level.',
      icon: 'level',
      xpReward: 250,
      condition: (s) => s.levelsCompleted >= 1,
    ),
    AchievementDef(
      slug: 'xp_1000',
      title: 'Rising',
      description: 'Earn 1,000 XP.',
      icon: 'xp',
      xpReward: 100,
      condition: (s) => s.totalXp >= 1000,
    ),
    AchievementDef(
      slug: 'xp_5000',
      title: 'High Achiever',
      description: 'Earn 5,000 XP.',
      icon: 'xp',
      xpReward: 300,
      condition: (s) => s.totalXp >= 5000,
    ),
  ];

  /// Achievements unlocked given current stats (freshly earned = not in
  /// [alreadyUnlocked]).
  static List<AchievementDef> evaluate(
    StatsSnapshot stats, {
    Set<String> alreadyUnlocked = const {},
  }) =>
      all.where((a) => !alreadyUnlocked.contains(a.slug) && a.condition(stats)).toList();
}
