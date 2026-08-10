/// The kind of test a learner can take.
enum TestKind {
  topic,
  chapter,
  level,
  mixed,
  professional,
  caFinalMock;

  static TestKind fromString(String value) => switch (value) {
        'topic' => topic,
        'chapter' => chapter,
        'level' => level,
        'mixed' => mixed,
        'professional' => professional,
        'ca_final_mock' => caFinalMock,
        _ => level,
      };

  String get label => switch (this) {
        topic => 'Topic Test',
        chapter => 'Chapter Test',
        level => 'Level Test',
        mixed => 'Mixed Test',
        professional => 'Professional Accountant Test',
        caFinalMock => 'CA Final Mock',
      };
}

/// A test the learner can take. Questions are either explicitly listed or
/// selected by scope (chapter/level/mixed) at run time.
class TestDefinition {
  const TestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    this.levelIndex,
    this.chapterId,
    this.topicId,
    this.questionIds = const [],
    this.durationMinutes = 10,
    this.negativeMarking = 0,
    this.passPercentage = 40,
    this.estimatedQuestionCount,
    this.difficulty,
  });

  final String id;
  final String title;
  final String description;
  final TestKind kind;
  final int? levelIndex;
  final String? chapterId;
  final String? topicId;

  /// Explicit question list (mock exams).
  final List<String> questionIds;

  final int durationMinutes;
  final double negativeMarking;
  final double passPercentage;

  /// For scoped tests: target number of questions.
  final int? estimatedQuestionCount;

  /// For mixed tests: constrain difficulty.
  final String? difficulty;
}
