import '../datasources/content_datasource.dart';
import '../models/curriculum.dart';
import '../models/level_meta.dart';
import '../models/question.dart';
import '../models/reference.dart';
import '../models/simulation.dart';
import '../models/test_definition.dart';

/// A topic's full position in the curriculum tree.
class TopicLocation {
  const TopicLocation({
    required this.level,
    required this.subject,
    required this.chapter,
    required this.topic,
  });

  final LevelData level;
  final SubjectData subject;
  final ChapterData chapter;
  final TopicData topic;
}

/// A single search hit across the curriculum.
class SearchHit {
  const SearchHit({
    required this.title,
    required this.subtitle,
    required this.type, // 'lesson' | 'topic' | 'concept' | 'reference'
    required this.levelId,
    required this.topicId,
    this.lessonId,
  });

  final String title;
  final String subtitle;
  final String type;
  final String levelId;
  final String topicId;
  final String? lessonId;
}

/// Facade over [ContentDataSource] with per-level caching and a fast local
/// search index built lazily from loaded levels.
class ContentRepository {
  ContentRepository(this._source);

  final ContentDataSource _source;
  final Map<String, LevelData> _levelCache = {};

  Future<CurriculumIndex> loadIndex() => _source.loadIndex();

  Future<LevelData> loadLevel(String levelId) async {
    final cached = _levelCache[levelId];
    if (cached != null) return cached;
    final level = await _source.loadLevel(levelId);
    _levelCache[levelId] = level;
    return level;
  }

  Future<List<QuestionData>> loadAssessmentQuestions() =>
      _source.loadAssessmentQuestions();

  Future<List<ReferenceSection>> loadReference() => _source.loadReference();

  Future<List<SimulationScenario>> loadSimulations() => _source.loadSimulations();

  Future<List<TestDefinition>> loadTests() => _source.loadTests();

  /// Question lookup used by mistake/revision flows.
  Future<QuestionData?> findQuestion(String questionId) async {
    final index = await loadIndex();
    for (final meta in index.levels) {
      final level = await loadLevel(meta.id);
      for (final q in level.allQuestions) {
        if (q.id == questionId) return q;
      }
    }
    return null;
  }

  /// Full location of a topic within the curriculum (level/subject/chapter).
  Future<TopicLocation?> findTopic(String topicId) async {
    final index = await loadIndex();
    for (final meta in index.levels) {
      final level = await loadLevel(meta.id);
      for (final subject in level.subjects) {
        for (final chapter in subject.chapters) {
          for (final topic in chapter.topics) {
            if (topic.id == topicId) {
              return TopicLocation(
                level: level,
                subject: subject,
                chapter: chapter,
                topic: topic,
              );
            }
          }
        }
      }
    }
    return null;
  }

  Future<TopicLocation?> findChapter(String chapterId) async {
    final index = await loadIndex();
    for (final meta in index.levels) {
      final level = await loadLevel(meta.id);
      for (final subject in level.subjects) {
        for (final chapter in subject.chapters) {
          if (chapter.id == chapterId) {
            if (chapter.topics.isEmpty) return null;
            return TopicLocation(
              level: level,
              subject: subject,
              chapter: chapter,
              topic: chapter.topics.first,
            );
          }
        }
      }
    }
    return null;
  }

  /// Builds a search index over everything loaded so far. Levels are loaded
  /// lazily, so the first search for an unloaded level loads it on demand.
  Future<List<SearchHit>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final hits = <SearchHit>[];
    final index = await loadIndex();
    for (final meta in index.levels) {
      final level = await loadLevel(meta.id);
      for (final subject in level.subjects) {
        for (final chapter in subject.chapters) {
          for (final topic in chapter.topics) {
            final titleMatch = topic.title.toLowerCase().contains(q);
            final descMatch = topic.description.toLowerCase().contains(q);
            final lesson = topic.lesson;
            if (titleMatch || descMatch) {
              hits.add(SearchHit(
                title: topic.title,
                subtitle: '${level.title} · ${chapter.title}',
                type: 'topic',
                levelId: level.id,
                topicId: topic.id,
              ));
            }
            if (lesson != null &&
                (lesson.title.toLowerCase().contains(q) ||
                    lesson.summary.toLowerCase().contains(q))) {
              hits.add(SearchHit(
                title: lesson.title,
                subtitle: '${level.title} · ${topic.title}',
                type: 'lesson',
                levelId: level.id,
                topicId: topic.id,
                lessonId: lesson.id,
              ));
            }
          }
        }
      }
    }
    return hits;
  }
}
