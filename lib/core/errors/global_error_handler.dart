import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Hooks global error handlers so failures are logged and the app degrades
/// gracefully instead of crashing silently.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static ErrorReporter reporter = const ConsoleErrorReporter();

  static void install({ErrorReporter? reporter}) {
    if (reporter != null) GlobalErrorHandler.reporter = reporter;

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      reporter?.report(
        message: details.exceptionAsString(),
        stack: details.stack,
        context: details.library,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      reporter?.report(message: error.toString(), stack: stack);
      return true; // handled — do not kill the app
    };

    // Catch async errors that would otherwise escape to the zone.
    runZonedGuarded(
      () {},
      (error, stack) {
        reporter?.report(message: error.toString(), stack: stack);
      },
    );
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
