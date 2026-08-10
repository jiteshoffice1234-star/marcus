import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/content_datasource.dart';
import '../../data/models/learner.dart';
import '../../data/models/question.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/sync/sync_engine.dart';
import '../../domain/assessment/assessment_engine.dart';
import '../../domain/gamification/gamification.dart';
import '../../features/ai_tutor/data/coach_ai_tutor_service.dart';
import '../../features/ai_tutor/data/remote_ai_tutor_service.dart';
import '../../features/ai_tutor/domain/ai_tutor_service.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../config/app_config.dart';
import '../storage/local_store.dart';

// ---------------------------------------------------------------------------
// Infrastructure (wired in main.dart with concrete implementations)
// ---------------------------------------------------------------------------

final localStoreProvider = Provider<LocalStore>(
    (_) => throw UnimplementedError('localStoreProvider must be overridden'));

final contentDataSourceProvider = Provider<ContentDataSource>(
    (_) => throw UnimplementedError('contentDataSourceProvider must be overridden'));

final authRepositoryProvider = Provider<AuthRepository>(
    (_) => throw UnimplementedError('authRepositoryProvider must be overridden'));

final syncEngineProvider = Provider<SyncEngine>(
    (_) => throw UnimplementedError('syncEngineProvider must be overridden'));

/// Poked whenever router-relevant state changes so GoRouter re-runs redirects.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerRefreshListenableProvider =
    Provider<RouterRefreshNotifier>((_) => RouterRefreshNotifier());

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final contentRepositoryProvider = Provider<ContentRepository>(
    (ref) => ContentRepository(ref.watch(contentDataSourceProvider)));

final learnerRepositoryProvider = Provider<LearnerRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  return LearnerRepository(store);
});

// ---------------------------------------------------------------------------
// AI tutor (selected from config; keys come from --dart-define, never checked
// into the repo)
// ---------------------------------------------------------------------------

final aiTutorServiceProvider = Provider<AiTutorService>((ref) {
  if (AppConfig.useRemoteAi) {
    return RemoteAiTutorService(
      endpoint: AppConfig.aiEndpoint,
      apiKey: AppConfig.aiApiKey,
    );
  }
  return CoachAiTutorService();
});

// ---------------------------------------------------------------------------
// Learner state (the LEARN → PRACTICE → TEST → ANALYZE → REVISE loop)
// ---------------------------------------------------------------------------

final learnerStateProvider =
    AsyncNotifierProvider<LearnerNotifier, LearnerState>(LearnerNotifier.new);

class LearnerNotifier extends AsyncNotifier<LearnerState> {
  LearnerRepository get _repo => ref.read(learnerRepositoryProvider);

  @override
  Future<LearnerState> build() async {
    await _repo.init();
    return _repo.state;
  }

  Future<void> _refresh() async {
    state = AsyncData(_repo.state);
  }

  Future<List<AchievementDef>> recordAnswer({
    required QuestionData question,
    required bool correct,
    String source = 'practice',
  }) async {
    final unlocked = await _repo.recordAnswer(
      question: question,
      correct: correct,
      source: source,
    );
    await _refresh();
    return unlocked;
  }

  Future<List<AchievementDef>> completeLesson() async {
    final unlocked = await _repo.completeLesson();
    await _refresh();
    return unlocked;
  }

  Future<List<AchievementDef>> completeTest({
    required int correctCount,
    required int totalCount,
  }) async {
    final unlocked =
        await _repo.completeTest(correctCount: correctCount, totalCount: totalCount);
    await _refresh();
    return unlocked;
  }

  Future<void> applyAssessment(AssessmentResult result) async {
    await _repo.applyAssessment(result);
    await _refresh();
  }

  Future<void> reviewRevision({
    required String contentId,
    required bool correct,
  }) async {
    await _repo.reviewRevision(contentId: contentId, correct: correct);
    await _refresh();
  }

  Future<void> addNote(NoteRecord note) async {
    await _repo.addNote(note);
    await _refresh();
  }

  Future<void> deleteNote(String id) async {
    await _repo.deleteNote(id);
    await _refresh();
  }

  Future<void> addBookmark(BookmarkRecord bookmark) async {
    await _repo.addBookmark(bookmark);
    await _refresh();
  }

  Future<void> removeBookmark(String contentType, String contentId) async {
    await _repo.removeBookmark(contentType, contentId);
    await _refresh();
  }

  Future<void> updateDailyGoal(int goal) async {
    await _repo.updateDailyGoal(goal);
    await _refresh();
  }

  Future<void> setOnboarded({bool assessmentTaken = false}) async {
    await _repo.setOnboarded(assessmentTaken: assessmentTaken);
    await _refresh();
  }
}

// ---------------------------------------------------------------------------
// Auth controller
// ---------------------------------------------------------------------------

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final repo = ref.watch(authRepositoryProvider);
    final initial = repo.status;
    // Keep the notifier in sync with repository changes.
    void listener() {
      state = repo.status;
    }

    ref.onDispose(() => repo.statusListenable.removeListener(listener));
    repo.statusListenable.addListener(listener);
    return initial == AuthStatus.unknown ? AuthStatus.signedOut : initial;
  }

  Future<AuthUser?> signIn({required String email, required String password}) =>
      ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          );

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) =>
      ref
          .read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password, fullName: fullName);

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}
