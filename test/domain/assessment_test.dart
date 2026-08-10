import 'package:accounting_academy/domain/assessment/assessment_engine.dart';
import 'package:accounting_academy/domain/assessment/roadmap_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assessment scoring', () {
    test('scores per-skill and overall accuracy', () {
      final result = scoreAssessment(
        answeredSkills: ['foundation', 'foundation', 'debit_credit', 'debit_credit'],
        correctness: [true, true, true, false],
        totalQuestions: 4,
      );
      expect(result.correctAnswers, 3);
      expect(result.accuracy, 0.75);
      final foundation = result.skills.firstWhere((s) => s.skill == 'foundation');
      expect(foundation.accuracy, 1.0);
      final debitCredit = result.skills.firstWhere((s) => s.skill == 'debit_credit');
      expect(debitCredit.accuracy, 0.5);
    });

    test('recommends level 1 for a beginner', () {
      final result = scoreAssessment(
        answeredSkills: List.filled(8, 'foundation'),
        correctness: List.filled(8, false),
        totalQuestions: 8,
      );
      expect(result.recommendedLevelIndex, 1);
    });

    test('recommends level 2 for solid foundation', () {
      final result = scoreAssessment(
        answeredSkills: ['foundation', 'foundation', 'debit_credit', 'journal'],
        correctness: [true, true, true, true],
        totalQuestions: 4,
      );
      expect(result.recommendedLevelIndex, 2);
    });

    test('recommends level 3 for strong advanced performance', () {
      final result = scoreAssessment(
        answeredSkills: ['foundation', 'debit_credit', 'journal', 'advanced'],
        correctness: [true, true, true, true],
        totalQuestions: 4,
      );
      expect(result.recommendedLevelIndex, greaterThanOrEqualTo(3));
    });

    test('recommends level 4 for near-perfect with strong advanced skill', () {
      final result = scoreAssessment(
        answeredSkills: List.filled(10, 'advanced'),
        correctness: List.filled(10, true),
        totalQuestions: 10,
      );
      expect(result.recommendedLevelIndex, 4);
    });
  });

  group('Roadmap builder', () {
    AssessmentResult weakResult() => scoreAssessment(
          answeredSkills: ['foundation', 'foundation', 'debit_credit', 'journal'],
          correctness: [false, false, true, true],
          totalQuestions: 4,
        );

    test('prioritizes weak-skill topics then forward path', () {
      final levels = [
        RoadmapLevelInput(levelIndex: 1, topics: [
          (topicId: 't_foundation_1', skills: ['foundation']),
          (topicId: 't_debit_1', skills: ['debit_credit']),
          (topicId: 't_journal_1', skills: ['journal']),
        ]),
        RoadmapLevelInput(levelIndex: 2, topics: [
          (topicId: 't_gst_1', skills: ['tax_awareness']),
        ]),
      ];
      final roadmap = RoadmapBuilder.build(assessment: weakResult(), levels: levels);

      expect(roadmap.first.topicId, 't_foundation_1');
      expect(roadmap.first.isPriority, isTrue);
      // Weak topics come first, in curriculum order.
      expect(roadmap.map((r) => r.topicId).toList(),
          ['t_foundation_1', 't_debit_1', 't_journal_1', 't_gst_1']);
    });

    test('skips levels below the recommended start', () {
      final levels = [
        RoadmapLevelInput(levelIndex: 1, topics: [
          (topicId: 't1', skills: ['foundation']),
        ]),
        RoadmapLevelInput(levelIndex: 2, topics: [
          (topicId: 't2', skills: ['gst']),
        ]),
      ];
      final strong = scoreAssessment(
        answeredSkills: ['foundation', 'foundation', 'foundation'],
        correctness: [true, true, true],
        totalQuestions: 3,
      );
      final roadmap = RoadmapBuilder.build(assessment: strong, levels: levels);
      expect(roadmap.map((r) => r.topicId), isNot(contains('t1')));
      expect(roadmap.map((r) => r.topicId), contains('t2'));
    });
  });
}
