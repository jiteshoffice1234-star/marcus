import '../../domain/gamification/gamification.dart';
import '../../domain/learning/revision_engine.dart';

/// The learner's profile — persisted locally and mirrored to Supabase.
class LearnerProfile {
  const LearnerProfile({
    this.fullName,
    this.email,
    this.onboarded = false,
    this.assessmentTaken = false,
    this.startingLevelIndex = 1,
    this.dailyGoal = 10,
    this.totalXp = 0,
    this.questionsSolved = 0,
    this.correctAnswers = 0,
    this.lessonsCompleted = 0,
    this.testsCompleted = 0,
    this.mistakesResolved = 0,
    this.levelsCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
  });

  final String? fullName;
  final String? email;
  final bool onboarded;
  final bool assessmentTaken;
  final int startingLevelIndex;
  final int dailyGoal;
  final int totalXp;
  final int questionsSolved;
  final int correctAnswers;
  final int lessonsCompleted;
  final int testsCompleted;
  final int mistakesResolved;
  final int levelsCompleted;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;

  double get accuracy =>
      questionsSolved == 0 ? 0 : correctAnswers / questionsSolved;

  LearnerProfile copyWith({
    String? fullName,
    String? email,
    bool? onboarded,
    bool? assessmentTaken,
    int? startingLevelIndex,
    int? dailyGoal,
    int? totalXp,
    int? questionsSolved,
    int? correctAnswers,
    int? lessonsCompleted,
    int? testsCompleted,
    int? mistakesResolved,
    int? levelsCompleted,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
  }) =>
      LearnerProfile(
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        onboarded: onboarded ?? this.onboarded,
        assessmentTaken: assessmentTaken ?? this.assessmentTaken,
        startingLevelIndex: startingLevelIndex ?? this.startingLevelIndex,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        totalXp: totalXp ?? this.totalXp,
        questionsSolved: questionsSolved ?? this.questionsSolved,
        correctAnswers: correctAnswers ?? this.correctAnswers,
        lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
        testsCompleted: testsCompleted ?? this.testsCompleted,
        mistakesResolved: mistakesResolved ?? this.mistakesResolved,
        levelsCompleted: levelsCompleted ?? this.levelsCompleted,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      );

  StatsSnapshot toStats() => StatsSnapshot(
        questionsSolved: questionsSolved,
        correctAnswers: correctAnswers,
        lessonsCompleted: lessonsCompleted,
        testsCompleted: testsCompleted,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        mistakesResolved: mistakesResolved,
        levelsCompleted: levelsCompleted,
        totalXp: totalXp,
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'onboarded': onboarded,
        'assessmentTaken': assessmentTaken,
        'startingLevelIndex': startingLevelIndex,
        'dailyGoal': dailyGoal,
        'totalXp': totalXp,
        'questionsSolved': questionsSolved,
        'correctAnswers': correctAnswers,
        'lessonsCompleted': lessonsCompleted,
        'testsCompleted': testsCompleted,
        'mistakesResolved': mistakesResolved,
        'levelsCompleted': levelsCompleted,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
      };

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
        fullName: json['fullName'] as String?,
        email: json['email'] as String?,
        onboarded: json['onboarded'] as bool? ?? false,
        assessmentTaken: json['assessmentTaken'] as bool? ?? false,
        startingLevelIndex: json['startingLevelIndex'] as int? ?? 1,
        dailyGoal: json['dailyGoal'] as int? ?? 10,
        totalXp: json['totalXp'] as int? ?? 0,
        questionsSolved: json['questionsSolved'] as int? ?? 0,
        correctAnswers: json['correctAnswers'] as int? ?? 0,
        lessonsCompleted: json['lessonsCompleted'] as int? ?? 0,
        testsCompleted: json['testsCompleted'] as int? ?? 0,
        mistakesResolved: json['mistakesResolved'] as int? ?? 0,
        levelsCompleted: json['levelsCompleted'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        lastActiveDate: json['lastActiveDate'] == null
            ? null
            : DateTime.tryParse(json['lastActiveDate'] as String),
      );
}

/// Per-skill mastery tracked continuously from attempts.
class SkillMastery {
  const SkillMastery({
    required this.skill,
    this.attempts = 0,
    this.correct = 0,
  });

  final String skill;
  final int attempts;
  final int correct;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  SkillMastery record(bool wasCorrect) => SkillMastery(
        skill: skill,
        attempts: attempts + 1,
        correct: correct + (wasCorrect ? 1 : 0),
      );

  Map<String, dynamic> toJson() =>
      {'skill': skill, 'attempts': attempts, 'correct': correct};

  factory SkillMastery.fromJson(Map<String, dynamic> json) => SkillMastery(
        skill: json['skill'] as String,
        attempts: json['attempts'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
      );
}

/// A single answered question.
class AttemptRecord {
  const AttemptRecord({
    required this.questionId,
    required this.skill,
    required this.correct,
    required this.answeredAt,
    this.source = 'practice',
  });

  final String questionId;
  final String skill;
  final bool correct;
  final DateTime answeredAt;
  final String source;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'skill': skill,
        'correct': correct,
        'answeredAt': answeredAt.toIso8601String(),
        'source': source,
      };

  factory AttemptRecord.fromJson(Map<String, dynamic> json) => AttemptRecord(
        questionId: json['questionId'] as String,
        skill: json['skill'] as String? ?? 'foundation',
        correct: json['correct'] as bool? ?? false,
        answeredAt: DateTime.parse(json['answeredAt'] as String),
        source: json['source'] as String? ?? 'practice',
      );
}

/// A recorded mistake (feed for the mistake engine).
class MistakeRecord {
  const MistakeRecord({
    required this.questionId,
    required this.skill,
    this.count = 0,
    this.resolved = false,
    this.lastMissedAt,
  });

  final String questionId;
  final String skill;
  final int count;
  final bool resolved;
  final DateTime? lastMissedAt;

  MistakeRecord increment() => MistakeRecord(
        questionId: questionId,
        skill: skill,
        count: count + 1,
        resolved: false,
        lastMissedAt: DateTime.now(),
      );

  MistakeRecord resolve() => MistakeRecord(
        questionId: questionId,
        skill: skill,
        count: count,
        resolved: true,
        lastMissedAt: lastMissedAt,
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'skill': skill,
        'count': count,
        'resolved': resolved,
        'lastMissedAt': lastMissedAt?.toIso8601String(),
      };

  factory MistakeRecord.fromJson(Map<String, dynamic> json) => MistakeRecord(
        questionId: json['questionId'] as String,
        skill: json['skill'] as String? ?? 'foundation',
        count: json['count'] as int? ?? 1,
        resolved: json['resolved'] as bool? ?? false,
        lastMissedAt: json['lastMissedAt'] == null
            ? null
            : DateTime.tryParse(json['lastMissedAt'] as String),
      );
}

/// Persisted revision queue item (domain [RevisionItem] + JSON).
class RevisionRecord {
  const RevisionRecord({
    required this.contentId,
    required this.contentType,
    this.skillKey,
    this.state = RevisionState.newItem,
    this.repetitions = 0,
    this.ease = 2.5,
    this.intervalDays = 1,
    this.dueAt,
  });

  final String contentId;
  final String contentType;
  final String? skillKey;
  final RevisionState state;
  final int repetitions;
  final double ease;
  final int intervalDays;
  final DateTime? dueAt;

  RevisionItem toItem() => RevisionItem(
        contentId: contentId,
        contentType: contentType,
        skillKey: skillKey,
        state: state,
        repetitions: repetitions,
        ease: ease,
        intervalDays: intervalDays,
        dueAt: dueAt,
      );

  factory RevisionRecord.fromItem(RevisionItem item) => RevisionRecord(
        contentId: item.contentId,
        contentType: item.contentType,
        skillKey: item.skillKey,
        state: item.state,
        repetitions: item.repetitions,
        ease: item.ease,
        intervalDays: item.intervalDays,
        dueAt: item.dueAt,
      );

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'contentType': contentType,
        'skillKey': skillKey,
        'state': state.name,
        'repetitions': repetitions,
        'ease': ease,
        'intervalDays': intervalDays,
        'dueAt': dueAt?.toIso8601String(),
      };

  factory RevisionRecord.fromJson(Map<String, dynamic> json) => RevisionRecord(
        contentId: json['contentId'] as String,
        contentType: json['contentType'] as String,
        skillKey: json['skillKey'] as String?,
        state: RevisionState.values.firstWhere(
            (s) => s.name == json['state'],
            orElse: () => RevisionState.newItem),
        repetitions: json['repetitions'] as int? ?? 0,
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: json['intervalDays'] as int? ?? 1,
        dueAt: json['dueAt'] == null
            ? null
            : DateTime.tryParse(json['dueAt'] as String),
      );
}

/// A user-created note.
class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.title,
    required this.body,
    this.contentType,
    this.contentId,
    this.isMistakeNote = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? contentType;
  final String? contentId;
  final bool isMistakeNote;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'contentType': contentType,
        'contentId': contentId,
        'isMistakeNote': isMistakeNote,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory NoteRecord.fromJson(Map<String, dynamic> json) => NoteRecord(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        contentType: json['contentType'] as String?,
        contentId: json['contentId'] as String?,
        isMistakeNote: json['isMistakeNote'] as bool? ?? false,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}

/// A bookmarked lesson/question/reference.
class BookmarkRecord {
  const BookmarkRecord({
    required this.contentType,
    required this.contentId,
    this.title,
    this.createdAt,
  });

  final String contentType;
  final String contentId;
  final String? title;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'contentType': contentType,
        'contentId': contentId,
        'title': title,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory BookmarkRecord.fromJson(Map<String, dynamic> json) => BookmarkRecord(
        contentType: json['contentType'] as String,
        contentId: json['contentId'] as String,
        title: json['title'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}
