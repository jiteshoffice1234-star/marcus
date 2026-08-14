import 'package:accounting_academy/app.dart';
import 'package:accounting_academy/core/providers/providers.dart';
import 'package:accounting_academy/core/storage/local_store.dart';
import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/data/models/question.dart';
import 'package:accounting_academy/data/sync/sync_engine.dart';
import 'package:accounting_academy/features/auth/data/local_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.create();
  final auth = LocalAuthRepository(store);
  await auth.init();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        contentDataSourceProvider.overrideWithValue(AssetContentDataSource()),
        authRepositoryProvider.overrideWithValue(auth),
        syncEngineProvider.overrideWithValue(LocalFirstSyncEngine()),
      ],
      child: const AccountingAcademyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Answers one assessment question correctly through the real UI controls.
Future<void> _answerQuestion(WidgetTester tester, QuestionData q) async {
  switch (q.type) {
    case QuestionType.mcq:
    case QuestionType.trueFalse:
      final correct = q.options.firstWhere((o) => q.answer.keys.contains(o.key));
      await tester.ensureVisible(find.text(correct.text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(correct.text));
      await tester.pump();
    case QuestionType.numerical:
      final text = q.answer.value ?? q.answer.accepted.first;
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    case QuestionType.fillBlank:
      await tester.enterText(find.byType(TextField), q.answer.accepted.first);
      await tester.pump();
    default:
      fail('Unexpected assessment question type: ${q.type.name} ($q)');
  }
}

void main() {
  testWidgets(
      'completing the full onboarding assessment reaches the results and roadmap '
      'screens without crashing', (tester) async {
    final questions =
        await AssetContentDataSource().loadAssessmentQuestions();

    await _pumpApp(tester);
    expect(find.text('Begin assessment'), findsOneWidget);

    await tester.tap(find.text('Begin assessment'));
    await tester.pumpAndSettle();

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      await _answerQuestion(tester, q);
      final submitLabel =
          i == questions.length - 1 ? 'Finish assessment' : 'Next question';
      await tester.tap(find.text(submitLabel));
      // Give the async scoring + state change time to settle.
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    // Results step — the crash used to happen on the final question.
    expect(find.text('Your skill profile'), findsOneWidget);

    // Roadmap step (async build — pump until it appears).
    await tester.ensureVisible(find.text('View my roadmap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View my roadmap'));
    await _pumpUntil(tester, find.text('Your personalized roadmap'));

    // Onboarding done → dashboard.
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await _pumpUntil(tester, find.text('ACCOUNTING JOURNEY'));
  });
}

/// Pumps frames until [finder] matches, up to a timeout.
///
/// Asset-bundle reads are real async I/O, which the fake-async test clock
/// cannot drive — yield to the real event loop with [WidgetTester.runAsync]
/// between pumps so pending loads can complete.
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}
