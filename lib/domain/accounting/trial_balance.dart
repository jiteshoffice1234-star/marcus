import 'package:decimal/decimal.dart';

import '../../../core/utils/money.dart';
import 'ledger.dart';

/// One row of a trial balance.
class TrialBalanceLine {
  const TrialBalanceLine({
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  final String accountName;

  /// Raw debit total of the account.
  final Decimal debit;

  /// Raw credit total of the account.
  final Decimal credit;

  bool get hasDebitBalance => debit > credit;
  bool get hasCreditBalance => credit > debit;

  /// The balancing figure on the larger side.
  Decimal get balance => debit > credit ? debit - credit : credit - debit;
}

class TrialBalance {
  TrialBalance(this.lines);

  final List<TrialBalanceLine> lines;

  Decimal get totalDebits {
    var total = Decimal.zero;
    for (final l in lines) {
      if (l.hasDebitBalance) total += l.balance;
    }
    return total;
  }

  Decimal get totalCredits {
    var total = Decimal.zero;
    for (final l in lines) {
      if (l.hasCreditBalance) total += l.balance;
    }
    return total;
  }

  bool get isBalanced => totalDebits == totalCredits;

  static TrialBalance fromLedger(Ledger ledger) {
    final lines = <TrialBalanceLine>[];
    for (final account in ledger.accounts) {
      if (account.totalDebits == Decimal.zero &&
          account.totalCredits == Decimal.zero) {
        continue;
      }
      lines.add(TrialBalanceLine(
        accountName: account.account.name,
        debit: account.totalDebits,
        credit: account.totalCredits,
      ));
    }
    return TrialBalance(lines);
  }

  String render() {
    final buffer = StringBuffer('Trial Balance\n');
    buffer.writeln('${'Account'.padRight(28)} ${'Debit'.padLeft(14)} ${'Credit'.padLeft(14)}');
    for (final l in lines) {
      buffer.writeln(
        '${l.accountName.padRight(28)} ${formatIndian(l.debit).padLeft(14)} ${formatIndian(l.credit).padLeft(14)}',
      );
    }
    buffer.writeln(
      '${'Total'.padRight(28)} ${formatIndian(totalDebits).padLeft(14)} ${formatIndian(totalCredits).padLeft(14)}',
    );
    return buffer.toString();
  }
}
