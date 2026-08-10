import 'dart:math';

import '../../../data/models/question.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/learner_repository.dart';

/// A question together with its curriculum context (for the answer experience).
class PracticeQuestion {
  const PracticeQuestion({
    required this.question,
    required this.topicTitle,
    required this.levelTitle,
  });

  final QuestionData question;
  final String topicTitle;
  final String levelTitle;
}

/// Selects questions for each practice mode. All modes are deterministic
/// except `quick` (random).
class QuestionPicker {
  QuestionPicker(this._content);

  final ContentRepository _content;
  final Random _random = Random();

  Future<List<PracticeQuestion>> pick({
    required String mode,
    String? topicId,
    required int count,
    LearnerState? learner,
  }) async {
    return switch (mode) {
      'topic' => _pickTopic(topicId, count),
      'weak' => _pickWeak(learner, count),
      'revision' => _pickRevision(learner, count),
      _ => _pickQuick(count),
    };
  }

  Future<List<PracticeQuestion>> _all() async {
    final index = await _content.loadIndex();
    final result = <PracticeQuestion>[];
    for (final meta in index.levels) {
      final level = await _content.loadLevel(meta.id);
      for (final subject in level.subjects) {
        for (final chapter in subject.chapters) {
          for (final topic in chapter.topics) {
            for (final q in topic.questions) {
              result.add(PracticeQuestion(
                question: q,
                topicTitle: topic.title,
                levelTitle: level.title,
              ));
            }
          }
        }
      }
    }
    return result;
  }

  Future<List<PracticeQuestion>> _pickTopic(String? topicId, int count) async {
    if (topicId == null) return _pickQuick(count);
    final location = await _content.findTopic(topicId);
    if (location == null) return _pickQuick(count);
    final questions = location.topic.questions
        .map((q) => PracticeQuestion(
              question: q,
              topicTitle: location.topic.title,
              levelTitle: location.level.title,
            ))
        .toList();
    questions.shuffle(_random);
    return questions.take(count).toList();
  }

  Future<List<PracticeQuestion>> _pickWeak(LearnerState? learner, int count) async {
    if (learner == null) return _pickQuick(count);
    final all = await _all();
    // 1. The learner's actual mistakes, first.
    final mistaken = learner.mistakes.values
        .where((m) => !m.resolved)
        .map((m) => m.questionId)
        .toSet();
    final byMistake = all.where((p) => mistaken.contains(p.question.id)).toList();

    // 2. Weak-skill questions to fill the quota.
    final weakSkills = <String>{
      for (final m in learner.mistakes.values)
        if (!m.resolved) m.skill,
      for (final s in learner.skills.values)
        if (s.attempts >= 3 && s.accuracy < 0.5) s.skill,
    };
    final bySkill = all
        .where((p) =>
            !byMistake.contains(p) && p.question.skills.any(weakSkills.contains))
        .toList();

    byMistake.shuffle(_random);
    bySkill.shuffle(_random);
    final picked = <PracticeQuestion>[...byMistake.take(count)];
    for (final p in bySkill) {
      if (picked.length >= count) break;
      picked.add(p);
    }
    if (picked.length < count) {
      final rest = all.where((p) => !picked.contains(p)).toList()..shuffle(_random);
      picked.addAll(rest.take(count - picked.length));
    }
    return picked;
  }

  Future<List<PracticeQuestion>> _pickRevision(
      LearnerState? learner, int count) async {
    if (learner == null) return _pickQuick(count);
    final due = learner.revision
        .where((r) => r.contentType == 'question' && (r.dueAt == null || !r.dueAt!.isAfter(DateTime.now())))
        .toList();
    if (due.isEmpty) return _pickQuick(count);
    final all = await _all();
    final byId = {for (final p in all) p.question.id: p};
    final picked = <PracticeQuestion>[];
    for (final item in due) {
      final p = byId[item.contentId];
      if (p != null) picked.add(p);
      if (picked.length >= count) break;
    }
    return picked;
  }

  Future<List<PracticeQuestion>> _pickQuick(int count) async {
    final all = await _all();
    all.shuffle(_random);
    return all.take(count).toList();
  }
}
