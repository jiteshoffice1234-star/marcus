import 'package:decimal/decimal.dart';

import '../../../core/utils/money.dart';
import 'account.dart';
import 'ledger.dart';

/// A named amount on a financial statement.
class StatementLine {
  const StatementLine(this.name, this.amount);
  final String name;
  final Decimal amount;
}

/// The Profit & Loss account for a period.
class ProfitAndLoss {
  ProfitAndLoss({
    required this.incomes,
    required this.expenses,
  });

  final List<StatementLine> incomes;
  final List<StatementLine> expenses;

  Decimal get totalIncome {
    var total = Decimal.zero;
    for (final l in incomes) {
      total += l.amount;
    }
    return total;
  }

  Decimal get totalExpenses {
    var total = Decimal.zero;
    for (final l in expenses) {
      total += l.amount;
    }
    return total;
  }

  Decimal get netProfit => totalIncome - totalExpenses;

  String render() {
    final buffer = StringBuffer('Profit & Loss Account\n');
    buffer.writeln('Incomes');
    for (final l in incomes) {
      buffer.writeln('  ${l.name.padRight(28)} ${formatIndian(l.amount).padLeft(14)}');
    }
    buffer.writeln('  ${'Total Income'.padRight(28)} ${formatIndian(totalIncome).padLeft(14)}');
    buffer.writeln('Expenses');
    for (final l in expenses) {
      buffer.writeln('  ${l.name.padRight(28)} ${formatIndian(l.amount).padLeft(14)}');
    }
    buffer.writeln('  ${'Total Expenses'.padRight(28)} ${formatIndian(totalExpenses).padLeft(14)}');
    buffer.writeln(
      '  ${'NET PROFIT'.padRight(28)} ${formatIndian(netProfit).padLeft(14)}',
    );
    return buffer.toString();
  }
}

/// The Balance Sheet at a point in time.
class BalanceSheet {
  BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.capital,
  });

  final List<StatementLine> assets;
  final List<StatementLine> liabilities;
  final List<StatementLine> capital;

  Decimal get totalAssets {
    var total = Decimal.zero;
    for (final l in assets) {
      total += l.amount;
    }
    return total;
  }

  Decimal get totalLiabilities {
    var total = Decimal.zero;
    for (final l in liabilities) {
      total += l.amount;
    }
    return total;
  }

  Decimal get totalCapital {
    var total = Decimal.zero;
    for (final l in capital) {
      total += l.amount;
    }
    return total;
  }

  bool get isBalanced => totalAssets == totalLiabilities + totalCapital;

  String render() {
    final buffer = StringBuffer('Balance Sheet\n');
    buffer.writeln('Assets');
    for (final l in assets) {
      buffer.writeln('  ${l.name.padRight(28)} ${formatIndian(l.amount).padLeft(14)}');
    }
    buffer.writeln('  ${'TOTAL ASSETS'.padRight(28)} ${formatIndian(totalAssets).padLeft(14)}');
    buffer.writeln('Liabilities');
    for (final l in liabilities) {
      buffer.writeln('  ${l.name.padRight(28)} ${formatIndian(l.amount).padLeft(14)}');
    }
    buffer.writeln('Capital');
    for (final l in capital) {
      buffer.writeln('  ${l.name.padRight(28)} ${formatIndian(l.amount).padLeft(14)}');
    }
    buffer.writeln(
      '  ${'TOTAL L + C'.padRight(28)} ${formatIndian(totalLiabilities + totalCapital).padLeft(14)}',
    );
    return buffer.toString();
  }
}

/// Builds [ProfitAndLoss] and [BalanceSheet] from a [Ledger].
///
/// Classification rules:
///  * income accounts → P&L incomes (signed balance is positive when credit).
///  * expense accounts → P&L expenses.
///  * asset accounts → balance sheet assets (contra-assets reduce assets).
///  * liability + capital accounts → balance sheet liabilities/capital.
///  * Net profit is added to capital; net loss reduces it.
class StatementBuilder {
  StatementBuilder._();

  static ({ProfitAndLoss pnl, BalanceSheet balanceSheet}) build(Ledger ledger) {
    final incomes = <StatementLine>[];
    final expenses = <StatementLine>[];
    final assets = <StatementLine>[];
    final liabilities = <StatementLine>[];
    final capital = <StatementLine>[];

    for (final account in ledger.accounts) {
      final balance = account.balance;
      if (balance == Decimal.zero) continue;
      switch (account.account.category) {
        case AccountCategory.income:
          incomes.add(StatementLine(account.account.name, balance));
        case AccountCategory.expense:
          expenses.add(StatementLine(account.account.name, balance));
        case AccountCategory.asset:
          assets.add(StatementLine(account.account.name, balance));
        case AccountCategory.liability:
          liabilities.add(StatementLine(account.account.name, balance));
        case AccountCategory.capital:
          capital.add(StatementLine(account.account.name, balance));
      }
    }

    final pnl = ProfitAndLoss(incomes: incomes, expenses: expenses);
    final netProfit = pnl.netProfit;
    if (netProfit != Decimal.zero) {
      capital.add(StatementLine(
        netProfit >= Decimal.zero ? 'Net Profit' : 'Net Loss',
        netProfit,
      ));
    }

    return (
      pnl: pnl,
      balanceSheet: BalanceSheet(
        assets: assets,
        liabilities: liabilities,
        capital: capital,
      ),
    );
  }
}
