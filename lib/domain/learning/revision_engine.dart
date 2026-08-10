import '../../../core/config/app_config.dart';

enum RevisionState { newItem, learning, reviewing, mastered }

/// A single item in the learner's revision queue.
class RevisionItem {
  RevisionItem({
    required this.contentId,
    required this.contentType,
    this.skillKey,
    this.state = RevisionState.newItem,
    this.repetitions = 0,
    this.ease = 2.5,
    this.intervalDays = 1,
    DateTime? dueAt,
  }) : dueAt = dueAt ?? DateTime.now();

  final String contentId;

  /// 'question' | 'lesson' | 'topic'
  final String contentType;
  final String? skillKey;

  RevisionState state;
  int repetitions;

  /// Memory-stability factor (SuperMemo-style); min 1.3.
  double ease;
  int intervalDays;
  DateTime dueAt;

  bool get isDue => !dueAt.isAfter(DateTime.now());

  RevisionItem copy() => RevisionItem(
        contentId: contentId,
        contentType: contentType,
        skillKey: skillKey,
        state: state,
        repetitions: repetitions,
        ease: ease,
        intervalDays: intervalDays,
        dueAt: dueAt,
      );
}

/// Implements the Day 1 → 3 → 7 → 14 → 30 schedule with adjustment:
///  * correct answers advance through the schedule and grow `ease`;
///  * a mistake resets progress and shortens the interval so the item
///    resurfaces sooner (higher revision priority);
///  * consistent mastery gradually reduces review frequency.
class RevisionEngine {
  RevisionEngine._();

  static const List<int> schedule = AppConfig.revisionScheduleDays;

  /// Produces the next state after a review. Pure — no clock, fully testable.
  static RevisionItem applyReview({
    required RevisionItem item,
    required bool correct,
    DateTime? reviewedAt,
  }) {
    final now = reviewedAt ?? DateTime.now();
    final next = item.copy();

    if (correct) {
      next.repetitions += 1;
      next.ease = (next.ease + 0.1).clamp(1.3, 3.0);
      final idx = (next.repetitions - 1).clamp(0, schedule.length - 1);
      next.intervalDays = schedule[idx];
      next.state = next.repetitions >= 3
          ? RevisionState.mastered
          : next.repetitions >= 1
              ? RevisionState.reviewing
              : RevisionState.learning;
    } else {
      // Mistake: reset progress and prioritize — due again tomorrow (or sooner).
      next.repetitions = 0;
      next.ease = (next.ease - 0.2).clamp(1.3, 3.0);
      next.intervalDays = 1;
      next.state = RevisionState.learning;
    }

    next.dueAt = now.add(Duration(days: next.intervalDays));
    return next;
  }

  /// A convenience for "due today" queries.
  static List<RevisionItem> dueItems(List<RevisionItem> items, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return items.where((i) => !i.dueAt.isAfter(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }
}
