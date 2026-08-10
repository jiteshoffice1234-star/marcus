import 'package:accounting_academy/domain/gamification/gamification.dart';
import 'package:accounting_academy/domain/learning/revision_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Revision engine (Day 1 → 3 → 7 → 14 → 30)', () {
    test('correct answers advance through the schedule', () {
      final now = DateTime(2026, 8, 10);
      var item = RevisionItem(
        contentId: 'q1',
        contentType: 'question',
        dueAt: now,
      );

      item = RevisionEngine.applyReview(item: item, correct: true, reviewedAt: now);
      expect(item.intervalDays, 1);
      expect(item.repetitions, 1);

      item = RevisionEngine.applyReview(item: item, correct: true, reviewedAt: now);
      expect(item.intervalDays, 3);
      expect(item.repetitions, 2);

      item = RevisionEngine.applyReview(item: item, correct: true, reviewedAt: now);
      expect(item.intervalDays, 7);
      expect(item.repetitions, 3);
      expect(item.state, RevisionState.mastered);
    });

    test('a mistake resets progress and reprioritizes', () {
      final now = DateTime(2026, 8, 10);
      var item = RevisionItem(
        contentId: 'q1',
        contentType: 'question',
        repetitions: 2,
        intervalDays: 3,
        state: RevisionState.reviewing,
        dueAt: now,
      );
      item = RevisionEngine.applyReview(item: item, correct: false, reviewedAt: now);
      expect(item.repetitions, 0);
      expect(item.intervalDays, 1);
      expect(item.state, RevisionState.learning);
      expect(item.ease, lessThan(2.5));
    });

    test('due items are ordered by due date', () {
      final now = DateTime(2026, 8, 10);
      final items = [
        RevisionItem(contentId: 'later', contentType: 'question', dueAt: now.add(const Duration(days: 2))),
        RevisionItem(contentId: 'due', contentType: 'question', dueAt: now),
        RevisionItem(contentId: 'past', contentType: 'question', dueAt: now.subtract(const Duration(days: 1))),
      ];
      final due = RevisionEngine.dueItems(items, at: now);
      expect(due.map((i) => i.contentId).toList(), ['past', 'due']);
    });
  });

  group('Streaks', () {
    test('starts a streak on first activity', () {
      final s = updateStreak(current: 0, longest: 0, now: DateTime(2026, 8, 10));
      expect(s.current, 1);
      expect(s.longest, 1);
    });

    test('extends a streak on consecutive days', () {
      final s = updateStreak(
        current: 3,
        longest: 5,
        lastActiveDate: DateTime(2026, 8, 9),
        now: DateTime(2026, 8, 10),
      );
      expect(s.current, 4);
      expect(s.longest, 5);
    });

    test('same-day activity does not double count', () {
      final s = updateStreak(
        current: 3,
        longest: 5,
        lastActiveDate: DateTime(2026, 8, 10),
        now: DateTime(2026, 8, 10),
      );
      expect(s.current, 3);
    });

    test('a gap resets the streak but keeps the longest', () {
      final s = updateStreak(
        current: 3,
        longest: 12,
        lastActiveDate: DateTime(2026, 8, 5),
        now: DateTime(2026, 8, 10),
      );
      expect(s.current, 1);
      expect(s.longest, 12);
    });
  });

  group('Ranks', () {
    const ranks = [
      RankDef(key: 'beginner', title: 'Accounting Beginner', minXp: 0),
      RankDef(key: 'bookkeeper', title: 'Bookkeeper', minXp: 500),
      RankDef(key: 'accountant', title: 'Accountant', minXp: 1500),
    ];

    test('maps XP to the highest qualifying rank', () {
      expect(rankForXp(ranks, 0).key, 'beginner');
      expect(rankForXp(ranks, 499).key, 'beginner');
      expect(rankForXp(ranks, 500).key, 'bookkeeper');
      expect(rankForXp(ranks, 2000).key, 'accountant');
    });

    test('reports the next rank', () {
      expect(nextRank(ranks, 0)!.key, 'bookkeeper');
      expect(nextRank(ranks, 2000), isNull);
    });
  });

  group('Achievements', () {
    test('unlocks first-step and accuracy achievements', () {
      final unlocked = AchievementCatalog.evaluate(const StatsSnapshot(
        questionsSolved: 60,
        correctAnswers: 56,
        currentStreak: 1,
      ));
      final slugs = unlocked.map((a) => a.slug).toSet();
      expect(slugs, contains('first_step'));
      expect(slugs, contains('accuracy_90'));
      expect(slugs, isNot(contains('hundred_questions')));
    });

    test('respects already-unlocked achievements', () {
      final unlocked = AchievementCatalog.evaluate(
        const StatsSnapshot(questionsSolved: 1),
        alreadyUnlocked: {'first_step'},
      );
      expect(unlocked.map((a) => a.slug), isNot(contains('first_step')));
    });
  });
}
