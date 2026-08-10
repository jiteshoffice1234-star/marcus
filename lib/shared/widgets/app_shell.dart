import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';

/// The five primary sections of the app.
enum AppSection {
  home('Home', Icons.home_rounded),
  learn('Learn', Icons.menu_book_rounded),
  practice('Practice', Icons.edit_note_rounded),
  simulator('Simulator', Icons.account_balance_rounded),
  profile('Profile', Icons.person_rounded);

  const AppSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Hosts the five primary sections.
///
/// Phones: bottom navigation bar. Tablets/desktop: navigation rail with the
/// content constrained to a readable column — not a stretched mobile UI.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppSpacing.tabletBreakpoint;
    return Scaffold(
      body: Row(
        children: [
          if (isWide) _Rail(navigationShell: navigationShell),
          Expanded(
            child: Column(
              children: [
                Expanded(child: navigationShell),
                if (!isWide) _BottomBar(navigationShell: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) =>
          navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      destinations: [
        for (final s in AppSection.values)
          NavigationDestination(icon: Icon(s.icon), label: s.label),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NavigationRail(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) =>
            navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Icon(Icons.account_balance_rounded,
              color: Theme.of(context).colorScheme.primary),
        ),
        destinations: [
          for (final s in AppSection.values)
            NavigationRailDestination(
              icon: Icon(s.icon),
              label: Text(s.label),
            ),
        ],
      ),
    );
  }
}
