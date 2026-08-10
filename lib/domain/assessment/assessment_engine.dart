/// Skill dimensions measured by the initial assessment.
const List<String> kAssessmentSkills = [
  'foundation',
  'debit_credit',
  'journal',
  'ledger',
  'trial_balance',
  'financial_statements',
  'tax_awareness',
  'advanced',
];

/// A single skill's score after assessment.
class SkillScore {
  const SkillScore({
    required this.skill,
    required this.correct,
    required this.total,
  });

  final String skill;
  final int correct;
  final int total;

  double get accuracy => total == 0 ? 0 : correct / total;
  bool get isWeak => total > 0 && accuracy < 0.5;
  bool get isStrong => total > 0 && accuracy >= 0.75;

  String get label => skillLabel(skill);
}

String skillLabel(String skill) => switch (skill) {
      'foundation' => 'Foundation',
      'debit_credit' => 'Debit & Credit',
      'journal' => 'Journal Entries',
      'ledger' => 'Ledger',
      'trial_balance' => 'Trial Balance',
      'financial_statements' => 'Financial Statements',
      'tax_awareness' => 'Tax & GST Awareness',
      'advanced' => 'Advanced Accounting',
      _ => skill,
    };

class AssessmentResult {
  const AssessmentResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.skills,
    required this.recommendedLevelIndex,
  });

  final int totalQuestions;
  final int correctAnswers;
  final List<SkillScore> skills;

  /// 1..4 (Foundation → CA Final).
  final int recommendedLevelIndex;

  double get accuracy => totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;

  List<SkillScore> get weakSkills => skills.where((s) => s.isWeak).toList();
  List<SkillScore> get strongSkills => skills.where((s) => s.isStrong).toList();
  SkillScore? get weakestSkill => weakSkills.isNotEmpty
      ? weakSkills.reduce((a, b) => a.accuracy <= b.accuracy ? a : b)
      : null;
}

/// Scores an assessment. [isAnswerCorrect] is supplied by the caller so this
/// engine stays independent of question-answer storage.
AssessmentResult scoreAssessment({
  required List<String> answeredSkills,
  required List<bool> correctness,
  required int totalQuestions,
}) {
  assert(answeredSkills.length == correctness.length);

  final perSkill = <String, List<bool>>{};
  for (var i = 0; i < answeredSkills.length; i++) {
    perSkill.putIfAbsent(answeredSkills[i], () => []).add(correctness[i]);
  }

  final skills = kAssessmentSkills.map((skill) {
    final results = perSkill[skill] ?? const <bool>[];
    return SkillScore(
      skill: skill,
      correct: results.where((c) => c).length,
      total: results.length,
    );
  }).toList();

  final correct = correctness.where((c) => c).length;
  final accuracy = totalQuestions == 0 ? 0.0 : correct / totalQuestions;

  return AssessmentResult(
    totalQuestions: totalQuestions,
    correctAnswers: correct,
    skills: skills,
    recommendedLevelIndex: recommendLevel(accuracy, skills),
  );
}

/// Maps overall accuracy + per-skill profile to a starting level (1..4).
///
/// Rules:
/// * A learner who cannot handle foundation concepts starts at Level 1 no
///   matter the overall score.
/// * Levels 3–4 (advanced / CA Final) require *demonstrated* advanced
///   strength — a learner never tested on advanced material is never placed
///   there, even at high accuracy.
/// * A learner with solid fundamentals is never forced back to Level 1 when
///   tax/advanced skills are weak — those become roadmap targets instead.
int recommendLevel(double accuracy, List<SkillScore> skills) {
  final foundation = skills.firstWhere((s) => s.skill == 'foundation',
      orElse: () => const SkillScore(skill: 'foundation', correct: 0, total: 0));
  final advanced = skills.firstWhere((s) => s.skill == 'advanced',
      orElse: () => const SkillScore(skill: 'advanced', correct: 0, total: 0));

  if (foundation.isWeak) return 1;

  final advancedDemonstrated = advanced.total > 0;
  final advancedStrong = advancedDemonstrated && advanced.accuracy >= 0.75;
  if (advancedDemonstrated && accuracy >= 0.85 && advancedStrong) return 4;
  if (advancedDemonstrated && accuracy >= 0.70 && advancedStrong) return 3;

  if (accuracy >= 0.45) return 2;
  return 1;
}
