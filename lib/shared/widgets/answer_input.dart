import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/question.dart';
import '../../domain/accounting/journal.dart';
import 'journal_entry_editor.dart';

/// Renders the appropriate answer control for a [QuestionData] and reports a
/// validated [UserAnswer] via [onSubmit]. Shared by assessment + practice.
class AnswerInput extends StatefulWidget {
  const AnswerInput({
    super.key,
    required this.question,
    required this.onSubmit,
    this.submitLabel = 'Submit',
    this.compact = false,
  });

  final QuestionData question;
  final ValueChanged<UserAnswer> onSubmit;
  final String submitLabel;
  final bool compact;

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput> {
  final _textController = TextEditingController();
  final Set<String> _selected = {};
  JournalEntry? _journal;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// AnswerInput State is reused across questions (the widget updates in
  /// place), so every piece of user input must be reset when the question
  /// changes — otherwise the previous question's selection/text/journal
  /// silently leaks into the next one.
  @override
  void didUpdateWidget(AnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _selected.clear();
      _textController.clear();
      _journal = null;
    }
  }

  void _submit() {
    final q = widget.question;
    switch (q.type) {
      case QuestionType.mcq:
      case QuestionType.trueFalse:
      case QuestionType.errorCorrection:
      case QuestionType.caseStudy:
        if (_selected.isEmpty) return;
        widget.onSubmit(
          UserAnswer(selectedKeys: _selected.toList()..sort()),
        );
      case QuestionType.numerical:
      case QuestionType.fillBlank:
      case QuestionType.financialStatement:
        final text = _textController.text.trim();
        if (text.isEmpty) return;
        widget.onSubmit(UserAnswer(text: text));
      case QuestionType.journalEntry:
        final entry = _journal;
        if (entry == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete the entry — debits must equal credits.'),
            ),
          );
          return;
        }
        widget.onSubmit(UserAnswer(journal: entry));
      default:
        break;
    }
  }

  void _toggleOption(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (q.type) {
          QuestionType.mcq ||
          QuestionType.errorCorrection ||
          QuestionType.caseStudy =>
            _mcqOptions(q),
          QuestionType.trueFalse => _trueFalseOptions(q),
          QuestionType.numerical ||
          QuestionType.financialStatement =>
            _numberField(q),
          QuestionType.fillBlank => _textField(q),
          QuestionType.journalEntry => JournalEntryEditor(
              // A fresh editor per question: the editor keeps its own line
              // state, which must not survive into the next question.
              key: ValueKey(q.id),
              onChanged: (entry) => _journal = entry,
            ),
          _ => _mcqOptions(q),
        },
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }

  Widget _mcqOptions(QuestionData q) {
    return Column(
      children: [
        for (final option in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _OptionTile(
              keyText: option.key,
              text: option.text,
              selected: _selected.contains(option.key),
              onTap: () => _toggleOption(option.key),
            ),
          ),
      ],
    );
  }

  Widget _trueFalseOptions(QuestionData q) {
    return Row(
      children: [
        for (final option in q.options)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: option.key == q.options.first.key
                    ? AppSpacing.sm
                    : 0,
              ),
              child: _OptionTile(
                keyText: option.key,
                text: option.text,
                selected: _selected.contains(option.key),
                onTap: () => _toggleOption(option.key),
                horizontal: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _numberField(QuestionData q) {
    return TextField(
      controller: _textController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: const InputDecoration(
        labelText: 'Your answer',
        hintText: 'e.g. 3,20,000 or 320000',
        prefixText: '₹ ',
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _textField(QuestionData q) {
    return TextField(
      controller: _textController,
      decoration: const InputDecoration(labelText: 'Your answer'),
      onSubmitted: (_) => _submit(),
    );
  }

}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.keyText,
    required this.text,
    required this.selected,
    required this.onTap,
    this.horizontal = false,
  });

  final String keyText;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.1) : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _badge(keyText, scheme),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: Text(text, style: AppTypography.label)),
                  ],
                )
              : Row(
                  children: [
                    _badge(keyText, scheme),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(text, style: AppTypography.body),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: scheme.primary),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _badge(String key, ColorScheme scheme) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? scheme.primary : scheme.outline),
      ),
      child: Text(
        key,
        style: AppTypography.caption.copyWith(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

