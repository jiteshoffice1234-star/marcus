import '../../core/errors/app_exception.dart';
import '../repositories/learner_repository.dart';

enum SyncStatus { idle, syncing, synced, failed, offline }

class SyncResult {
  const SyncResult({
    required this.status,
    this.syncedItems = 0,
    this.message,
  });

  final SyncStatus status;
  final int syncedItems;
  final String? message;
}

/// Abstraction over the offline → server sync pipeline.
///
/// Contract (implemented by the remote engine in the backend phase):
///  * submissions carry a stable local idempotency key so replaying a sync
///    never creates duplicates;
///  * conflicts resolve last-write-wins with per-record timestamps;
///  * failures leave the queue intact and retry with backoff.
abstract interface class SyncEngine {
  /// Pushes local changes to the server. Safe to call repeatedly.
  Future<SyncResult> sync(LearnerRepository repository);

  /// Pulls remote changes into the local state.
  Future<SyncResult> pull(LearnerRepository repository);

  bool get isPending;
}

/// MVP engine: the app is local-first and content is bundled, so sync is a
/// no-op that reports the local state is authoritative. Swapping in the
/// Supabase-backed engine (with idempotency keys) requires no feature changes.
class LocalFirstSyncEngine implements SyncEngine {
  @override
  bool get isPending => false;

  @override
  Future<SyncResult> pull(LearnerRepository repository) async =>
      const SyncResult(status: SyncStatus.synced);

  @override
  Future<SyncResult> sync(LearnerRepository repository) async {
    try {
      // Future: POST pending attempts/mistakes/revision with idempotency keys.
      return const SyncResult(status: SyncStatus.synced);
    } on AppException {
      return const SyncResult(
        status: SyncStatus.failed,
        message: 'Sync failed; your changes are saved locally.',
      );
    }
  }
}
