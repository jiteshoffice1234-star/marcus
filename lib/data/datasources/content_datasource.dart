import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/curriculum.dart';
import '../models/level_meta.dart';
import '../models/question.dart';
import '../models/reference.dart';
import '../models/simulation.dart';
import '../models/test_definition.dart';

/// Abstraction over where curriculum content comes from. The MVP uses bundled
/// asset data (offline-first); a Supabase-backed implementation can be plugged
/// in later without touching feature code.
abstract interface class ContentDataSource {
  Future<CurriculumIndex> loadIndex();
  Future<LevelData> loadLevel(String levelId);
  Future<List<QuestionData>> loadAssessmentQuestions();
  Future<List<ReferenceSection>> loadReference();
  Future<List<SimulationScenario>> loadSimulations();
  Future<List<TestDefinition>> loadTests();
}

/// Reads content from bundled JSON assets with per-level lazy loading and
/// in-memory caching (never loads the entire curriculum at startup).
class AssetContentDataSource implements ContentDataSource {
  AssetContentDataSource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, dynamic> _cache = {};
  Future<CurriculumIndex>? _indexFuture;
  Future<List<QuestionData>>? _assessmentFuture;

  Future<dynamic> _loadJson(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw);
    _cache[path] = decoded;
    return decoded;
  }

  @override
  Future<CurriculumIndex> loadIndex() =>
      _indexFuture ??= _loadJson('assets/data/levels.json')
          .then((json) => CurriculumIndex.fromJson(json as Map<String, dynamic>));

  @override
  Future<LevelData> loadLevel(String levelId) async {
    final index = await loadIndex();
    final meta = index.levels.firstWhere((l) => l.id == levelId);
    final json = await _loadJson(meta.dataFile) as Map<String, dynamic>;
    // Level data files carry only `levelId` + `subjects`; the display
    // metadata lives in the index so it can be updated in one place.
    return LevelData.fromJson({
      ...json,
      'id': meta.id,
      'title': meta.title,
      'subtitle': meta.subtitle,
      'description': meta.description,
      'levelIndex': meta.levelIndex,
      'accentColor': meta.accentColor,
      'icon': meta.icon,
    });
  }

  @override
  Future<List<QuestionData>> loadAssessmentQuestions() =>
      _assessmentFuture ??= _loadJson('assets/data/assessment.json')
          .then((json) => ((json as Map<String, dynamic>)['questions']
                  as List<dynamic>)
              .map((e) => QuestionData.fromJson(e as Map<String, dynamic>))
              .toList());

  @override
  Future<List<ReferenceSection>> loadReference() => _loadJson('assets/data/reference.json')
      .then((json) => ((json as Map<String, dynamic>)['sections']
              as List<dynamic>)
          .map((e) => ReferenceSection.fromJson(e as Map<String, dynamic>))
          .toList());

  @override
  Future<List<SimulationScenario>> loadSimulations() =>
      _loadJson('assets/data/simulations.json')
          .then((json) => ((json as Map<String, dynamic>)['simulations']
                  as List<dynamic>)
              .map((e) => SimulationScenario.fromJson(e as Map<String, dynamic>))
              .toList());

  @override
  Future<List<TestDefinition>> loadTests() async {
    final index = await loadIndex();
    final tests = <TestDefinition>[];
    // Explicit tests defined in data (mocks, professional test).
    final raw = await _loadJson('assets/data/tests.json');
    for (final e in (raw as Map<String, dynamic>)['tests'] as List<dynamic>) {
      final json = e as Map<String, dynamic>;
      tests.add(TestDefinition(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        kind: TestKind.fromString(json['kind'] as String? ?? 'level'),
        levelIndex: json['levelIndex'] as int?,
        chapterId: json['chapterId'] as String?,
        topicId: json['topicId'] as String?,
        questionIds: (json['questionIds'] as List<dynamic>? ?? const [])
            .cast<String>(),
        durationMinutes: json['durationMinutes'] as int? ?? 10,
        negativeMarking: (json['negativeMarking'] as num?)?.toDouble() ?? 0,
        passPercentage: (json['passPercentage'] as num?)?.toDouble() ?? 40,
        estimatedQuestionCount: json['estimatedQuestionCount'] as int?,
        difficulty: json['difficulty'] as String?,
      ));
    }
    // Dynamic chapter tests for every chapter with questions.
    for (final levelMeta in index.levels) {
      final level = await loadLevel(levelMeta.id);
      for (final subject in level.subjects) {
        for (final chapter in subject.chapters) {
          final questions = [
            for (final topic in chapter.topics) ...topic.questions,
          ];
          if (questions.length < 3) continue;
          tests.add(TestDefinition(
            id: 'chapter_test_${chapter.id}',
            title: '${chapter.title} — Chapter Test',
            description:
                'Test your mastery of ${chapter.title} (${questions.length} questions).',
            kind: TestKind.chapter,
            levelIndex: level.levelIndex,
            chapterId: chapter.id,
            estimatedQuestionCount: questions.length,
            durationMinutes: (questions.length * 1.2).ceil().clamp(5, 60),
            negativeMarking: 0.25,
            passPercentage: 40,
          ));
        }
      }
    }
    // Dynamic level tests.
    for (final levelMeta in index.levels) {
      final level = await loadLevel(levelMeta.id);
      final questions = level.allQuestions;
      if (questions.length < 5) continue;
      tests.add(TestDefinition(
        id: 'level_test_${level.id}',
        title: '${level.title} — Level Test',
        description:
            'Comprehensive test covering ${level.title} (${questions.length} questions).',
        kind: TestKind.level,
        levelIndex: level.levelIndex,
        estimatedQuestionCount: questions.length,
        durationMinutes: (questions.length * 1.2).ceil().clamp(10, 90),
        negativeMarking: 0.25,
        passPercentage: 40,
      ));
    }
    return tests;
  }
}
