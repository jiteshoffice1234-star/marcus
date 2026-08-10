/// Base class for all typed application errors.
///
/// Every layer throws a typed [AppException] (or a subclass) so the UI can
/// present a friendly, recoverable message instead of crashing.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Human-readable message safe to show to the user.
  final String message;

  /// Machine-readable code for analytics/debugging (e.g. `network_timeout`).
  final String? code;

  /// The underlying error, logged but never shown raw to the user.
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

/// A network failure (timeout, no connection, server unreachable).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code = 'network', super.cause});
}

/// The user has no connectivity and the data is not available offline.
class OfflineException extends AppException {
  const OfflineException(super.message, {super.code = 'offline', super.cause});
}

/// Authentication failure (bad credentials, unverified email, expired session).
class AuthException extends AppException {
  const AuthException(super.message, {super.code = 'auth', super.cause});
}

/// The remote service (Supabase / AI provider) returned an unexpected result.
class RemoteServiceException extends AppException {
  const RemoteServiceException(super.message, {super.code = 'remote', super.cause});
}

/// Validation failure for user input.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code = 'validation', super.cause});
}

/// The requested content does not exist (or was deleted).
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code = 'not_found', super.cause});
}
