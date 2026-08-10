import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/data/models/question.dart';
import 'package:accounting_academy/data/models/test_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = AssetContentDataSource();

  test('loads the level index with four levels and ranks', () async {
    final index = await source.loadIndex();
    expect(index.levels, hasLength(4));
    expect(index.ranks, isNotEmpty);
    expect(index.disclaimer, contains('ICAI'));
    expect(index.levels.map((l) => l.levelIndex).toList(), [1, 2, 3, 4]);
  });

  test('loads each level with subjects, chapters, topics and lessons', () async {
    final index = await source.loadIndex();
    var totalTopics = 0;
    var totalQuestions = 0;
    for (final meta in index.levels) {
      final level = await source.loadLevel(meta.id);
      expect(level.subjects, isNotEmpty, reason: '${meta.id} has subjects');
      for (final subject in level.subjects) {
        expect(subject.chapters, isNotEmpty);
        for (final chapter in subject.chapters) {
          expect(chapter.topics, isNotEmpty);
          for (final topic in chapter.topics) {
            totalTopics++;
            totalQuestions += topic.questions.length;
            if (topic.lesson != null) {
              expect(topic.lesson!.sections, isNotEmpty,
                  reason: '${topic.id} has lesson content');
            }
          }
        }
      }
    }
    expect(totalTopics, greaterThanOrEqualTo(30));
    expect(totalQuestions, greaterThanOrEqualTo(60));
  });

  test('assessment bank has at least 20 questions with skill tags', () async {
    final questions = await source.loadAssessmentQuestions();
    expect(questions.length, greaterThanOrEqualTo(20));
    final skills = questions.expand((q) => q.skills).toSet();
    expect(skills, containsAll([
      'foundation',
      'debit_credit',
      'journal',
      'ledger',
      'trial_balance',
      'financial_statements',
      'tax_awareness',
      'advanced',
    ]));
  });

  test('loads simulations with transactions and expected journals', () async {
    final simulations = await source.loadSimulations();
    expect(simulations, isNotEmpty);
    for (final sim in simulations) {
      expect(sim.transactions, isNotEmpty);
      for (final tx in sim.transactions) {
        expect(tx.expectedLines, isNotEmpty,
            reason: '${sim.id} tx ${tx.seq} has an expected journal');
      }
    }
  });

  test('loads reference sections', () async {
    final sections = await source.loadReference();
    expect(sections, isNotEmpty);
    expect(sections.every((s) => s.items.isNotEmpty), isTrue);
  });

  test('loads tests including chapter/level tests and mocks', () async {
    final tests = await source.loadTests();
    expect(tests, isNotEmpty);
    expect(tests.any((t) => t.kind == TestKind.caFinalMock), isTrue);
    expect(tests.any((t) => t.kind == TestKind.chapter), isTrue);
    expect(tests.any((t) => t.kind == TestKind.level), isTrue);
  });

  test('every question is answerable (has answer data)', () async {
    final index = await source.loadIndex();
    for (final meta in index.levels) {
      final level = await source.loadLevel(meta.id);
      for (final q in level.allQuestions) {
        expect(_hasAnswer(q), isTrue, reason: '${q.id} has an answer');
      }
    }
  });
}

bool _hasAnswer(QuestionData q) {
  switch (q.type) {
    case QuestionType.mcq:
    case QuestionType.trueFalse:
      return q.answer.keys.isNotEmpty && q.options.isNotEmpty;
    case QuestionType.numerical:
      return q.answer.value != null || q.answer.accepted.isNotEmpty;
    case QuestionType.fillBlank:
      return q.answer.accepted.isNotEmpty;
    case QuestionType.journalEntry:
      return q.answer.journalLines.isNotEmpty;
    default:
      return true;
  }
}
