import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/curriculum.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/learner_repository.dart';
import '../../../domain/gamification/gamification.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/state_views.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: 'Ask the accounting tutor',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push('/ai-tutor'),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (state) => _Dashboard(state: state),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.state});

  final LearnerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentRepositoryProvider);
    final dataAsync = ref.watch(_dashboardDataProvider);

    return dataAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (data) {
        final rank = rankForXp(data.index.ranks, state.profile.totalXp);
        final levelMeta = data.index.levels
            .where((l) => l.levelIndex == state.profile.startingLevelIndex)
            .firstOrNull;
        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _JourneyCard(
                rankTitle: rank.title,
                levelTitle: levelMeta?.title ?? 'Accounting Foundation',
                progress: data.totalLessons == 0
                    ? 0
                    : (state.profile.lessonsCompleted / data.totalLessons)
                        .clamp(0.0, 1.0),
                nextRank: nextRank(data.index.ranks, state.profile.totalXp),
                xp: state.profile.totalXp,
                onViewProgress: () => context.go('/profile'),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 600 ? 4 : 2;
                  final width = (constraints.maxWidth -
                          AppSpacing.lg * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppColors.amber,
                          value: '${state.profile.currentStreak}',
                          label: 'Day streak',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.gps_fixed_rounded,
                          iconColor: AppColors.emerald,
                          value: '${(state.profile.accuracy * 100).round()}%',
                          label: 'Accuracy',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.quiz_rounded,
                          value: '${state.profile.questionsSolved}',
                          label: 'Questions solved',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.flag_rounded,
                          value: '${state.profile.lessonsCompleted}',
                          label: 'Lessons done',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _SkillFocusRow(state: state),
              const SizedBox(height: AppSpacing.lg),
              _ContinueCard(
                levelIndex: state.profile.startingLevelIndex,
                content: content,
              ),
              const SizedBox(height: AppSpacing.lg),
              _RevisionCard(state: state),
              const SizedBox(height: AppSpacing.lg),
              _PerformanceCard(state: state),
              const SizedBox(height: AppSpacing.lg),
              _UpcomingCard(levelIndex: state.profile.startingLevelIndex),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

/// Dashboard metrics: curriculum index + total lesson count (loaded lazily).
final _dashboardDataProvider = FutureProvider((ref) async {
  final content = ref.read(contentRepositoryProvider);
  final index = await content.loadIndex();
  var totalLessons = 0;
  for (final meta in index.levels) {
    totalLessons += (await content.loadLevel(meta.id)).lessonCount;
  }
  return (index: index, totalLessons: totalLessons);
});

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.rankTitle,
    required this.levelTitle,
    required this.progress,
    this.nextRank,
    this.xp = 0,
    this.onViewProgress,
  });

  final String rankTitle;
  final String levelTitle;
  final double progress;
  final RankDef? nextRank;
  final int xp;
  final VoidCallback? onViewProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACCOUNTING JOURNEY', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rank', style: AppTypography.caption),
                      const SizedBox(height: 2),
                      Text(rankTitle, style: AppTypography.title),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Level', style: AppTypography.caption),
                      const SizedBox(height: 2),
                      Text(levelTitle, style: AppTypography.subtitle),
                      const SizedBox(height: AppSpacing.sm),
                      if (nextRank != null)
                        Text(
                          '$xp XP · ${nextRank!.minXp - xp} XP to ${nextRank!.title}',
                          style: AppTypography.figures.copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                ProgressRing(
                  progress: progress,
                  size: 84,
                  color: scheme.primary,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: AppTypography.label.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      Text('done', style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillFocusRow extends StatelessWidget {
  const _SkillFocusRow({required this.state});

  final LearnerState state;

  @override
  Widget build(BuildContext context) {
    final mastered = state.skills.values.toList();
    if (mastered.isEmpty) {
      return const SizedBox.shrink();
    }
    mastered.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final weakest = mastered.first;
    final strongest = mastered.last;
    return Row(
      children: [
        Expanded(
          child: _FocusTile(
            label: 'Weak area',
            value: skillLabel(weakest.skill),
            color: AppColors.coral,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _FocusTile(
            label: 'Strong area',
            value: skillLabel(strongest.skill),
            color: AppColors.emerald,
          ),
        ),
      ],
    );
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTypography.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.levelIndex, required this.content});

  final int levelIndex;
  final ContentRepository content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _resolveNext(),
      builder: (context, snapshot) {
        final title = snapshot.data?.title ?? 'Your first topic';
        final topicId = snapshot.data?.id ?? '';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT', style: AppTypography.overline),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.title.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  snapshot.data == null
                      ? 'Continue your personalized roadmap.'
                      : 'Recommended next lesson based on your progress.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: topicId.isEmpty
                        ? null
                        : () => context.push('/learn/topic/$topicId'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('CONTINUE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<TopicData?> _resolveNext() async {
    try {
      final index = await content.loadIndex();
      final meta = index.levels
          .where((l) => l.levelIndex == levelIndex)
          .firstOrNull;
      if (meta == null) return null;
      final level = await content.loadLevel(meta.id);
      return level.subjects.firstOrNull?.chapters.firstOrNull?.topics.firstOrNull;
    } catch (_) {
      return null;
    }
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.state});

  final LearnerState state;

  @override
  Widget build(BuildContext context) {
    final due = state.revision.where((r) => r.dueAt == null || !r.dueAt!.isAfter(DateTime.now())).length;
    if (due == 0) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: Icon(Icons.refresh_rounded,
            color: AppColors.sky),
        title: Text('$due revision item${due == 1 ? '' : 's'} due',
            style: AppTypography.label),
        subtitle: const Text(
          'Spaced repetition keeps your knowledge fresh.',
          style: AppTypography.caption,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/practice/player?mode=revision&count=10'),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.state});

  final LearnerState state;

  @override
  Widget build(BuildContext context) {
    final days = _last7Days(state);
    if (days.isEmpty) return const SizedBox.shrink();
    final maxCount = days.fold<int>(1, (m, d) => d.correct > m ? d.correct : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent performance', style: AppTypography.title),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              day.correct == 0 && day.total == 0
                                  ? '–'
                                  : '${day.correct}',
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: day.total == 0
                                  ? 3
                                  : (90 - 34) * (day.correct / maxCount),
                              decoration: BoxDecoration(
                                color: day.total == 0
                                    ? Theme.of(context).colorScheme.outline
                                    : AppColors.emerald,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weekdayLabel(day.day),
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
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

  List<({DateTime day, int correct, int total})> _last7Days(LearnerState state) {
    final today = DateTime.now();
    final result = <({DateTime day, int correct, int total})>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final attempts = state.attempts
          .where((a) =>
              a.answeredAt.year == day.year &&
              a.answeredAt.month == day.month &&
              a.answeredAt.day == day.day)
          .toList();
      result.add((
        day: day,
        correct: attempts.where((a) => a.correct).length,
        total: attempts.length,
      ));
    }
    return result;
  }

  String _weekdayLabel(DateTime day) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[day.weekday - 1];
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.levelIndex});

  final int levelIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.fact_check_rounded,
            color: AppColors.violet),
        title: const Text('Test yourself',
            style: AppTypography.label),
        subtitle: const Text(
          'Chapter and level tests with timed, exam-style conditions.',
          style: AppTypography.caption,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/practice'),
      ),
    );
  }
}

String skillLabel(String skill) => switch (skill) {
      'debit_credit' => 'Debit & Credit',
      'trial_balance' => 'Trial Balance',
      'financial_statements' => 'Financial Statements',
      'tax_awareness' => 'Tax & GST',
      _ => _titleCase(skill),
    };

String _titleCase(String s) => s.isEmpty
    ? s
    : s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
