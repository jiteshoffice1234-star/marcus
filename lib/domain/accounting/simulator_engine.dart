import 'package:decimal/decimal.dart';

import 'account.dart';
import 'journal.dart';

/// The expected journal line for a simulator transaction.
class ExpectedJournalLine {
  const ExpectedJournalLine({
    required this.accountName,
    required this.side,
    required this.amount,
  });

  final String accountName;
  final JournalSide side;
  final Decimal amount;
}

/// A transaction the learner must journalize.
class SimulatorTransactionSpec {
  const SimulatorTransactionSpec({
    required this.seq,
    required this.narration,
    required this.expectedLines,
    this.hints = const [],
  });

  final int seq;
  final String narration;
  final List<ExpectedJournalLine> expectedLines;
  final List<String> hints;
}

enum LineFeedbackKind { correct, missing, wrongAmount, extra }

class LineFeedback {
  const LineFeedback({
    required this.kind,
    required this.accountName,
    required this.side,
    required this.expectedAmount,
    this.actualAmount,
    this.message,
  });

  final LineFeedbackKind kind;
  final String accountName;
  final JournalSide side;
  final Decimal expectedAmount;
  final Decimal? actualAmount;
  final String? message;
}

class JournalCheckResult {
  const JournalCheckResult({
    required this.isCorrect,
    required this.structuralErrors,
    required this.feedback,
  });

  final bool isCorrect;
  final List<String> structuralErrors;
  final List<LineFeedback> feedback;
}

/// Compares a user's [JournalEntry] against the expected [SimulatorTransactionSpec].
///
/// Comparison is tolerant of line order and of how accounts are named
/// (see [Account.matchesName]); amounts must match exactly.
JournalCheckResult checkSimulatorJournal(
  JournalEntry userEntry,
  SimulatorTransactionSpec expected,
) {
  // Structural validation. Line-level feedback is still produced for
  // unbalanced entries so learners see exactly which line is missing or
  // wrong — structural errors and line feedback are complementary.
  final structural = validateJournal(userEntry);

  // Normalize both sides: account name -> total amount, per side.
  Map<String, Decimal> group(Iterable<JournalLine> lines, JournalSide side) {
    final map = <String, Decimal>{};
    for (final line in lines.where((l) => l.side == side)) {
      map.update(line.account.name, (v) => v + line.amount,
          ifAbsent: () => line.amount);
    }
    return map;
  }

  Map<String, Decimal> expectedBySide(JournalSide side) {
    final map = <String, Decimal>{};
    for (final line in expected.expectedLines.where((l) => l.side == side)) {
      map.update(line.accountName, (v) => v + line.amount,
          ifAbsent: () => line.amount);
    }
    return map;
  }

  final feedback = <LineFeedback>[];
  var correct = true;

  for (final side in [JournalSide.debit, JournalSide.credit]) {
    final expMap = expectedBySide(side);
    final userMap = group(userEntry.lines, side);

    for (final entry in expMap.entries) {
      // Find the user's line for this expected account (tolerant name match).
      String? matchedKey;
      for (final key in userMap.keys) {
        final account = ChartOfAccounts.byName(key) ??
            Account(key, AccountCategory.asset);
        if (account.matchesName(entry.key)) {
          matchedKey = key;
          break;
        }
      }
      if (matchedKey == null) {
        correct = false;
        feedback.add(LineFeedback(
          kind: LineFeedbackKind.missing,
          accountName: entry.key,
          side: side,
          expectedAmount: entry.value,
          message: 'Missing: ${side.name} ${entry.key} for ${formatAmount(entry.value)}.',
        ));
      } else {
        final actual = userMap[matchedKey]!;
        if (actual == entry.value) {
          feedback.add(LineFeedback(
            kind: LineFeedbackKind.correct,
            accountName: entry.key,
            side: side,
            expectedAmount: entry.value,
          ));
        } else {
          correct = false;
          feedback.add(LineFeedback(
            kind: LineFeedbackKind.wrongAmount,
            accountName: entry.key,
            side: side,
            expectedAmount: entry.value,
            actualAmount: actual,
            message:
                '${side.name} ${entry.key} should be ${formatAmount(entry.value)} but you entered ${formatAmount(actual)}.',
          ));
        }
        userMap.remove(matchedKey);
      }
    }

    // Anything left in the user map is extra.
    for (final entry in userMap.entries) {
      correct = false;
      feedback.add(LineFeedback(
        kind: LineFeedbackKind.extra,
        accountName: entry.key,
        side: side,
        expectedAmount: Decimal.zero,
        actualAmount: entry.value,
        message: 'Unexpected ${side.name} to ${entry.key} for ${formatAmount(entry.value)}.',
      ));
    }
  }

  return JournalCheckResult(
    isCorrect: correct && structural.isValid,
    structuralErrors: structural.isValid ? const [] : structural.errors,
    feedback: feedback,
  );
}

String formatAmount(Decimal amount) {
  final raw = amount.toString();
  return raw.endsWith('.00') ? raw.substring(0, raw.length - 3) : raw;
}
