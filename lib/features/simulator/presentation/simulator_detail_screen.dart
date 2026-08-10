import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/simulation.dart';
import '../../../domain/accounting/journal.dart';
import '../../../domain/accounting/ledger.dart';
import '../../../domain/accounting/simulator_engine.dart';
import '../../../domain/accounting/statements.dart';
import '../../../domain/accounting/trial_balance.dart';
import '../../../shared/widgets/journal_entry_editor.dart';
import '../../../shared/widgets/state_views.dart';

final simulatorProvider = FutureProvider.family((ref, String simId) {
  return ref
      .read(contentRepositoryProvider)
      .loadSimulations()
      .then((list) => list.where((s) => s.id == simId).firstOrNull);
});

class SimulatorDetailScreen extends ConsumerStatefulWidget {
  const SimulatorDetailScreen({super.key, required this.simId});

  final String simId;

  @override
  ConsumerState<SimulatorDetailScreen> createState() =>
      _SimulatorDetailScreenState();
}

class _SimulatorDetailScreenState extends ConsumerState<SimulatorDetailScreen> {
  late final Ledger _ledger = Ledger();
  int _step = 0;
  JournalCheckResult? _lastCheck;
  JournalEntry? _currentEntry;
  int _attempts = 0;
  int _correctCount = 0;

  void _initLedger(SimulationScenario scenario) {
    if (_ledger.accounts.isNotEmpty) return;
    final opening = scenario.buildOpeningLedger();
    for (final account in opening.accounts) {
      _ledger.postOpeningBalance(
        account.account.name,
        account.account.category,
        account.balance,
      );
    }
  }

  void _submit(SimulationScenario scenario) {
    final entry = _currentEntry;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the entry — debits must equal credits.'),
        ),
      );
      return;
    }
    final tx = scenario.transactions[_step];
    final check = checkSimulatorJournal(entry, tx.toSpec());
    setState(() {
      _lastCheck = check;
      _attempts += 1;
    });
    if (check.isCorrect) {
      _ledger.post(entry);
      setState(() {
        _correctCount += 1;
        _currentEntry = null;
      });
    }
  }

  void _next() {
    setState(() {
      _step += 1;
      _lastCheck = null;
      _attempts = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenarioAsync = ref.watch(simulatorProvider(widget.simId));
    return scenarioAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingView(label: 'Loading simulation…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: e.toString()),
      ),
      data: (scenario) {
        if (scenario == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorState(message: 'Simulation not found.'),
          );
        }
        _initLedger(scenario);
        final completed = _step >= scenario.transactions.length;
        return Scaffold(
          appBar: AppBar(title: Text(scenario.companyName)),
          body: completed
              ? _StatementsView(
                  scenario: scenario,
                  ledger: _ledger,
                  accuracy: _correctCount / scenario.transactions.length,
                )
              : _TransactionView(
                  scenario: scenario,
                  step: _step,
                  lastCheck: _lastCheck,
                  entry: _currentEntry,
                  attempts: _attempts,
                  onEntryChanged: (e) => _currentEntry = e,
                  onSubmit: () => _submit(scenario),
                  onNext: _next,
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _TransactionView extends StatelessWidget {
  const _TransactionView({
    required this.scenario,
    required this.step,
    required this.lastCheck,
    required this.entry,
    required this.attempts,
    required this.onEntryChanged,
    required this.onSubmit,
    required this.onNext,
  });

  final SimulationScenario scenario;
  final int step;
  final JournalCheckResult? lastCheck;
  final JournalEntry? entry;
  final int attempts;
  final ValueChanged<JournalEntry?> onEntryChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tx = scenario.transactions[step];
    final accepted = lastCheck?.isCorrect ?? false;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: step / scenario.transactions.length,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${step + 1}/${scenario.transactions.length}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Transaction ${step + 1}', style: AppTypography.overline),
              const SizedBox(height: AppSpacing.xs),
              Text(tx.narration, style: AppTypography.headline),
              if (tx.hints.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Hint: ${tx.hints.join(' ')}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record the journal entry', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.md),
                  JournalEntryEditor(onChanged: onEntryChanged),
                  const SizedBox(height: AppSpacing.lg),
                  if (lastCheck != null && !accepted)
                    _FeedbackPanel(check: lastCheck!),
                  if (accepted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.emerald),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Correct! The entry has been posted to the ledger.',
                              style: AppTypography.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onNext,
                        child: Text(step == scenario.transactions.length - 1
                            ? 'View the statements'
                            : 'Next transaction'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onSubmit,
                        child: Text(attempts == 0 ? 'Check entry' : 'Try again'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.check});

  final JournalCheckResult check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Not quite — here\'s what to fix',
              style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          for (final error in check.structuralErrors)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.error_rounded, size: 16, color: AppColors.coral),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(error, style: AppTypography.bodySmall)),
                ],
              ),
            ),
          for (final line in check.feedback)
            if (line.kind != LineFeedbackKind.correct)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      line.kind == LineFeedbackKind.missing
                          ? Icons.add_circle_outline_rounded
                          : line.kind == LineFeedbackKind.extra
                              ? Icons.remove_circle_outline_rounded
                              : Icons.swap_horiz_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        line.message ?? '',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatementsView extends StatelessWidget {
  const _StatementsView({
    required this.scenario,
    required this.ledger,
    required this.accuracy,
  });

  final SimulationScenario scenario;
  final Ledger ledger;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final tb = TrialBalance.fromLedger(ledger);
    final statements = StatementBuilder.build(ledger);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulation complete',
                  style: AppTypography.title.copyWith(color: AppColors.emeraldDark),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${scenario.companyName}: all ${scenario.transactions.length} transactions '
                  'journalized correctly. Your accuracy was ${(accuracy * 100).round()}%. '
                  'These statements were produced from your accepted entries.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Trial balance'),
              Tab(text: 'Profit & Loss'),
              Tab(text: 'Balance sheet'),
              Tab(text: 'Ledger'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StatementCard(
                  title: 'Trial Balance',
                  subtitle: tb.isBalanced
                      ? 'Debits ${formatIndian(tb.totalDebits)} = Credits ${formatIndian(tb.totalCredits)} ✓'
                      : 'Not balanced — investigate!',
                  body: tb.render(),
                ),
                _StatementCard(
                  title: 'Profit & Loss Account',
                  subtitle: 'Net profit ${formatIndian(statements.pnl.netProfit)}',
                  body: statements.pnl.render(),
                ),
                _StatementCard(
                  title: 'Balance Sheet',
                  subtitle: statements.balanceSheet.isBalanced
                      ? 'Assets = Liabilities + Capital ✓'
                      : 'Out of balance — check the adjustments.',
                  body: statements.balanceSheet.render(),
                ),
                _LedgerView(ledger: ledger),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              Text(
                body,
                style: AppTypography.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final account in ledger.accounts)
          if (account.lines.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(account.account.name,
                              style: AppTypography.label),
                        ),
                        Text(
                          'Balance: ${formatIndian(account.balance)}',
                          style: AppTypography.caption.copyWith(
                            color: account.balance >= Decimal.zero
                                ? AppColors.emerald
                                : AppColors.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final line in account.lines)
                      Text(
                        '  ${line.isDebit ? 'Dr' : 'Cr'}  ${formatIndian(line.amount)}',
                        style: AppTypography.caption,
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
