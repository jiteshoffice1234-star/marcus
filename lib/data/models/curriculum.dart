import '../../domain/assessment/roadmap_builder.dart';
import 'question.dart';

/// A section inside a lesson body (concept, example, formula, etc.).
class LessonSection {
  const LessonSection({
    required this.type,
    required this.heading,
    required this.body,
    this.formula,
  });

  final String type;
  final String heading;
  final String body;
  final String? formula;

  factory LessonSection.fromJson(Map<String, dynamic> json) => LessonSection(
        type: json['type'] as String? ?? 'concept',
        heading: json['heading'] as String? ?? '',
        body: json['body'] as String? ?? '',
        formula: json['formula'] as String?,
      );
}

class LessonData {
  const LessonData({
    required this.id,
    required this.title,
    required this.summary,
    required this.sections,
    this.estimatedMinutes = 5,
  });

  final String id;
  final String title;
  final String summary;
  final List<LessonSection> sections;
  final int estimatedMinutes;

  factory LessonData.fromJson(Map<String, dynamic> json) => LessonData(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        sections: (json['sections'] as List<dynamic>? ?? const [])
            .map((e) => LessonSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
      );
}

class TopicData {
  const TopicData({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.lesson,
    this.questions = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final LessonData? lesson;
  final List<QuestionData> questions;

  factory TopicData.fromJson(Map<String, dynamic> json) => TopicData(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        lesson: json['lesson'] == null
            ? null
            : LessonData.fromJson(json['lesson'] as Map<String, dynamic>),
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .map((e) => QuestionData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<String> get skills {
    final skills = <String>{};
    for (final q in questions) {
      skills.addAll(q.skills);
    }
    return skills.toList();
  }
}

class ChapterData {
  const ChapterData({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.topics = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final List<TopicData> topics;

  factory ChapterData.fromJson(Map<String, dynamic> json) => ChapterData(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        topics: (json['topics'] as List<dynamic>? ?? const [])
            .map((e) => TopicData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get lessonCount => topics.where((t) => t.lesson != null).length;
}

class SubjectData {
  const SubjectData({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.chapters = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final List<ChapterData> chapters;

  factory SubjectData.fromJson(Map<String, dynamic> json) => SubjectData(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        chapters: (json['chapters'] as List<dynamic>? ?? const [])
            .map((e) => ChapterData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LevelData {
  const LevelData({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.levelIndex,
    required this.accentColor,
    required this.icon,
    this.subjects = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final int levelIndex;
  final String accentColor;
  final String icon;
  final List<SubjectData> subjects;

  factory LevelData.fromJson(Map<String, dynamic> json) => LevelData(
        id: json['id'] as String? ?? json['levelId'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        description: json['description'] as String? ?? '',
        levelIndex: json['levelIndex'] as int? ?? 1,
        accentColor: json['accentColor'] as String? ?? '#2E7D32',
        icon: json['icon'] as String? ?? '',
        subjects: (json['subjects'] as List<dynamic>? ?? const [])
            .map((e) => SubjectData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get topicCount {
    var count = 0;
    for (final s in subjects) {
      for (final c in s.chapters) {
        count += c.topics.length;
      }
    }
    return count;
  }

  int get lessonCount {
    var count = 0;
    for (final s in subjects) {
      for (final c in s.chapters) {
        count += c.lessonCount;
      }
    }
    return count;
  }

  /// All topics flattened with their skills, in curriculum order — feeds the
  /// roadmap builder.
  RoadmapLevelInput toRoadmapInput() => RoadmapLevelInput(
        levelIndex: levelIndex,
        topics: [
          for (final s in subjects)
            for (final c in s.chapters)
              for (final t in c.topics)
                (topicId: t.id, skills: t.skills),
        ],
      );

  /// All questions in this level.
  List<QuestionData> get allQuestions => [
        for (final s in subjects)
          for (final c in s.chapters)
            for (final t in c.topics) ...t.questions,
      ];
}
