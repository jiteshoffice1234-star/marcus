import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_academy/data/models/difficulty.dart';
import 'package:accounting_academy/data/models/question.dart';
import 'package:accounting_academy/shared/widgets/answer_input.dart';

QuestionData _mcq(String id, {required List<String> keys, required Map<String, String> options}) =>
    QuestionData(
      id: id,
      type: QuestionType.mcq,
      difficulty: Difficulty.beginner,
      stem: 'Stem $id',
      answer: AnswerData(keys: keys),
      explanation: 'explanation',
      options: [
        for (final e in options.entries) QuestionOption(key: e.key, text: e.value),
      ],
    );

QuestionData _num(String id, String value) => QuestionData(
      id: id,
      type: QuestionType.numerical,
      difficulty: Difficulty.beginner,
      stem: 'Stem $id',
      answer: AnswerData(value: value),
      explanation: 'explanation',
      options: const [],
    );

QuestionData _journal(String id) => QuestionData(
      id: id,
      type: QuestionType.journalEntry,
      difficulty: Difficulty.beginner,
      stem: 'Stem $id',
      answer: AnswerData(
        journalLines: [
          (account: 'Cash', side: 'debit', amount: '100000'),
          (account: 'Capital', side: 'credit', amount: '100000'),
        ],
      ),
      explanation: 'explanation',
      options: const [],
    );

void main() {
  // These tests drive the REAL widgets and assert the state transitions the
  // P1 answer-state-leak fix promises: user input from question N must never
  // carry into question N+1, for every input type.

  testWidgets('MCQ selection does not leak into the next question',
      (tester) async {
    final submitted = <UserAnswer>[];
    Future<void> pump(QuestionData q) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AnswerInput(question: q, onSubmit: submitted.add),
          ),
        ));

    await pump(_mcq('q1', keys: ['A'], options: {'A': 'Alpha', 'B': 'Beta'}));
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitted, hasLength(1));
    expect(submitted.single.selectedKeys, ['A']);

    // Swap to a different question (same widget slot → State is reused).
    await pump(_mcq('q2', keys: ['D'], options: {'C': 'Gamma', 'D': 'Delta'}));
    await tester.pump();
    // Selecting Gamma must submit ONLY Gamma — a leaked 'A' would submit ['A','C'].
    await tester.tap(find.text('Gamma'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitted, hasLength(2));
    expect(submitted.last.selectedKeys, ['C']);
  });

  testWidgets('typed numerical answer does not leak into the next question',
      (tester) async {
    final submitted = <UserAnswer>[];
    Future<void> pump(QuestionData q) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AnswerInput(question: q, onSubmit: submitted.add),
          ),
        ));

    await pump(_num('n1', '100'));
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitted, hasLength(1));
    expect(submitted.single.text, '100');

    await pump(_num('n2', '200'));
    await tester.pump();
    // The field must be empty for the new question.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty,
        reason: 'typed answer from the previous question must be cleared');
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitted, hasLength(2));
    expect(submitted.last.text, '200');
  });

  testWidgets('journal entry does not leak across journal questions',
      (tester) async {
    final submitted = <UserAnswer>[];
    Future<void> pump(QuestionData q) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AnswerInput(question: q, onSubmit: submitted.add),
          ),
        ));

    await pump(_journal('j1'));
    expect(find.text('No lines yet — add a debit and a credit.'),
        findsOneWidget);

    // Line 1: Cash Dr 100000 (default account, default side)
    await tester.tap(find.text('Add line'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').first, '100000');
    await tester.pump();
    // Line 2: Cash Cr 100000 (default account, toggled to credit)
    await tester.tap(find.text('Add line'));
    await tester.pump();
    await tester.tap(find.text('Cr').at(1));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').at(1), '100000');
    await tester.pump();

    expect(find.text('Balanced ✓'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitted, hasLength(1));
    expect(submitted.single.journal, isNotNull);
    expect(submitted.single.journal!.lines, hasLength(2));

    // Swap to a different journal question: the editor must start empty.
    await pump(_journal('j2'));
    await tester.pump();
    expect(find.text('No lines yet — add a debit and a credit.'),
        findsOneWidget,
        reason: 'journal lines from the previous question must not leak');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    expect(submitted, hasLength(1),
        reason: 'submitting an untouched new question must not send a stale entry');
  });
}
