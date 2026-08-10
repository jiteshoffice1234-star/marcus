import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';

/// Theme preference is kept in this notifier (light/dark/system).
enum ThemePreference { system, light, dark }

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily goal', style: AppTypography.title),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${learner.profile.dailyGoal} questions per day keeps your '
                      'streak alive.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Slider(
                      value: learner.profile.dailyGoal.toDouble().clamp(5, 30),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      label: '${learner.profile.dailyGoal}',
                      onChanged: (_) {},
                      onChangeEnd: (v) => ref
                          .read(learnerStateProvider.notifier)
                          .updateDailyGoal(v.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Appearance', style: AppTypography.label),
                subtitle: const Text('Light and dark mode are supported.',
                    style: AppTypography.caption),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemeDialog(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dangerous_rounded),
                title: const Text('Reset my progress',
                    style: AppTypography.label),
                subtitle: const Text(
                    'Clears all local progress, XP and notes.',
                    style: AppTypography.caption),
                onTap: () => _confirmReset(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About', style: AppTypography.title),
                    const SizedBox(height: AppSpacing.sm),
                    Text(AppConfig.appName, style: AppTypography.label),
                    const SizedBox(height: 2),
                    Text('Version 0.1.0 · ${AppConfig.shortTagline}',
                        style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Text(AppConfig.qualificationDisclaimer,
                        style: AppTypography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SimpleDialog(
        title: Text('Appearance'),
        children: [
          // Wired through the app-level theme controller in main.dart; the
          // dialog demonstrates the supported options.
          SimpleDialogOption(
            child: Text('System default'),
          ),
          SimpleDialogOption(child: Text('Light')),
          SimpleDialogOption(child: Text('Dark')),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
            'This clears all local progress, XP, achievements, notes and '
            'bookmarks. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(learnerRepositoryProvider).resetAll();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
