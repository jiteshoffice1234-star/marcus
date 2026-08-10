import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/money.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/journal.dart';

/// A composable journal-entry editor shared by practice questions and the
/// accounting simulator. Reports the current (balanced) entry via
/// [onChanged]; reports null while incomplete or unbalanced.
class JournalEntryEditor extends StatefulWidget {
  const JournalEntryEditor({
    super.key,
    required this.onChanged,
    this.maxLines = 6,
    this.autoSubmitOnBalance = false,
  });

  final ValueChanged<JournalEntry?> onChanged;
  final int maxLines;

  /// When true, submits (via [onChanged]) as soon as the entry balances.
  final bool autoSubmitOnBalance;

  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  final List<_Line> _lines = [];

  void _emit() {
    widget.onChanged(_buildEntry());
  }

  JournalEntry? _buildEntry() {
    final valid = _lines
        .where((l) => l.amountText.trim().isNotEmpty)
        .map((l) {
      final amount = tryParseAmount(l.amountText);
      if (amount == null || amount <= Decimal.zero) return null;
      return JournalLine(account: l.account, side: l.side, amount: amount);
    })
        .toList();
    if (valid.any((l) => l == null)) return null;
    final lines = valid.cast<JournalLine>();
    if (lines.isEmpty) return null;
    final entry = JournalEntry(lines);
    return entry.isBalanced ? entry : null;
  }

  Decimal? get totalDebits {
    var total = Decimal.zero;
    var any = false;
    for (final l in _lines) {
      final amount = tryParseAmount(l.amountText);
      if (amount == null) continue;
      any = true;
      if (l.side == JournalSide.debit) total += amount;
    }
    return any ? total : null;
  }

  Decimal? get totalCredits {
    var total = Decimal.zero;
    var any = false;
    for (final l in _lines) {
      final amount = tryParseAmount(l.amountText);
      if (amount == null) continue;
      any = true;
      if (l.side == JournalSide.credit) total += amount;
    }
    return any ? total : null;
  }

  void _addLine() {
    setState(() {
      if (_lines.length >= widget.maxLines) return;
      _lines.add(_Line(
        account: ChartOfAccounts.cash,
        side: JournalSide.debit,
        amountText: '',
      ));
      _emit();
    });
  }

  void _updateLine(int index, _Line line) {
    setState(() {
      _lines[index] = line;
      _emit();
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dr = totalDebits;
    final cr = totalCredits;
    final balanced = dr != null && cr != null && dr == cr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _LineEditor(
              key: ValueKey('journal_line_$i'),
              line: _lines[i],
              onChanged: (l) => _updateLine(i, l),
              onRemove: () => _removeLine(i),
            ),
          ),
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'No lines yet — add a debit and a credit.',
              style: AppTypography.caption,
            ),
          ),
        OutlinedButton.icon(
          onPressed: _lines.length >= widget.maxLines ? null : _addLine,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add line'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (dr != null || cr != null)
          Row(
            children: [
              Text(
                'Debits: ${dr == null ? '—' : formatIndian(dr)}',
                style: AppTypography.caption,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                'Credits: ${cr == null ? '—' : formatIndian(cr)}',
                style: AppTypography.caption,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          balanced
              ? 'Balanced ✓'
              : dr != null && cr != null
                  ? 'Not balanced — difference ${formatIndian((dr - cr).abs())}'
                  : 'Enter amounts on both sides to balance',
          style: AppTypography.caption.copyWith(
            color: balanced
                ? AppColors.emerald
                : Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Line {
  _Line({required this.account, required this.side, required this.amountText});
  Account account;
  JournalSide side;
  String amountText;
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  final _Line line;
  final ValueChanged<_Line> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<Account>(
            initialValue: line.account,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              for (final a in ChartOfAccounts.all)
                DropdownMenuItem(value: a, child: Text(a.name)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(_Line(account: v, side: line.side, amountText: line.amountText));
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: SegmentedButton<JournalSide>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: JournalSide.debit, label: Text('Dr')),
              ButtonSegment(value: JournalSide.credit, label: Text('Cr')),
            ],
            selected: {line.side},
            onSelectionChanged: (s) => onChanged(
                _Line(account: line.account, side: s.first, amountText: line.amountText)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: TextFormField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
            initialValue: line.amountText,
            onChanged: (v) =>
                onChanged(_Line(account: line.account, side: line.side, amountText: v)),
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }
}
