import 'package:decimal/decimal.dart';

import '../../../core/utils/money.dart';
import 'account.dart';

/// One side of a journal entry: debit or credit.
enum JournalSide { debit, credit }

/// A single line in a journal entry.
class JournalLine {
  const JournalLine({
    required this.account,
    required this.side,
    required this.amount,
  });

  final Account account;
  final JournalSide side;
  final Decimal amount;

  bool get isDebit => side == JournalSide.debit;

  @override
  String toString() =>
      '${isDebit ? 'Dr' : 'Cr'} ${account.name} ${formatIndian(amount)}';
}

/// A complete journal entry: at least one debit and one credit, and total
/// debits must equal total credits.
class JournalEntry {
  JournalEntry(Iterable<JournalLine> lines)
      : lines = List.unmodifiable(lines) {
    if (this.lines.isEmpty) {
      throw ArgumentError('A journal entry needs at least one line.');
    }
  }

  final List<JournalLine> lines;

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

  bool get hasDebit => lines.any((l) => l.isDebit);
  bool get hasCredit => lines.any((l) => !l.isDebit);

  /// A journal is balanced when total debits equal total credits.
  bool get isBalanced => totalDebits == totalCredits;

  /// Line amounts must be strictly positive (a negative amount should be
  /// recorded on the opposite side instead).
  bool get hasValidAmounts =>
      lines.every((l) => l.amount > Decimal.zero);

  /// Non-duplicate, non-ambiguous accounts per side.
  bool get hasDistinctAccounts {
    final seen = <String>{};
    for (final l in lines) {
      if (!seen.add('${l.account.name}|${l.side.name}')) return false;
    }
    return true;
  }

  /// Human-readable journal rendering.
  String describe() {
    final buffer = StringBuffer();
    for (final l in lines) {
      buffer.writeln(
        '${l.isDebit ? '  ' : '    '}${l.account.name} ${l.isDebit ? 'Dr' : 'Cr'}  ${formatIndian(l.amount)}',
      );
    }
    return buffer.toString().trimRight();
  }
}

/// Result of validating a user-created journal entry.
class JournalValidation {
  const JournalValidation({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;
}

/// Validates a journal entry structurally (balance, amounts, accounts).
JournalValidation validateJournal(JournalEntry entry) {
  final errors = <String>[];

  if (!entry.hasDebit) {
    errors.add('The entry has no debit line.');
  }
  if (!entry.hasCredit) {
    errors.add('The entry has no credit line.');
  }
  if (!entry.isBalanced) {
    errors.add(
      'Debits (${formatIndian(entry.totalDebits)}) do not equal credits '
      '(${formatIndian(entry.totalCredits)}).',
    );
  }
  if (!entry.hasValidAmounts) {
    errors.add('Amounts must be positive numbers.');
  }
  if (!entry.hasDistinctAccounts) {
    errors.add('The same account cannot appear twice on the same side.');
  }

  return JournalValidation(isValid: errors.isEmpty, errors: errors);
}
