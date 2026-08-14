import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Hooks global error handlers so failures are logged and the app degrades
/// gracefully instead of crashing silently.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static ErrorReporter reporter = const ConsoleErrorReporter();

  static void install({ErrorReporter? reporter}) {
    if (reporter != null) GlobalErrorHandler.reporter = reporter;

    // Note: the closures must reference the static field, not the [reporter]
    // parameter — install() is called without arguments in main(), and the
    // static default must remain effective.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      GlobalErrorHandler.reporter.report(
        message: details.exceptionAsString(),
        stack: details.stack,
        context: details.library,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      GlobalErrorHandler.reporter.report(
          message: error.toString(), stack: stack);
      return true; // handled — do not kill the app
    };

    // Uncaught async errors in the root zone are routed to
    // [PlatformDispatcher.onError] above, so no separate zone handler is
    // needed here. (A runZonedGuarded around `runApp` in main() is the
    // pattern if zone-scoped handling is ever required.)
  }
}

/// Abstraction over where errors go (console now, crash-reporting service later).
abstract interface class ErrorReporter {
  void report({required String message, StackTrace? stack, String? context});
}

/// Default: structured console logging (Crashlytics/Sentry can be swapped in
/// behind this interface without touching app code).
class ConsoleErrorReporter implements ErrorReporter {
  const ConsoleErrorReporter();

  @override
  void report({required String message, StackTrace? stack, String? context}) {
    debugPrint('[ERROR]${context == null ? '' : ' ($context)'}: $message');
    if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 8);
  }
}

/// Maps any thrown object to a user-friendly message. Used by feature-level
/// error handling so the UI never displays raw exceptions.
String friendlyErrorMessage(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
