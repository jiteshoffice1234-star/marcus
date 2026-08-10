import 'package:accounting_academy/data/models/difficulty.dart';
import 'package:accounting_academy/data/models/question.dart';
import 'package:accounting_academy/data/repositories/learner_repository.dart';
import 'package:accounting_academy/core/storage/local_store.dart';
import 'package:accounting_academy/domain/accounting/account.dart';
import 'package:accounting_academy/domain/accounting/journal.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuestionData _mcq() => QuestionData(
      id: 'q_mcq',
      type: QuestionType.mcq,
      difficulty: Difficulty.easy,
      stem: 'Which is an asset?',
      answer: const AnswerData(keys: ['C']),
      explanation: 'Cash is an asset.',
      options: const [
        QuestionOption(key: 'A', text: 'Loan'),
        QuestionOption(key: 'B', text: 'Payable'),
        QuestionOption(key: 'C', text: 'Cash'),
        QuestionOption(key: 'D', text: 'Capital'),
      ],
      skills: ['foundation'],
    );

QuestionData _numerical() => QuestionData(
      id: 'q_num',
      type: QuestionType.numerical,
      difficulty: Difficulty.easy,
      stem: 'Capital?',
      answer: const AnswerData(
        value: '320000',
        accepted: ['3,20,000', '320000.00'],
      ),
      explanation: 'A - L = C.',
      options: const [],
      skills: ['foundation'],
    );

QuestionData _fillBlank() => QuestionData(
      id: 'q_fb',
      type: QuestionType.fillBlank,
      difficulty: Difficulty.easy,
      stem: 'Debits equal ___',
      answer: const AnswerData(accepted: ['credits', 'credit']),
      explanation: '',
      options: const [],
      skills: ['debit_credit'],
    );

QuestionData _journalQuestion() => QuestionData(
      id: 'q_journal',
      type: QuestionType.journalEntry,
      difficulty: Difficulty.intermediate,
      stem: 'Capital introduced in cash.',
      answer: const AnswerData(journalLines: [
        (account: 'Cash', side: 'debit', amount: '200000'),
        (account: 'Capital', side: 'credit', amount: '200000'),
      ]),
      explanation: '',
      options: const [],
      skills: ['journal'],
    );

void main() {
  group('Answer checking', () {
    test('MCQ correct and incorrect', () {
      expect(
        checkAnswer(_mcq(), const UserAnswer(selectedKeys: ['C'])).isCorrect,
        isTrue,
      );
      expect(
        checkAnswer(_mcq(), const UserAnswer(selectedKeys: ['A'])).isCorrect,
        isFalse,
      );
    });

    test('numerical accepts comma formatting', () {
      expect(
        checkAnswer(_numerical(), const UserAnswer(text: '3,20,000')).isCorrect,
        isTrue,
      );
      expect(
        checkAnswer(_numerical(), const UserAnswer(text: '320000')).isCorrect,
        isTrue,
      );
      expect(
        checkAnswer(_numerical(), const UserAnswer(text: '300000')).isCorrect,
        isFalse,
      );
    });

    test('fill blank is case-insensitive', () {
      expect(
        checkAnswer(_fillBlank(), const UserAnswer(text: 'Credits')).isCorrect,
        isTrue,
      );
      expect(
        checkAnswer(_fillBlank(), const UserAnswer(text: 'debits')).isCorrect,
        isFalse,
      );
    });

    test('journal entry checked by the accounting engine', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(200000)),
      ]);
      expect(
        checkAnswer(_journalQuestion(), UserAnswer(journal: entry)).isCorrect,
        isTrue,
      );
    });

    test('journal entry rejects unbalanced entries', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(150000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(200000)),
      ]);
      expect(
        checkAnswer(_journalQuestion(), UserAnswer(journal: entry)).isCorrect,
        isFalse,
      );
    });
  });

  group('Learner repository (learning loop)', () {
    late LearnerRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.create();
      repo = LearnerRepository(store);
      await repo.init();
    });

    test('records a correct answer with XP and skills', () async {
      await repo.recordAnswer(question: _mcq(), correct: true);
      final state = repo.state;
      expect(state.profile.questionsSolved, 1);
      expect(state.profile.correctAnswers, 1);
      expect(state.profile.totalXp, 5);
      expect(state.skills['foundation']!.correct, 1);
      expect(state.mistakes, isEmpty);
    });

    test('records a wrong answer as a mistake and schedules revision', () async {
      await repo.recordAnswer(question: _mcq(), correct: false);
      final state = repo.state;
      expect(state.profile.questionsSolved, 1);
      expect(state.profile.correctAnswers, 0);
      expect(state.mistakes['q_mcq']!.count, 1);
      expect(state.revision, hasLength(1));
      expect(state.revision.first.contentId, 'q_mcq');
    });

    test('increments repeated mistakes', () async {
      await repo.recordAnswer(question: _mcq(), correct: false);
      await repo.recordAnswer(question: _mcq(), correct: false);
      expect(repo.state.mistakes['q_mcq']!.count, 2);
    });

    test('resolving a mistake in revision increases the counter', () async {
      await repo.recordAnswer(question: _mcq(), correct: false);
      await repo.reviewRevision(contentId: 'q_mcq', correct: true);
      expect(repo.state.mistakes['q_mcq']!.resolved, isTrue);
      expect(repo.state.profile.mistakesResolved, 1);
    });

    test('completing a lesson awards XP', () async {
      await repo.completeLesson();
      expect(repo.state.profile.lessonsCompleted, 1);
      expect(repo.state.profile.totalXp, 20);
    });

    test('streak starts on first activity', () async {
      await repo.recordActivity(at: DateTime(2026, 8, 10));
      expect(repo.state.profile.currentStreak, 1);
    });

    test('persists and reloads state', () async {
      await repo.recordAnswer(question: _mcq(), correct: true);
      final repo2 = LearnerRepository(
          LocalStore(await SharedPreferences.getInstance(), namespace: 'aa'));
      await repo2.init();
      expect(repo2.state.profile.questionsSolved, 1);
      expect(repo2.state.profile.totalXp, 5);
    });
  });
}
