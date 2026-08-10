import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/errors/global_error_handler.dart';
import 'core/providers/providers.dart';
import 'core/storage/local_store.dart';
import 'data/datasources/content_datasource.dart';
import 'data/sync/sync_engine.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.install();

  final store = await LocalStore.create();

  // Backend: initialize Supabase only when configured via --dart-define.
  // Without it the app runs in local demo mode (bundled content + local auth),
  // which keeps the entire MVP testable offline.
  AuthRepository authRepository;
  if (AppConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      final repo = SupabaseAuthRepository(Supabase.instance.client);
      repo.attachListener();
      authRepository = repo;
    } catch (e) {
      debugPrint('Supabase init failed, falling back to local demo mode: $e');
      final local = LocalAuthRepository(store);
      await local.init();
      authRepository = local;
    }
  } else {
    final local = LocalAuthRepository(store);
    await local.init();
    authRepository = local;
  }

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        contentDataSourceProvider
            .overrideWithValue(AssetContentDataSource()),
        authRepositoryProvider.overrideWithValue(authRepository),
        syncEngineProvider.overrideWithValue(LocalFirstSyncEngine()),
      ],
      child: const AccountingAcademyApp(),
    ),
  );
}
