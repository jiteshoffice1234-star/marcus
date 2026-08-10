import 'package:accounting_academy/app.dart';
import 'package:accounting_academy/core/storage/local_store.dart';
import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/data/sync/sync_engine.dart';
import 'package:accounting_academy/features/auth/data/local_auth_repository.dart';
import 'package:accounting_academy/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the onboarding welcome screen in demo mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome to'), findsOneWidget);
    expect(find.text('Begin assessment'), findsOneWidget);
  });

  testWidgets('onboarding assessment step shows a question after starting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Begin assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Knowledge assessment'), findsOneWidget);
    expect(find.textContaining('1 /'), findsOneWidget);
  });
}
