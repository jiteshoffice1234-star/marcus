import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/gamification/gamification.dart';
import '../../../shared/widgets/state_views.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) {
          final unlocked = AchievementCatalog.all
              .where((a) => learner.achievements.contains(a.slug))
              .toList();
          final locked = AchievementCatalog.all
              .where((a) => !learner.achievements.contains(a.slug))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${unlocked.length} of ${AchievementCatalog.all.length} unlocked',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Unlocked', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              for (final a in unlocked)
                _AchievementTile(achievement: a, unlocked: true),
              const SizedBox(height: AppSpacing.lg),
              Text('To unlock', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              for (final a in locked)
                _AchievementTile(achievement: a, unlocked: false),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final AchievementDef achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.amber.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.amber : null,
              size: 20,
            ),
          ),
          title: Text(achievement.title,
              style: unlocked ? AppTypography.label : AppTypography.label),
          subtitle: Text(
            achievement.description,
            style: AppTypography.bodySmall,
          ),
          trailing: unlocked
              ? Text('+${achievement.xpReward} XP',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.emerald))
              : null,
        ),
      ),
    );
  }
}
