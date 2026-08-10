import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../domain/auth_repository.dart';

/// Demo-mode auth: enables the complete product flow without a backend.
///
/// Sign-in accepts any valid-looking email/password (never stored) — or skips
/// straight to a guest learner. This is the offline-first MVP path; production
/// uses [SupabaseAuthRepository] behind the same interface.
class LocalAuthRepository implements AuthRepository, GuestAuthSupport {
  LocalAuthRepository(this._store);

  final LocalStore _store;
  final ValueNotifier<AuthStatus> _status =
      ValueNotifier(AuthStatus.unknown);

  @override
  ValueListenable<AuthStatus> get statusListenable => _status;

  @override
  AuthStatus get status => _status.value;

  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  Future<void> init() async {
    final email = _store.getString('auth.email');
    final name = _store.getString('auth.name');
    if (email != null) {
      _user = AuthUser(email: email, fullName: name);
      _status.value = AuthStatus.signedIn;
    } else {
      _status.value = AuthStatus.signedOut;
    }
  }

  @override
  Future<AuthUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }
    _user = AuthUser(email: trimmed);
    await _store.setString('auth.email', trimmed);
    _status.value = AuthStatus.signedIn;
    return _user;
  }

  /// Continue without an account (fully supported in demo mode).
  @override
  Future<AuthUser?> continueAsGuest() async {
    _user = const AuthUser(email: 'guest@local', fullName: 'Learner');
    await _store.setString('auth.email', _user!.email);
    await _store.setString('auth.name', _user!.fullName!);
    _status.value = AuthStatus.signedIn;
    return _user;
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    // Demo mode: same acceptance rules as sign-in.
    await signInWithEmail(email: email, password: password);
    _user = AuthUser(email: email.trim(), fullName: fullName);
    await _store.setString('auth.name', fullName ?? '');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // Demo mode has no mailer; the UI explains this.
  }

  @override
  Future<void> signOut() async {
    _user = null;
    await _store.remove('auth.email');
    await _store.remove('auth.name');
    _status.value = AuthStatus.signedOut;
  }
}
