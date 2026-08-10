import '../../core/config/app_config.dart';
import '../../core/storage/local_store.dart';
import '../../domain/assessment/assessment_engine.dart';
import '../../domain/gamification/gamification.dart';
import '../../domain/learning/revision_engine.dart';
import '../models/learner.dart';
import '../models/question.dart';

/// The full in-memory learner state (persisted to [LocalStore] on change).
class LearnerState {
  LearnerState({
    LearnerProfile? profile,
    Map<String, SkillMastery>? skills,
    List<AttemptRecord>? attempts,
    Map<String, MistakeRecord>? mistakes,
    List<RevisionRecord>? revision,
    List<NoteRecord>? notes,
    List<BookmarkRecord>? bookmarks,
    Set<String>? achievements,
  })  : profile = profile ?? const LearnerProfile(),
        skills = skills ?? {},
        attempts = attempts ?? [],
        mistakes = mistakes ?? {},
        revision = revision ?? [],
        notes = notes ?? [],
        bookmarks = bookmarks ?? [],
        achievements = achievements ?? {};

  LearnerProfile profile;
  final Map<String, SkillMastery> skills;
  final List<AttemptRecord> attempts;

  /// questionId -> mistake record.
  final Map<String, MistakeRecord> mistakes;
  final List<RevisionRecord> revision;
  final List<NoteRecord> notes;
  final List<BookmarkRecord> bookmarks;
  final Set<String> achievements;

  /// Mistakes grouped by skill, unresolved only, desc by count.
  List<({String skill, int count})> get weakSkillCounts {
    final counts = <String, int>{};
    for (final m in mistakes.values) {
      if (m.resolved) continue;
      counts.update(m.skill, (v) => v + m.count, ifAbsent: () => m.count);
    }
    final list = counts.entries
        .map((e) => (skill: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  SkillMastery? skillMastery(String skill) => skills[skill];
}

/// Coordinates learner state persistence and the LEARN → PRACTICE → TEST →
/// ANALYZE → REVISE loop. All updates are atomic in memory and flushed to
/// local storage; the sync engine mirrors them to the server when online.
class LearnerRepository {
  LearnerRepository(this._store);

  final LocalStore _store;
  static const _maxAttempts = 1000;

  LearnerState _state = LearnerState();
  LearnerState get state => _state;

  Future<void> init() async {
    _state = LearnerState(
      profile: _fromJson('profile', LearnerProfile.fromJson),
      skills: {
        for (final s in _fromJsonList('skills', SkillMastery.fromJson)) s.skill: s,
      },
      attempts: _fromJsonList('attempts', AttemptRecord.fromJson),
      mistakes: {
        for (final m in _fromJsonList('mistakes', MistakeRecord.fromJson))
          m.questionId: m,
      },
      revision: _fromJsonList('revision', RevisionRecord.fromJson),
      notes: _fromJsonList('notes', NoteRecord.fromJson),
      bookmarks: _fromJsonList('bookmarks', BookmarkRecord.fromJson),
      achievements:
          (_store.getJson('achievements') as List?)?.cast<String>().toSet() ??
              <String>{},
    );
  }

  T _fromJson<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _store.getJson(key);
    if (raw == null) return LearnerProfile() as T;
    return parse(raw as Map<String, dynamic>);
  }

  List<T> _fromJsonList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _store.getJson(key);
    if (raw == null) return <T>[];
    return (raw as List).map((e) => parse(e as Map<String, dynamic>)).toList();
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  Future<void> _persist() async {
    await _store.setJson('profile', _state.profile.toJson());
    await _store.setJson('skills',
        _state.skills.values.map((s) => s.toJson()).toList());
    await _store.setJson('attempts',
        _state.attempts.map((a) => a.toJson()).toList());
    await _store.setJson('mistakes',
        _state.mistakes.values.map((m) => m.toJson()).toList());
    await _store.setJson(
        'revision', _state.revision.map((r) => r.toJson()).toList());
    await _store.setJson('notes', _state.notes.map((n) => n.toJson()).toList());
    await _store.setJson(
        'bookmarks', _state.bookmarks.map((b) => b.toJson()).toList());
    await _store.setJson('achievements', _state.achievements.toList());
  }

  // -------------------------------------------------------------------------
  // Learning-loop updates
  // -------------------------------------------------------------------------

  /// Registers activity for today and updates the streak.
  Future<void> recordActivity({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final streak = updateStreak(
      current: _state.profile.currentStreak,
      longest: _state.profile.longestStreak,
      lastActiveDate: _state.profile.lastActiveDate,
      now: now,
    );
    _state.profile = _state.profile.copyWith(
      currentStreak: streak.current,
      longestStreak: streak.longest,
      lastActiveDate: now,
    );
    await _persist();
  }

  /// Records an answer: profile counters, skill mastery, mistakes, revision
  /// queue, XP and achievement evaluation. Returns newly unlocked achievements.
  Future<List<AchievementDef>> recordAnswer({
    required QuestionData question,
    required bool correct,
    String source = 'practice',
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await recordActivity(at: now);

    final skill = question.skills.isNotEmpty ? question.skills.first : 'foundation';
    final mastery = _state.skills[skill] ?? SkillMastery(skill: skill);
    _state.skills[skill] = mastery.record(correct);

    _state.attempts.add(AttemptRecord(
      questionId: question.id,
      skill: skill,
      correct: correct,
      answeredAt: now,
      source: source,
    ));
    if (_state.attempts.length > _maxAttempts) {
      _state.attempts.removeRange(0, _state.attempts.length - _maxAttempts);
    }

    var xp = 0;
    if (correct) {
      xp += AppConfig.xpPerCorrectQuestion;
      _state.profile = _state.profile.copyWith(
        questionsSolved: _state.profile.questionsSolved + 1,
        correctAnswers: _state.profile.correctAnswers + 1,
      );
    } else {
      _state.profile = _state.profile.copyWith(
        questionsSolved: _state.profile.questionsSolved + 1,
      );
      // Mistake intelligence: record + push into revision queue.
      final existing = _state.mistakes[question.id];
      _state.mistakes[question.id] =
          (existing ?? MistakeRecord(questionId: question.id, skill: skill))
              .increment();
      final item = _state.revision
          .where((r) => r.contentId == question.id && r.contentType == 'question')
          .firstOrNull;
      if (item == null) {
        _state.revision.add(RevisionRecord(
          contentId: question.id,
          contentType: 'question',
          skillKey: skill,
        ));
      } else {
        _state.revision[_state.revision.indexOf(item)] =
            RevisionRecord.fromItem(RevisionEngine.applyReview(
          item: item.toItem(),
          correct: false,
          reviewedAt: now,
        ));
      }
    }

    _state.profile = _state.profile.copyWith(totalXp: _state.profile.totalXp + xp);
    final unlocked = _unlockAchievements();
    await _persist();
    return unlocked;
  }

  /// Marks a lesson complete: XP + progress counters.
  Future<List<AchievementDef>> completeLesson({DateTime? at}) async {
    final now = at ?? DateTime.now();
    await recordActivity(at: now);
    _state.profile = _state.profile.copyWith(
      lessonsCompleted: _state.profile.lessonsCompleted + 1,
      totalXp: _state.profile.totalXp + AppConfig.xpPerLesson,
    );
    final unlocked = _unlockAchievements();
    await _persist();
    return unlocked;
  }

  /// Records a completed test submission.
  Future<List<AchievementDef>> completeTest({
    required int correctCount,
    required int totalCount,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await recordActivity(at: now);
    _state.profile = _state.profile.copyWith(
      testsCompleted: _state.profile.testsCompleted + 1,
      totalXp: _state.profile.totalXp + AppConfig.xpPerTestCompleted + correctCount * 2,
    );
    final unlocked = _unlockAchievements();
    await _persist();
    return unlocked;
  }

  /// Applies the initial assessment result: stores the personalized starting
  /// level and marks the profile onboarded.
  Future<void> applyAssessment(AssessmentResult result, {DateTime? at}) async {
    await recordActivity(at: at);
    _state.profile = _state.profile.copyWith(
      assessmentTaken: true,
      startingLevelIndex: result.recommendedLevelIndex,
      totalXp: _state.profile.totalXp + result.correctAnswers * AppConfig.xpPerCorrectQuestion,
    );
    await _persist();
  }

  /// Reviews a revision item; [correct] true advances the schedule, false
  /// resets and reprioritizes. Returns newly unlocked achievements.
  Future<List<AchievementDef>> reviewRevision({
    required String contentId,
    required bool correct,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await recordActivity(at: now);
    final idx = _state.revision.indexWhere(
        (r) => r.contentId == contentId && r.contentType == 'question');
    if (idx == -1) return const [];
    final next = RevisionEngine.applyReview(
      item: _state.revision[idx].toItem(),
      correct: correct,
      reviewedAt: now,
    );
    _state.revision[idx] = RevisionRecord.fromItem(next);

    final mistake = _state.mistakes[contentId];
    if (correct && mistake != null) {
      _state.mistakes[contentId] = mistake.resolve();
      _state.profile = _state.profile.copyWith(
        mistakesResolved: _state.profile.mistakesResolved + 1,
        totalXp: _state.profile.totalXp + AppConfig.xpPerCorrectQuestion,
      );
    }
    final unlocked = _unlockAchievements();
    await _persist();
    return unlocked;
  }

  // -------------------------------------------------------------------------
  // Notes & bookmarks
  // -------------------------------------------------------------------------

  Future<void> addNote(NoteRecord note) async {
    _state.notes.insert(0, note);
    await _persist();
  }

  Future<void> deleteNote(String id) async {
    _state.notes.removeWhere((n) => n.id == id);
    await _persist();
  }

  Future<void> addBookmark(BookmarkRecord bookmark) async {
    _state.bookmarks.removeWhere(
        (b) => b.contentType == bookmark.contentType && b.contentId == bookmark.contentId);
    _state.bookmarks.insert(0, bookmark);
    await _persist();
  }

  Future<void> removeBookmark(String contentType, String contentId) async {
    _state.bookmarks.removeWhere(
        (b) => b.contentType == contentType && b.contentId == contentId);
    await _persist();
  }

  bool isBookmarked(String contentType, String contentId) => _state.bookmarks
      .any((b) => b.contentType == contentType && b.contentId == contentId);

  // -------------------------------------------------------------------------
  // Settings / profile
  // -------------------------------------------------------------------------

  Future<void> updateDailyGoal(int goal) async {
    _state.profile = _state.profile.copyWith(dailyGoal: goal);
    await _persist();
  }

  Future<void> setOnboarded({bool assessmentTaken = false}) async {
    _state.profile = _state.profile.copyWith(
      onboarded: true,
      assessmentTaken: assessmentTaken,
    );
    await _persist();
  }

  Future<void> updateName(String name) async {
    _state.profile = _state.profile.copyWith(fullName: name);
    await _persist();
  }

  Future<void> resetAll() async {
    _state = LearnerState();
    await _store.clear();
    await _persist();
  }

  List<AchievementDef> _unlockAchievements() {
    final unlocked = AchievementCatalog.evaluate(
      _state.profile.toStats(),
      alreadyUnlocked: _state.achievements,
    );
    for (final a in unlocked) {
      _state.achievements.add(a.slug);
    }
    return unlocked;
  }
}
