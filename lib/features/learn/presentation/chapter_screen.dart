import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';

final chapterLocationProvider =
    FutureProvider.family((ref, String chapterId) {
  return ref.read(contentRepositoryProvider).findChapter(chapterId);
});

class ChapterScreen extends ConsumerWidget {
  const ChapterScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(chapterLocationProvider(chapterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chapter')),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (location) {
          if (location == null) {
            return const ErrorState(message: 'Chapter not found.');
          }
          final chapter = location.chapter;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${location.level.title} · ${location.subject.title}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(chapter.title, style: AppTypography.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(chapter.description, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              for (final topic in chapter.topics)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.menu_book_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title:
                          Text(topic.title, style: AppTypography.label),
                      subtitle: Text(
                        '${topic.lesson == null ? '' : '${topic.lesson!.estimatedMinutes} min · '}${topic.questions.length} practice question${topic.questions.length == 1 ? '' : 's'}',
                        style: AppTypography.caption,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/learn/topic/${topic.id}'),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/test/chapter_test_${chapter.id}'),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('Chapter test'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}
