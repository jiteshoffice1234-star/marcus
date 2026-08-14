import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_academy/core/errors/global_error_handler.dart';

class _RecordingReporter implements ErrorReporter {
  _RecordingReporter(this.messages);

  final List<String> messages;

  @override
  void report({required String message, StackTrace? stack, String? context}) {
    messages.add(message);
  }
}

void main() {
  // Behavioral check for the error-handler fix: install() is called without
  // arguments in main(), and the handlers must route through the static
  // [GlobalErrorHandler.reporter] — not through a null local.
  test('install() without arguments routes framework errors to the static '
      'reporter', () {
    final messages = <String>[];
    final prevReporter = GlobalErrorHandler.reporter;
    final prevOnError = FlutterError.onError;
    final prevPlatformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      GlobalErrorHandler.reporter = prevReporter;
      FlutterError.onError = prevOnError;
      PlatformDispatcher.instance.onError = prevPlatformOnError;
    });

    GlobalErrorHandler.reporter = _RecordingReporter(messages);
    GlobalErrorHandler.install();

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('boom-test'),
        library: 'behavior_test',
      ),
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('boom-test'));
  });
}
