import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/learner_repository.dart';
import '../../../domain/gamification/gamification.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/state_views.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    final indexAsync = ref.watch(_profileIndexProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) => indexAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (index) => _ProfileView(learner: learner, ranks: index.ranks),
        ),
      ),
    );
  }
}

final _profileIndexProvider = FutureProvider((ref) {
  return ref.read(contentRepositoryProvider).loadIndex();
});

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.learner, required this.ranks});

  final LearnerState learner;
  final List<RankDef> ranks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = learner.profile;
    final rank = rankForXp(ranks, profile.totalXp);
    final next = nextRank(ranks, profile.totalXp);
    final estimateMinutes = profile.questionsSolved + profile.lessonsCompleted * 5;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  child: Icon(Icons.person_rounded,
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName?.isNotEmpty == true
                            ? profile.fullName!
                            : 'Learner',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: 2),
                      Text(rank.title, style: AppTypography.subtitle),
                      const SizedBox(height: 4),
                      if (next != null)
                        Text(
                          '${profile.totalXp} XP · ${next.minXp - profile.totalXp} to ${next.title}',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 4 : 2;
            final width = (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                SizedBox(width: width, child: StatCard(
                  icon: Icons.gps_fixed_rounded,
                  iconColor: AppColors.emerald,
                  value: '${(profile.accuracy * 100).round()}%',
                  label: 'Accuracy',
                )),
                SizedBox(width: width, child: StatCard(
                  icon: Icons.quiz_rounded,
                  value: '${profile.questionsSolved}',
                  label: 'Questions solved',
                )),
                SizedBox(width: width, child: StatCard(
                  icon: Icons.timer_rounded,
                  value: '${estimateMinutes}m',
                  label: 'Study time',
                )),
                SizedBox(width: width, child: StatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.amber,
                  value: '${profile.currentStreak}',
                  label: 'Day streak',
                )),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: 'Skill statistics'),
        _SkillsCard(learner: learner),
        const SizedBox(height: AppSpacing.md),
        _LinksCard(learner: learner),
        const SizedBox(height: AppSpacing.lg),
        _SignOutCard(),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings', style: AppTypography.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.learner});

  final LearnerState learner;

  @override
  Widget build(BuildContext context) {
    final skills = learner.skills.values.toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    if (skills.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_rounded,
        title: 'No data yet',
        message: 'Answer some questions to build your skill profile.',
        compact: true,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            for (final skill in skills)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_skillLabel(skill.skill),
                              style: AppTypography.label),
                        ),
                        Text(
                          '${(skill.accuracy * 100).round()}%',
                          style: AppTypography.caption.copyWith(
                            color: skill.accuracy >= 0.75
                                ? AppColors.emerald
                                : skill.accuracy < 0.5
                                    ? AppColors.coral
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: LinearProgressIndicator(
                        value: skill.accuracy,
                        minHeight: 6,
                        color: skill.accuracy >= 0.75
                            ? AppColors.emerald
                            : skill.accuracy < 0.5
                                ? AppColors.coral
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.learner});

  final LearnerState learner;

  @override
  Widget build(BuildContext context) {
    final unlocked = learner.achievements.length;
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.emoji_events_rounded,
                color: AppColors.amber),
            title: const Text('Achievements', style: AppTypography.label),
            subtitle: Text('$unlocked unlocked',
                style: AppTypography.caption),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/achievements'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_rounded),
            title: const Text('Notes', style: AppTypography.label),
            subtitle: Text('${learner.notes.length} saved',
                style: AppTypography.caption),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/notes'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bookmark_rounded),
            title: const Text('Bookmarks', style: AppTypography.label),
            subtitle: Text('${learner.bookmarks.length} saved',
                style: AppTypography.caption),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/bookmarks'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.refresh_rounded, color: AppColors.sky),
            title: const Text('Revision history', style: AppTypography.label),
            subtitle: Text(
              '${learner.revision.length} item${learner.revision.length == 1 ? '' : 's'} in the queue',
              style: AppTypography.caption,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/practice/player?mode=revision&count=10'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.library_books_rounded),
            title: const Text('Reference library', style: AppTypography.label),
            subtitle: const Text('Rules, formulas, ratios and standards',
                style: AppTypography.caption),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/reference'),
          ),
        ),
      ],
    );
  }
}

class _SignOutCard extends ConsumerWidget {
  const _SignOutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.hasSupabase) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.logout_rounded),
        title: const Text('Sign out', style: AppTypography.label),
        onTap: () => ref.read(authControllerProvider.notifier).signOut(),
      ),
    );
  }
}

String _skillLabel(String skill) => switch (skill) {
      'debit_credit' => 'Debit & Credit',
      'trial_balance' => 'Trial Balance',
      'financial_statements' => 'Financial Statements',
      'tax_awareness' => 'Tax & GST',
      'cash_flow' => 'Cash Flow',
      _ => skill.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
    };
