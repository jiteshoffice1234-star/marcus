import '../../domain/gamification/gamification.dart';

/// Lightweight metadata for a level — loaded from the levels index without
/// pulling the full curriculum (lazy loading requirement).
class LevelMeta {
  const LevelMeta({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.levelIndex,
    required this.accentColor,
    required this.icon,
    required this.dataFile,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final int levelIndex;
  final String accentColor;
  final String icon;
  final String dataFile;

  factory LevelMeta.fromJson(Map<String, dynamic> json) => LevelMeta(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        description: json['description'] as String? ?? '',
        levelIndex: json['levelIndex'] as int? ?? 1,
        accentColor: json['accentColor'] as String? ?? '#2E7D32',
        icon: json['icon'] as String? ?? '',
        dataFile: json['dataFile'] as String? ?? '',
      );
}

/// The curriculum index: level metadata + ranks + qualification disclaimer.
class CurriculumIndex {
  const CurriculumIndex({
    required this.levels,
    required this.ranks,
    required this.disclaimer,
  });

  final List<LevelMeta> levels;
  final List<RankDef> ranks;
  final String disclaimer;

  factory CurriculumIndex.fromJson(Map<String, dynamic> json) =>
      CurriculumIndex(
        levels: (json['levels'] as List<dynamic>? ?? const [])
            .map((e) => LevelMeta.fromJson(e as Map<String, dynamic>))
            .toList(),
        ranks: (json['ranks'] as List<dynamic>? ?? const [])
            .map((e) => RankDef(
                  key: (e as Map<String, dynamic>)['key'] as String,
                  title: e['title'] as String,
                  minXp: e['minXp'] as int,
                ))
            .toList(),
        disclaimer: json['disclaimer'] as String? ?? '',
      );
}
