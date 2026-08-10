import 'assessment_engine.dart';

/// A topic the learner should study next, with the reason it was chosen.
class RoadmapItem {
  const RoadmapItem({
    required this.topicId,
    required this.levelIndex,
    required this.reason,
    this.isPriority = false,
  });

  final String topicId;
  final int levelIndex;
  final String reason;
  final bool isPriority;

  @override
  String toString() => '$topicId (level $levelIndex): $reason';
}

/// Input describing one level of the curriculum (enough for roadmap planning).
class RoadmapLevelInput {
  const RoadmapLevelInput({
    required this.levelIndex,
    required this.topics,
  });

  final int levelIndex;

  /// Topics in curriculum order; each is a (topicId, skills) pair.
  final List<({String topicId, List<String> skills})> topics;
}

/// Builds a personalized roadmap:
///
/// 1. Topics matching the learner's weak skills are pulled to the front
///    (revision-first so mistakes stop compounding).
/// 2. The remaining curriculum from the recommended level onwards follows in
///    order, so a strong learner is never forced back to Level 1.
class RoadmapBuilder {
  RoadmapBuilder._();

  static List<RoadmapItem> build({
    required AssessmentResult assessment,
    required List<RoadmapLevelInput> levels,
  }) {
    final weakSkills = assessment.weakSkills.map((s) => s.skill).toSet();
    if (weakSkills.isEmpty && assessment.accuracy >= 0.7) {
      // No weak spots — pure forward path.
      return _forwardPath(levels, assessment.recommendedLevelIndex);
    }

    final prioritized = <RoadmapItem>[];
    final seen = <String>{};

    for (final level in levels) {
      for (final topic in level.topics) {
        final intersects = topic.skills.any(weakSkills.contains);
        if (!intersects) continue;
        seen.add(topic.topicId);
        prioritized.add(RoadmapItem(
          topicId: topic.topicId,
          levelIndex: level.levelIndex,
          reason: _reasonForWeakTopic(topic.skills, weakSkills),
          isPriority: true,
        ));
      }
    }

    final rest = _forwardPath(levels, assessment.recommendedLevelIndex)
        .where((item) => !seen.contains(item.topicId))
        .toList();

    return [...prioritized, ...rest];
  }

  static List<RoadmapItem> _forwardPath(
    List<RoadmapLevelInput> levels,
    int startLevel,
  ) {
    final items = <RoadmapItem>[];
    for (final level in levels.where((l) => l.levelIndex >= startLevel)) {
      for (final topic in level.topics) {
        items.add(RoadmapItem(
          topicId: topic.topicId,
          levelIndex: level.levelIndex,
          reason: 'Level ${level.levelIndex} curriculum',
        ));
      }
    }
    return items;
  }

  static String _reasonForWeakTopic(
    List<String> topicSkills,
    Set<String> weakSkills,
  ) {
    final hit = topicSkills.where(weakSkills.contains).toList();
    return 'Weak area: ${hit.map(skillLabel).join(', ')}';
  }
}
