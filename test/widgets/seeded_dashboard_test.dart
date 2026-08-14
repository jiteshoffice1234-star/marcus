import 'package:accounting_academy/app.dart';
import 'package:accounting_academy/core/providers/providers.dart';
import 'package:accounting_academy/core/storage/local_store.dart';
import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/data/sync/sync_engine.dart';
import 'package:accounting_academy/features/auth/data/local_auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'dashboard renders with an all-wrong assessment profile (level 1, 0 XP)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.aa.profile':
          '{"fullName":null,"email":null,"onboarded":true,"assessmentTaken":true,'
              '"startingLevelIndex":1,"dailyGoal":10,"totalXp":0,"questionsSolved":0,'
              '"correctAnswers":0,"lessonsCompleted":0,"testsCompleted":0,'
              '"mistakesResolved":0,"levelsCompleted":0,"currentStreak":1,'
              '"longestStreak":1,"lastActiveDate":"2026-08-14T18:10:10.061Z"}',
    });
    final store = await LocalStore.create();
    final auth = LocalAuthRepository(store);
    await auth.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          contentDataSourceProvider.overrideWithValue(AssetContentDataSource()),
          authRepositoryProvider.overrideWithValue(auth),
          syncEngineProvider.overrideWithValue(LocalFirstSyncEngine()),
        ],
        child: const AccountingAcademyApp(),
      ),
    );

    // Boot: the router should skip onboarding and land on the dashboard.
    for (var i = 0; i < 60; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // The dashboard journey card is the landing marker.
    expect(find.text('ACCOUNTING JOURNEY'), findsOneWidget);
  });
}
