import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/curriculum.dart';
import '../../../data/models/learner.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/state_views.dart';

final topicLocationProvider =
    FutureProvider.family((ref, String topicId) {
  return ref.read(contentRepositoryProvider).findTopic(topicId);
});

class TopicScreen extends ConsumerWidget {
  const TopicScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(topicLocationProvider(topicId));
    final learnerAsync = ref.watch(learnerStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson'),
        actions: [
          IconButton(
            tooltip: 'Ask the tutor',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push('/ai-tutor?topicId=$topicId'),
          ),
        ],
      ),
      body: locationAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (location) {
          if (location == null) {
            return const ErrorState(message: 'Lesson not found.');
          }
          return learnerAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (learner) => _TopicView(
              location: location,
              isBookmarked: learner.bookmarks.any(
                (b) => b.contentType == 'topic' && b.contentId == location.topic.id,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopicView extends ConsumerWidget {
  const _TopicView({required this.location, required this.isBookmarked});

  final TopicLocation location;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = location.topic;
    final lesson = topic.lesson;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '${location.level.title} · ${location.chapter.title}',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(topic.title, style: AppTypography.headline)),
            IconButton(
              tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
              icon: Icon(
                isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isBookmarked ? AppColors.amber : null,
              ),
              onPressed: () {
                final notifier = ref.read(learnerStateProvider.notifier);
                if (isBookmarked) {
                  notifier.removeBookmark('topic', topic.id);
                } else {
                  notifier.addBookmark(BookmarkRecord(
                    contentType: 'topic',
                    contentId: topic.id,
                    title: topic.title,
                  ));
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (lesson != null) ...[
          _LessonContent(lesson: lesson),
          const SizedBox(height: AppSpacing.xl),
        ],
        _PracticeSection(topic: topic),
        const SizedBox(height: AppSpacing.xl),
        if (lesson != null)
          FilledButton.icon(
            onPressed: () async {
              final unlocked =
                  await ref.read(learnerStateProvider.notifier).completeLesson();
              if (!context.mounted) return;
              if (unlocked.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Lesson complete! +20 XP · Achievement unlocked: ${unlocked.first.title}',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lesson complete! +20 XP')),
                );
              }
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Mark lesson complete'),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _LessonContent extends StatelessWidget {
  const _LessonContent({required this.lesson});

  final LessonData lesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lesson.title, style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${lesson.estimatedMinutes} min read',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final section in lesson.sections)
          _SectionBlock(section: section),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final LessonSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (section.type) {
      'concept' => Icons.lightbulb_rounded,
      'example' => Icons.assignment_rounded,
      'worked_solution' => Icons.calculate_rounded,
      'common_mistakes' => Icons.warning_amber_rounded,
      'formula' => Icons.functions_rounded,
      _ => Icons.article_rounded,
    };
    final isFormula = section.type == 'formula';
    final isMistake = section.type == 'common_mistakes';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isMistake
                      ? AppColors.coral
                      : scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(section.heading, style: AppTypography.subtitle),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isFormula && section.formula != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                section.formula!,
                style: AppTypography.title.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          Text(section.body, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _PracticeSection extends StatelessWidget {
  const _PracticeSection({required this.topic});

  final TopicData topic;

  @override
  Widget build(BuildContext context) {
    final questions = topic.questions;
    if (questions.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Practice', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${questions.length} question${questions.length == 1 ? '' : 's'} · MCQ, numerical, true/false and journal entries.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/practice/player?topicId=${topic.id}&mode=topic&count=${questions.length}',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Practice this topic'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
