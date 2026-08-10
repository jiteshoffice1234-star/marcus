import 'package:accounting_academy/core/utils/money.dart';
import 'package:accounting_academy/domain/accounting/account.dart';
import 'package:accounting_academy/domain/accounting/journal.dart';
import 'package:accounting_academy/domain/accounting/ledger.dart';
import 'package:accounting_academy/domain/accounting/simulator_engine.dart';
import 'package:accounting_academy/domain/accounting/statements.dart';
import 'package:accounting_academy/domain/accounting/trial_balance.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEntry', () {
    test('balances when debits equal credits', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(50000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(50000)),
      ]);
      expect(entry.isBalanced, isTrue);
      expect(entry.totalDebits, Decimal.fromInt(50000));
    });

    test('detects imbalance', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(50000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(40000)),
      ]);
      expect(entry.isBalanced, isFalse);
      final validation = validateJournal(entry);
      expect(validation.isValid, isFalse);
      expect(validation.errors, isNotEmpty);
    });

    test('rejects negative amounts', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(-100)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(100)),
      ]);
      expect(entry.hasValidAmounts, isFalse);
    });

    test('allows compound entries', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.purchases,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: ChartOfAccounts.inputGst,
            side: JournalSide.debit,
            amount: Decimal.fromInt(36000)),
        JournalLine(
            account: ChartOfAccounts.accountsPayable,
            side: JournalSide.credit,
            amount: Decimal.fromInt(236000)),
      ]);
      expect(entry.isBalanced, isTrue);
      expect(entry.totalDebits, Decimal.fromInt(236000));
    });
  });

  group('Ledger', () {
    test('posts entries and computes balances', () {
      final ledger = Ledger();
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(100000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(100000)),
      ]));
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.rent,
            side: JournalSide.debit,
            amount: Decimal.fromInt(25000)),
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.credit,
            amount: Decimal.fromInt(25000)),
      ]));

      expect(ledger.byName('Cash')!.balance, Decimal.fromInt(75000));
      expect(ledger.byName('Rent')!.balance, Decimal.fromInt(25000));
      expect(ledger.byName('Capital')!.balance, Decimal.fromInt(100000));
      expect(ledger.isBalanced, isTrue);
    });

    test('handles opening balances (contra accounts)', () {
      final ledger = Ledger();
      // A balanced opening trial balance: bank 500,000 = loan 200,000 + capital 300,000.
      ledger.postOpeningBalance(
          'Bank', AccountCategory.asset, Decimal.fromInt(500000));
      ledger.postOpeningBalance(
          'Bank Loan', AccountCategory.liability, Decimal.fromInt(200000));
      ledger.postOpeningBalance(
          'Capital', AccountCategory.capital, Decimal.fromInt(300000));
      expect(ledger.byName('Bank')!.balance, Decimal.fromInt(500000));
      expect(ledger.byName('Bank Loan')!.balance, Decimal.fromInt(200000));
      expect(ledger.byName('Capital')!.balance, Decimal.fromInt(300000));
      expect(ledger.isBalanced, isTrue);
    });
  });

  group('TrialBalance', () {
    test('extracts balances and balances', () {
      final ledger = Ledger();
      // Each entry balances on its own: cash 40,000 sales on credit.
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(40000)),
        JournalLine(
            account: ChartOfAccounts.sales,
            side: JournalSide.credit,
            amount: Decimal.fromInt(40000)),
      ]));
      // Purchases 20,000 paid from cash.
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.purchases,
            side: JournalSide.debit,
            amount: Decimal.fromInt(20000)),
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.credit,
            amount: Decimal.fromInt(20000)),
      ]));

      final tb = TrialBalance.fromLedger(ledger);
      expect(tb.isBalanced, isTrue);
      // Cash 20,000 (40,000 - 20,000) + Purchases 20,000 = 40,000 debits.
      expect(tb.totalDebits, Decimal.fromInt(40000));
      expect(tb.totalCredits, Decimal.fromInt(40000));
    });
  });

  group('Statements', () {
    test('builds P&L and balance sheet from a ledger', () {
      final ledger = Ledger();
      // Capital 200,000 cash
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(200000)),
      ]));
      // Sales on credit 120,000
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.accountsReceivable,
            side: JournalSide.debit,
            amount: Decimal.fromInt(120000)),
        JournalLine(
            account: ChartOfAccounts.sales,
            side: JournalSide.credit,
            amount: Decimal.fromInt(120000)),
      ]));
      // Rent paid 30,000
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.rent,
            side: JournalSide.debit,
            amount: Decimal.fromInt(30000)),
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.credit,
            amount: Decimal.fromInt(30000)),
      ]));

      final statements = StatementBuilder.build(ledger);
      expect(statements.pnl.netProfit, Decimal.fromInt(90000));
      expect(statements.balanceSheet.isBalanced, isTrue);
      // Assets: cash 170,000 + receivables 120,000 = 290,000
      expect(statements.balanceSheet.totalAssets, Decimal.fromInt(290000));
      // Capital: 200,000 + net profit 90,000 = 290,000
      expect(statements.balanceSheet.totalCapital, Decimal.fromInt(290000));
    });

    test('handles a net loss', () {
      final ledger = Ledger();
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(100000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(100000)),
      ]));
      ledger.post(JournalEntry([
        JournalLine(
            account: ChartOfAccounts.salaries,
            side: JournalSide.debit,
            amount: Decimal.fromInt(120000)),
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.credit,
            amount: Decimal.fromInt(120000)),
      ]));

      final statements = StatementBuilder.build(ledger);
      // Revenue 0 − expenses 120,000 = net loss 120,000.
      expect(statements.pnl.netProfit, Decimal.fromInt(-120000));
      expect(statements.balanceSheet.isBalanced, isTrue);
    });
  });

  group('Simulator engine', () {
    final capitalSpec = SimulatorTransactionSpec(
      seq: 1,
      narration: 'Capital introduced in cash',
      expectedLines: [
        ExpectedJournalLine(
            accountName: 'Cash', side: JournalSide.debit, amount: Decimal.fromInt(200000)),
        ExpectedJournalLine(
            accountName: 'Capital', side: JournalSide.credit, amount: Decimal.fromInt(200000)),
      ],
    );

    test('accepts a correct entry in any line order', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
      ]);
      final check = checkSimulatorJournal(entry, capitalSpec);
      expect(check.isCorrect, isTrue);
      expect(check.feedback.where((f) => f.kind == LineFeedbackKind.correct).length, 2);
    });

    test('flags missing lines', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
      ]);
      final check = checkSimulatorJournal(entry, capitalSpec);
      expect(check.isCorrect, isFalse);
      expect(
        check.feedback.any((f) => f.kind == LineFeedbackKind.missing),
        isTrue,
      );
    });

    test('flags wrong amounts', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(150000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(150000)),
      ]);
      final check = checkSimulatorJournal(entry, capitalSpec);
      expect(check.isCorrect, isFalse);
      expect(
        check.feedback.any((f) => f.kind == LineFeedbackKind.wrongAmount),
        isTrue,
      );
    });

    test('flags extra lines', () {
      final entry = JournalEntry([
        JournalLine(
            account: ChartOfAccounts.cash,
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: ChartOfAccounts.bank,
            side: JournalSide.debit,
            amount: Decimal.fromInt(10000)),
        JournalLine(
            account: ChartOfAccounts.capital,
            side: JournalSide.credit,
            amount: Decimal.fromInt(210000)),
      ]);
      final check = checkSimulatorJournal(entry, capitalSpec);
      expect(check.isCorrect, isFalse);
      expect(
        check.feedback.any((f) => f.kind == LineFeedbackKind.extra),
        isTrue,
      );
    });

    test('tolerates account naming variations', () {
      final entry = JournalEntry([
        JournalLine(
            account: Account('Cash a/c', AccountCategory.asset),
            side: JournalSide.debit,
            amount: Decimal.fromInt(200000)),
        JournalLine(
            account: Account('Capital Account', AccountCategory.capital),
            side: JournalSide.credit,
            amount: Decimal.fromInt(200000)),
      ]);
      final check = checkSimulatorJournal(entry, capitalSpec);
      expect(check.isCorrect, isTrue);
    });
  });

  group('Money parsing', () {
    test('parses Indian formatting', () {
      expect(tryParseAmount('3,20,000'), Decimal.fromInt(320000));
      expect(tryParseAmount('₹ 1,00,000.50'), Decimal.parse('100000.50'));
      expect(tryParseAmount('Rs 50,000'), Decimal.fromInt(50000));
    });

    test('parses negatives and parentheses', () {
      expect(tryParseAmount('-12,000'), Decimal.fromInt(-12000));
      expect(tryParseAmount('(8,500)'), Decimal.fromInt(-8500));
    });

    test('rejects garbage', () {
      expect(tryParseAmount(''), isNull);
      expect(tryParseAmount('abc'), isNull);
      expect(tryParseAmount('   '), isNull);
    });

    test('formats compactly', () {
      expect(formatCompact(Decimal.fromInt(120000)), '1.2L');
      expect(formatCompact(Decimal.fromInt(34000000)), '3.4Cr');
      expect(formatCompact(Decimal.fromInt(5600)), '5.6K');
    });
  });
}
