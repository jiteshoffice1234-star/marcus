import 'dart:convert';

import 'package:accounting_academy/core/utils/money.dart';
import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/data/models/question.dart';
import 'package:accounting_academy/data/repositories/content_repository.dart';
import 'package:accounting_academy/domain/accounting/account.dart';
import 'package:accounting_academy/domain/accounting/journal.dart';
import 'package:accounting_academy/domain/accounting/statements.dart';
import 'package:accounting_academy/domain/accounting/trial_balance.dart';
import 'package:accounting_academy/features/exams/presentation/test_runner_screen.dart'
    show resolveTestQuestions;
import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _validQuestionTypes = {
  'mcq',
  'numerical',
  'journal_entry',
  'fill_blank',
  'true_false',
  'error_correction',
  'match_items',
  'financial_statement',
  'case_study',
  'multi_step',
};

const _validDifficulties = {
  'beginner',
  'easy',
  'intermediate',
  'advanced',
  'ca_final',
};

final _jsonCache = <String, Future<Map<String, dynamic>>>{};

Future<Map<String, dynamic>> _loadJson(String path) {
  return _jsonCache.putIfAbsent(
    path,
    () async => jsonDecode(await rootBundle.loadString(path))
        as Map<String, dynamic>,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = AssetContentDataSource();
  final repo = ContentRepository(source);

  group('Raw JSON schema', () {
    test('level curriculum files are structurally valid', () async {
      final index = await _loadJson('assets/data/levels.json');
      final levelFiles = <String, dynamic>{
        for (final l in index['levels'] as List<dynamic>)
          (l as Map<String, dynamic>)['dataFile'] as String: l,
      };

      final allIds = <String>[];
      final allTopics = <({String levelId, String topicId, List<String> skills})>[];

      for (final entry in levelFiles.entries) {
        final levelJson = await _loadJson(entry.key);
        final meta = entry.value as Map<String, dynamic>;
        expect(levelJson['levelId'], meta['id'],
            reason: '${entry.key} declares the level id from the index');
        final seen = <String>[];
        for (final subject in levelJson['subjects'] as List<dynamic>) {
          final s = subject as Map<String, dynamic>;
          seen.add(s['id'] as String);
          for (final chapter in s['chapters'] as List<dynamic>) {
            final c = chapter as Map<String, dynamic>;
            seen.add(c['id'] as String);
            for (final topic in c['topics'] as List<dynamic>) {
              final t = topic as Map<String, dynamic>;
              seen.add(t['id'] as String);
              allTopics.add((
                levelId: meta['id'] as String,
                topicId: t['id'] as String,
                skills: (t['skills'] as List<dynamic>? ?? const [])
                    .cast<String>(),
              ));
              final lesson = t['lesson'] as Map<String, dynamic>?;
              if (lesson != null) {
                seen.add(lesson['id'] as String);
                expect(lesson['sections'], isNotEmpty,
                    reason: '${lesson['id']} has lesson content');
              }
              for (final q in t['questions'] as List<dynamic>? ?? const []) {
                final question = q as Map<String, dynamic>;
                seen.add(question['id'] as String);
                _expectValidQuestion(question);
              }
            }
          }
        }
        // No duplicate ids within this level.
        expect(seen.toSet().length, seen.length,
            reason: '${entry.key} has no duplicate ids');
        allIds.addAll(seen);
      }

      expect(allIds.toSet().length, allIds.length,
          reason: 'no duplicate ids across levels');
      // Every level declares at least one topic.
      expect(allTopics, isNotEmpty);
    });

    test('assessment bank is structurally valid with no duplicate ids', () async {
      final json = await _loadJson('assets/data/assessment.json');
      final ids = <String>[];
      for (final q in json['questions'] as List<dynamic>) {
        final question = q as Map<String, dynamic>;
        ids.add(question['id'] as String);
        _expectValidQuestion(question);
      }
      expect(ids.toSet().length, ids.length,
          reason: 'assessment ids are unique');
    });

    test('simulations are structurally valid and produce balanced statements',
        () async {
      final json = await _loadJson('assets/data/simulations.json');
      final simIds = <String>[];
      for (final raw in json['simulations'] as List<dynamic>) {
        final sim = raw as Map<String, dynamic>;
        simIds.add(sim['id'] as String);

        final opening = (sim['openingBalances'] as Map<String, dynamic>? ??
            const {});
        var signedOpening = Decimal.zero;
        for (final e in opening.entries) {
          final account = ChartOfAccounts.byName(e.key) ??
              Account(e.key, AccountCategory.asset);
          final amount = tryParseAmount(e.value.toString());
          expect(amount, isNotNull,
              reason: '${sim['id']} opening ${e.key} parses');
          expect(amount! < Decimal.zero || amount == Decimal.zero, isFalse,
              reason: '${sim['id']} opening ${e.key} is positive');
          signedOpening += account.category.normalDebit ? amount : -amount;
        }
        expect(signedOpening, Decimal.zero,
            reason: '${sim['id']} opening balances are internally balanced '
                '(debits = credits) so the final statements can balance');

        final transactions = sim['transactions'] as List<dynamic>;
        expect(transactions, isNotEmpty,
            reason: '${sim['id']} has transactions');
        for (final rawTx in transactions) {
          final tx = rawTx as Map<String, dynamic>;
          final lines = tx['expectedJournal'] as List<dynamic>;
          expect(lines, isNotEmpty,
              reason: '${sim['id']} tx ${tx['seq']} has an expected journal');
          var dr = Decimal.zero;
          var cr = Decimal.zero;
          for (final rawLine in lines) {
            final line = rawLine as Map<String, dynamic>;
            expect(['debit', 'credit'], contains(line['side']),
                reason: '${sim['id']} tx ${tx['seq']} side is valid');
            final amount = tryParseAmount(line['amount'].toString());
            expect(amount, isNotNull,
                reason: '${sim['id']} tx ${tx['seq']} amount parses');
            expect(amount! < Decimal.zero || amount == Decimal.zero, isFalse,
                reason: '${sim['id']} tx ${tx['seq']} amount is positive');
            if (line['side'] == 'debit') {
              dr += amount;
            } else {
              cr += amount;
            }
          }
          expect(dr, cr,
              reason: '${sim['id']} tx ${tx['seq']} expected journal balances '
                  '(debits = credits)');
        }
      }
      expect(simIds.toSet().length, simIds.length,
          reason: 'simulation ids are unique');
    });

    test('test definitions resolve to real questions', () async {
      final tests = await source.loadTests();
      expect(tests, isNotEmpty);
      final index = await source.loadIndex();
      final levelIds = index.levels.map((l) => l.id).toSet();
      for (final test in tests) {
        final questions = await resolveTestQuestions(test, repo);
        expect(questions, isNotEmpty,
            reason: 'test ${test.id} resolves to questions');
        for (final id in test.questionIds) {
          expect(await repo.findQuestion(id), isNotNull,
              reason: 'test ${test.id} question $id exists');
        }
        if (test.levelIndex != null) {
          expect(levelIds, isNotEmpty);
        }
      }
    });
  });

  group('Content model invariants (via AssetContentDataSource)', () {
    test('every numerical answer variant equals the canonical value', () async {
      final index = await source.loadIndex();
      var checked = 0;
      for (final meta in index.levels) {
        final level = await source.loadLevel(meta.id);
        for (final q in level.allQuestions) {
          if (q.type != QuestionType.numerical) continue;
          final expected = tryParseAmount(q.answer.value ?? '');
          expect(expected, isNotNull,
              reason: '${q.id} has a parseable canonical value');
          for (final variant in q.answer.accepted) {
            final parsed = tryParseAmount(variant);
            expect(parsed, isNotNull,
                reason: '${q.id} accepted variant "$variant" parses');
            expect(parsed, expected,
                reason: '${q.id} accepted variant "$variant" equals the '
                    'canonical value ${q.answer.value}');
          }
          checked++;
        }
      }
      expect(checked, greaterThanOrEqualTo(10),
          reason: 'a meaningful number of numerical questions were checked');
    });

    test('MCQ and true/false questions have exactly one valid answer key',
        () async {
      final index = await source.loadIndex();
      for (final meta in index.levels) {
        final level = await source.loadLevel(meta.id);
        for (final q in level.allQuestions) {
          if (q.type != QuestionType.mcq &&
              q.type != QuestionType.trueFalse) {
            continue;
          }
          expect(q.answer.keys, hasLength(1),
              reason: '${q.id} has exactly one answer key');
          final keys = q.options.map((o) => o.key).toSet();
          expect(keys.toList().length, q.options.length,
              reason: '${q.id} option keys are unique');
          expect(q.options.length, greaterThanOrEqualTo(2),
              reason: '${q.id} has at least two options');
          for (final key in q.answer.keys) {
            expect(keys, contains(key),
                reason: '${q.id} answer key $key exists among options');
          }
          final wrongKeys = q.whyOthersWrong.map((e) => e.key).toSet();
          for (final key in wrongKeys) {
            expect(keys, contains(key),
                reason: '${q.id} whyOthersWrong key $key exists among options');
          }
        }
      }
    });

    test('journal-entry questions have balanced expected journals', () async {
      final index = await source.loadIndex();
      for (final meta in index.levels) {
        final level = await source.loadLevel(meta.id);
        for (final q in level.allQuestions) {
          if (q.type != QuestionType.journalEntry) continue;
          expect(q.answer.journalLines, isNotEmpty,
              reason: '${q.id} has expected journal lines');
          var dr = Decimal.zero;
          var cr = Decimal.zero;
          for (final line in q.answer.journalLines) {
            expect(['debit', 'credit'], contains(line.side),
                reason: '${q.id} line side is valid');
            final amount = tryParseAmount(line.amount);
            expect(amount, isNotNull,
                reason: '${q.id} line amount ${line.amount} parses');
            if (line.side == 'debit') {
              dr += amount!;
            } else {
              cr += amount!;
            }
          }
          expect(dr, cr,
              reason: '${q.id} expected journal balances (debits = credits)');
        }
      }
    });

    test('every question is answerable with a non-empty stem', () async {
      final index = await source.loadIndex();
      for (final meta in index.levels) {
        final level = await source.loadLevel(meta.id);
        for (final q in level.allQuestions) {
          expect(q.stem.trim(), isNotEmpty, reason: '${q.id} has a stem');
          expect(_hasAnswer(q), isTrue, reason: '${q.id} has answer data');
        }
      }
      final assessment = await source.loadAssessmentQuestions();
      for (final q in assessment) {
        expect(q.stem.trim(), isNotEmpty, reason: '${q.id} has a stem');
        expect(_hasAnswer(q), isTrue, reason: '${q.id} has answer data');
      }
    });

    test('every simulation, fully journalized, produces a balanced trial '
        'balance and balanced financial statements', () async {
      final simulations = await source.loadSimulations();
      expect(simulations, isNotEmpty);
      for (final sim in simulations) {
        final ledger = sim.buildOpeningLedger();
        for (final tx in sim.transactions) {
          final entry = JournalEntry([
            for (final line in tx.expectedLines)
              JournalLine(
                account: ChartOfAccounts.byName(line.account) ??
                    Account(line.account, AccountCategory.asset),
                side: line.side == 'credit'
                    ? JournalSide.credit
                    : JournalSide.debit,
                amount: tryParseAmount(line.amount) ?? Decimal.zero,
              ),
          ]);
          ledger.post(entry);
        }

        expect(ledger.isBalanced, isTrue,
            reason: '${sim.id} ledger debits = credits after correct posting');
        final tb = TrialBalance.fromLedger(ledger);
        expect(tb.isBalanced, isTrue,
            reason: '${sim.id} trial balance balances after correct posting');

        final statements = StatementBuilder.build(ledger);
        expect(statements.balanceSheet.isBalanced, isTrue,
            reason: '${sim.id} balance sheet balances: '
                'assets = liabilities + capital');
        // Double check the accounting equation with the actual figures.
        expect(
          statements.balanceSheet.totalAssets,
          statements.balanceSheet.totalLiabilities +
              statements.balanceSheet.totalCapital,
          reason: '${sim.id} Assets = Liabilities + Capital',
        );
      }
    });

    test('every lesson topic has non-empty sections and unique lesson ids',
        () async {
      final index = await source.loadIndex();
      final lessonIds = <String>[];
      for (final meta in index.levels) {
        final level = await source.loadLevel(meta.id);
        for (final subject in level.subjects) {
          for (final chapter in subject.chapters) {
            for (final topic in chapter.topics) {
              final lesson = topic.lesson;
              if (lesson != null) {
                lessonIds.add(lesson.id);
                expect(lesson.sections, isNotEmpty,
                    reason: '${lesson.id} has sections');
              }
            }
          }
        }
      }
      expect(lessonIds.toSet().length, lessonIds.length,
          reason: 'lesson ids are unique');
    });
  });
}

void _expectValidQuestion(Map<String, dynamic> question) {
  final id = question['id'] as String;
  final type = question['type'] as String? ?? 'mcq';
  final difficulty = question['difficulty'] as String? ?? 'easy';
  expect(_validQuestionTypes, contains(type),
      reason: '$id has a valid question type (got "$type")');
  expect(_validDifficulties, contains(difficulty),
      reason: '$id has a valid difficulty (got "$difficulty")');
  expect((question['stem'] as String? ?? '').trim(), isNotEmpty,
      reason: '$id has a non-empty stem');
  final answer = question['answer'] as Map<String, dynamic>? ?? const {};
  final options = question['options'] as List<dynamic>? ?? const [];
  switch (type) {
    case 'mcq':
    case 'true_false':
      final keys =
          (answer['keys'] as List<dynamic>? ?? const []).cast<String>();
      expect(keys, hasLength(1), reason: '$id has exactly one answer key');
      final optionKeys =
          options.map((o) => (o as Map<String, dynamic>)['key']).toSet();
      for (final key in keys) {
        expect(optionKeys, contains(key), reason: '$id key $key has an option');
      }
      break;
    case 'numerical':
      expect(answer['value'], isNotNull, reason: '$id has a numeric value');
      break;
    case 'journal_entry':
      final lines = answer['journal'] as List<dynamic>? ?? const [];
      expect(lines, isNotEmpty, reason: '$id has journal lines');
      break;
    case 'fill_blank':
      final accepted = answer['accepted'] as List<dynamic>? ?? const [];
      expect(accepted, isNotEmpty, reason: '$id has accepted answers');
      break;
    default:
      break;
  }
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
