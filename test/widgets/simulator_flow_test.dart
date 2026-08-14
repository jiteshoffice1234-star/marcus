import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_academy/core/providers/providers.dart';
import 'package:accounting_academy/data/datasources/content_datasource.dart';
import 'package:accounting_academy/domain/accounting/account.dart';
import 'package:accounting_academy/features/simulator/presentation/simulator_detail_screen.dart';

void main() {
  testWidgets('simulator resets the journal editor between transactions',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentDataSourceProvider
            .overrideWithValue(AssetContentDataSource()),
      ],
      child: const MaterialApp(
        home: SimulatorDetailScreen(simId: 'sim_abc_trading'),
      ),
    ));
    await tester.pumpAndSettle();

    // Transaction 1 loaded (opening balances + first transaction).
    expect(find.text('Transaction 1'), findsOneWidget);

    // Line 1: Bank Dr 200000
    await tester.tap(find.text('Add line'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButton<Account>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').first, '200000');
    await tester.pump();

    // Line 2: Capital Cr 200000
    await tester.tap(find.text('Add line'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButton<Account>).at(1));
    await tester.pumpAndSettle();
    // Scroll the menu to its end so Capital sits mid-list, clear of edges.
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capital').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cr').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cr').at(1));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').at(1), '200000');
    await tester.pump();

    expect(find.text('Balanced ✓'), findsOneWidget);
    await tester.ensureVisible(find.text('Check entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check entry'));
    await tester.pumpAndSettle();
    expect(find.text('Correct! The entry has been posted to the ledger.'),
        findsOneWidget);

    // Advance to transaction 2 — the editor must start empty, not showing
    // transaction 1's lines.
    await tester.ensureVisible(find.text('Next transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction 2'), findsOneWidget);
    expect(find.text('No lines yet — add a debit and a credit.'),
        findsOneWidget,
        reason: 'transaction 1 journal lines must not leak into transaction 2');
  });
}
