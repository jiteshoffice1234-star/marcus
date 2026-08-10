import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/test_definition.dart';
import '../../../data/repositories/learner_repository.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';

final practiceTestsProvider = FutureProvider((ref) {
  return ref.read(contentRepositoryProvider).loadTests();
});

class PracticeHomeScreen extends ConsumerWidget {
  const PracticeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    final testsAsync = ref.watch(practiceTestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _QuickPracticeCard(),
            const SizedBox(height: AppSpacing.lg),
            _WeakAreasCard(learner: learner),
            const SizedBox(height: AppSpacing.lg),
            _RevisionCard(learner: learner),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Tests',
              trailing: Text(
                '${testsAsync.valueOrNull?.length ?? 0} available',
                style: AppTypography.caption,
              ),
            ),
            testsAsync.when(
              loading: () => const LoadingView(compact: true),
              error: (e, _) => ErrorState(message: e.toString(), compact: true),
              data: (tests) => _TestsList(tests: tests),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CaseStudiesCard(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _QuickPracticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/practice/player?mode=quick&count=10'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.emerald),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick practice', style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      '10 mixed questions across the whole curriculum.',
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
}

class _WeakAreasCard extends StatelessWidget {
  const _WeakAreasCard({required this.learner});

  final LearnerState learner;

  @override
  Widget build(BuildContext context) {
    final weak = learner.weakSkillCounts;
    if (weak.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weak areas', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mistake intelligence flags these skills for focused practice.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final w in weak)
                  ActionChip(
                    avatar: Text('${w.count}'),
                    label: Text(_label(w.skill)),
                    onPressed: () =>
                        context.push('/practice/player?mode=weak&count=10'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(String skill) => switch (skill) {
        'debit_credit' => 'Debit & Credit',
        'trial_balance' => 'Trial Balance',
        'financial_statements' => 'Financial Statements',
        'tax_awareness' => 'Tax & GST',
        _ => skill.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
      };
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.learner});

  final LearnerState learner;

  @override
  Widget build(BuildContext context) {
    final due = learner.revision
        .where((r) => r.dueAt == null || !r.dueAt!.isAfter(DateTime.now()))
        .length;
    return Card(
      child: ListTile(
        leading: Icon(Icons.refresh_rounded, color: AppColors.sky),
        title: Text(
          due == 0 ? 'Smart revision' : '$due items due for revision',
          style: AppTypography.label,
        ),
        subtitle: const Text(
          'Spaced repetition: day 1 → 3 → 7 → 14 → 30.',
          style: AppTypography.caption,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/practice/player?mode=revision&count=10'),
      ),
    );
  }
}

class _TestsList extends StatelessWidget {
  const _TestsList({required this.tests});

  final List<TestDefinition> tests;

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No tests yet',
        message: 'Tests appear here once the curriculum has enough questions.',
        compact: true,
      );
    }
    // Group: mocks first, then professional, then scoped tests.
    final priority = tests.where((t) => t.kind == TestKind.caFinalMock).toList();
    final professional =
        tests.where((t) => t.kind == TestKind.professional).toList();
    final scoped = tests.where((t) =>
        t.kind == TestKind.chapter || t.kind == TestKind.level);
    final all = [...priority, ...professional, ...scoped];
    return Column(
      children: [
        for (final test in all.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: ListTile(
                leading: Icon(
                  test.kind == TestKind.caFinalMock
                      ? Icons.military_tech_rounded
                      : test.kind == TestKind.professional
                          ? Icons.work_rounded
                          : Icons.fact_check_rounded,
                  color: test.kind == TestKind.caFinalMock
                      ? AppColors.diffCaFinal
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(test.title, style: AppTypography.label),
                subtitle: Text(
                  '${test.durationMinutes} min · ${test.estimatedQuestionCount ?? test.questionIds.length} questions',
                  style: AppTypography.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/test/${test.id}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _CaseStudiesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.account_balance_rounded,
            color: AppColors.violet),
        title: const Text('Case studies & simulations',
            style: AppTypography.label),
        subtitle: const Text(
          'Run a fictional company: journalize transactions and build the statements.',
          style: AppTypography.caption,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/simulator'),
      ),
    );
  }
}
