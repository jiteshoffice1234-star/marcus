import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/reference.dart';
import '../../../shared/widgets/state_views.dart';

final referenceProvider = FutureProvider((ref) {
  return ref.read(contentRepositoryProvider).loadReference();
});

class ReferenceScreen extends ConsumerWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referenceAsync = ref.watch(referenceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reference Library')),
      body: referenceAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (sections) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Rules, formulas, ratios and standards — updated independently '
              'of the app.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in sections)
              _SectionCard(section: section),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final ReferenceSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        child: ExpansionTile(
          title: Text(section.title, style: AppTypography.label),
          subtitle: Text(section.description, style: AppTypography.caption),
          children: [
            for (final item in section.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTypography.subtitle),
                    const SizedBox(height: AppSpacing.xs),
                    if (item.formula != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.green600.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Text(
                          item.formula!,
                          style: AppTypography.label.copyWith(
                            color: AppColors.green800,
                          ),
                        ),
                      ),
                    Text(item.body, style: AppTypography.bodySmall),
                    const Divider(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
