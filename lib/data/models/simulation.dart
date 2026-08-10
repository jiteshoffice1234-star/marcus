import 'package:decimal/decimal.dart';

import '../../core/utils/money.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/journal.dart';
import '../../domain/accounting/ledger.dart';
import '../../domain/accounting/simulator_engine.dart';

class SimTransactionData {
  const SimTransactionData({
    required this.seq,
    required this.narration,
    this.hints = const [],
    this.expectedLines = const [],
  });

  final int seq;
  final String narration;
  final List<String> hints;
  final List<({String account, String side, String amount})> expectedLines;

  factory SimTransactionData.fromJson(Map<String, dynamic> json) =>
      SimTransactionData(
        seq: json['seq'] as int,
        narration: json['narration'] as String,
        hints: (json['hints'] as List<dynamic>? ?? const []).cast<String>(),
        expectedLines: (json['expectedJournal'] as List<dynamic>? ?? const [])
            .map((e) => (
                  account: (e as Map<String, dynamic>)['account'] as String,
                  side: e['side'] as String,
                  amount: e['amount'] as String,
                ))
            .toList(),
      );

  SimulatorTransactionSpec toSpec() => SimulatorTransactionSpec(
        seq: seq,
        narration: narration,
        hints: hints,
        expectedLines: [
          for (final l in expectedLines)
            ExpectedJournalLine(
              accountName: l.account,
              side: l.side == 'credit' ? JournalSide.credit : JournalSide.debit,
              amount: tryParseAmount(l.amount) ?? Decimal.zero,
            ),
        ],
      );
}

class SimulationScenario {
  const SimulationScenario({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.companyName,
    required this.industry,
    this.levelIndex = 2,
    this.openingBalances = const {},
    this.transactions = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String companyName;
  final String industry;
  final int levelIndex;

  /// Opening balances: accountName -> amount string (positive = normal balance).
  final Map<String, String> openingBalances;

  final List<SimTransactionData> transactions;

  factory SimulationScenario.fromJson(Map<String, dynamic> json) =>
      SimulationScenario(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        companyName: json['companyName'] as String,
        industry: json['industry'] as String? ?? '',
        levelIndex: json['levelIndex'] as int? ?? 2,
        openingBalances: (json['openingBalances']
                as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map((e) => SimTransactionData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The ledger seeded with opening balances.
  Ledger buildOpeningLedger() {
    final ledger = Ledger();
    for (final entry in openingBalances.entries) {
      final account = ChartOfAccounts.byName(entry.key) ??
          Account(entry.key, AccountCategory.asset);
      final amount = tryParseAmount(entry.value) ?? Decimal.zero;
      ledger.postOpeningBalance(account.name, account.category, amount);
    }
    return ledger;
  }
}
