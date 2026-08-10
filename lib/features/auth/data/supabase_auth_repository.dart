import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';

/// Production auth backed by Supabase Auth.
///
/// Email verification is enforced at the UI layer via
/// [SupabaseAuthRepository.requiresEmailVerification] after sign-up.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;
  final ValueNotifier<AuthStatus> _status =
      ValueNotifier(AuthStatus.unknown);

  @override
  ValueListenable<AuthStatus> get statusListenable => _status;

  @override
  AuthStatus get status => _status.value;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUser(
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] as String?,
    );
  }

  bool get requiresEmailVerification =>
      _client.auth.currentUser?.emailConfirmedAt == null &&
          _client.auth.currentUser?.email != null;

  void attachListener() {
    _client.auth.onAuthStateChange.listen((data) {
      _status.value = data.session == null
          ? AuthStatus.signedOut
          : AuthStatus.signedIn;
    });
    _status.value = _client.auth.currentSession == null
        ? AuthStatus.signedOut
        : AuthStatus.signedIn;
  }

  @override
  Future<AuthUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _status.value = AuthStatus.signedIn;
      return AuthUser(
        email: response.user?.email ?? email,
        fullName: response.user?.userMetadata?['full_name'] as String?,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message), cause: e);
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName ?? ''},
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message), cause: e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on supabase.AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message), cause: e);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _status.value = AuthStatus.signedOut;
  }

  String _mapAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw;
  }
}
