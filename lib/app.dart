import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/providers/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class AccountingAcademyApp extends ConsumerWidget {
  const AccountingAcademyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-run router redirects whenever the learner profile changes
    // (e.g. onboarding completes → land on the dashboard).
    ref.listen(learnerStateProvider, (_, _) {
      ref.read(routerRefreshListenableProvider).refresh();
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
