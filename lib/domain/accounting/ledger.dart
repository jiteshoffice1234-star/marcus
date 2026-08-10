import 'package:decimal/decimal.dart';

import 'account.dart';
import 'journal.dart';

/// An individual ledger account with its posted entries and computed balance.
class LedgerAccount {
  LedgerAccount(this.account);

  final Account account;
  final List<JournalLine> lines = [];

  Decimal get totalDebits {
    var total = Decimal.zero;
    for (final l in lines) {
      if (l.isDebit) total += l.amount;
    }
    return total;
  }

  Decimal get totalCredits {
    var total = Decimal.zero;
    for (final l in lines) {
      if (!l.isDebit) total += l.amount;
    }
    return total;
  }

  /// The signed balance: positive when the account has its normal balance,
  /// negative when it is in a contra state (e.g. overdrawn bank).
  Decimal get balance => account.category.normalDebit
      ? totalDebits - totalCredits
      : totalCredits - totalDebits;

  void post(JournalLine line) => lines.add(line);
}

/// The ledger: post journal entries and read balances.
class Ledger {
  final Map<String, LedgerAccount> _accounts = {};

  LedgerAccount account(Account a) =>
      _accounts.putIfAbsent(a.name, () => LedgerAccount(a));

  /// Posts every line of [entry] to the relevant ledger accounts.
  void post(JournalEntry entry) {
    for (final line in entry.lines) {
      account(line.account).post(line);
    }
  }

  /// Seeds a starting balance (from an opening trial balance). Opening
  /// balances are a position, not a journal entry — they post directly to the
  /// account without needing a matching line.
  void postOpeningBalance(String accountName, AccountCategory category, Decimal balance) {
    if (balance == Decimal.zero) return;
    final acc = Account(accountName, category);
    final side = balance > Decimal.zero
        ? (category.normalDebit ? JournalSide.debit : JournalSide.credit)
        : (category.normalDebit ? JournalSide.credit : JournalSide.debit);
    account(acc).post(JournalLine(account: acc, side: side, amount: balance.abs()));
  }

  List<LedgerAccount> get accounts => _accounts.values.toList();

  LedgerAccount? byName(String name) => _accounts[name];

  /// Debit total of the whole ledger (== credit total when balanced).
  Decimal get totalDebits {
    var total = Decimal.zero;
    for (final a in _accounts.values) {
      total += a.totalDebits;
    }
    return total;
  }

  Decimal get totalCredits {
    var total = Decimal.zero;
    for (final a in _accounts.values) {
      total += a.totalCredits;
    }
    return total;
  }

  bool get isBalanced => totalDebits == totalCredits;
}
