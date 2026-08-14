import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/simulation.dart';
import '../../../shared/widgets/state_views.dart';

final simulationsProvider = FutureProvider((ref) {
  return ref.read(contentRepositoryProvider).loadSimulations();
});

class SimulatorHomeScreen extends ConsumerWidget {
  const SimulatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationsAsync = ref.watch(simulationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulator')),
      body: simulationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (simulations) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Run a real company\'s books', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You receive business transactions for a fictional company and '
              'perform the accounting yourself: journal → ledger → trial balance '
              '→ adjustments → P&L → balance sheet. The system checks your work '
              'and explains every error.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final scenario in simulations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _ScenarioCard(scenario: scenario),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final SimulationScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/simulator/${scenario.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.green600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.apartment_rounded,
                        color: AppColors.green700),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scenario.companyName,
                            style: AppTypography.title),
                        Text(scenario.industry,
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(scenario.title, style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(scenario.description, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  Chip(
                    avatar: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(
                        '${scenario.transactions.length} transactions'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.trending_up_rounded, size: 16),
                    label: Text('Level ${scenario.levelIndex}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
