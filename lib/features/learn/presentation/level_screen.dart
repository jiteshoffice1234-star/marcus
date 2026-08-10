import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/curriculum.dart';
import '../../../shared/widgets/state_views.dart';

final levelProvider =
    FutureProvider.family((ref, String levelId) {
  return ref.read(contentRepositoryProvider).loadLevel(levelId);
});

class LevelScreen extends ConsumerWidget {
  const LevelScreen({super.key, required this.levelId});

  final String levelId;

  static String route(String levelId) => '/learn/level/$levelId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(levelProvider(levelId));
    return Scaffold(
      appBar: AppBar(title: const Text('Level')),
      body: levelAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (level) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(level.title, style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(level.description, style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            for (final subject in level.subjects)
              _SubjectCard(subject: subject, level: level),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.level});

  final SubjectData subject;
  final LevelData level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject.title, style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(subject.description, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final chapter in subject.chapters)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: ListTile(
                  title: Text(chapter.title, style: AppTypography.label),
                  subtitle: Text(
                    '${chapter.topics.length} topic${chapter.topics.length == 1 ? '' : 's'} · ${chapter.lessonCount} lesson${chapter.lessonCount == 1 ? '' : 's'}',
                    style: AppTypography.caption,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/learn/chapter/${chapter.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
