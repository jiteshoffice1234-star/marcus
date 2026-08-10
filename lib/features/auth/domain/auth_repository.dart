import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthUser {
  const AuthUser({required this.email, this.fullName});

  final String email;
  final String? fullName;
}

/// Abstraction over authentication. The MVP ships with a local demo
/// implementation (works offline, no credentials) and a Supabase
/// implementation (email + password, email verification) selected at wiring
/// time — features never depend on a concrete provider.
abstract interface class AuthRepository {
  AuthStatus get status;

  /// Listen to auth state changes.
  ValueListenable<AuthStatus> get statusListenable;

  AuthUser? get currentUser;

  Future<AuthUser?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Implemented by auth providers that support anonymous/guest sessions.
/// The onboarding flow offers "continue as guest" when available.
abstract interface class GuestAuthSupport {
  Future<AuthUser?> continueAsGuest();
}
