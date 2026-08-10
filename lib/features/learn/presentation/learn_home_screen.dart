import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/level_meta.dart';
import '../../../shared/widgets/state_views.dart';
import 'level_screen.dart';

final levelIndexProvider = FutureProvider((ref) {
  return ref.read(contentRepositoryProvider).loadIndex();
});

class LearnHomeScreen extends ConsumerWidget {
  const LearnHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelIndexProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: levelsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (index) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'The curriculum',
              style: AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Four levels from accounting zero to CA Final-level reporting.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final level in index.levels)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _LevelCard(level: level),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              index.disclaimer,
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level});

  final LevelMeta level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => context.push(
          LevelScreen.route(level.id),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  _iconFor(level.icon),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEVEL ${level.levelIndex}',
                      style: AppTypography.overline.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(level.title, style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      level.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String icon) => switch (icon) {
        'professional' => Icons.work_rounded,
        'advanced' => Icons.insights_rounded,
        'ca_final' => Icons.military_tech_rounded,
        _ => Icons.psychology_rounded,
      };
}
