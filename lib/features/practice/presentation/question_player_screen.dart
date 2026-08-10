import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/global_error_handler.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/question.dart';
import '../../../shared/widgets/answer_input.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/question_picker.dart';

class QuestionPlayerScreen extends ConsumerStatefulWidget {
  const QuestionPlayerScreen({
    super.key,
    this.topicId,
    this.mode = 'quick',
    this.count = 10,
    this.sourceTestId,
  });

  final String? topicId;
  final String mode;
  final int count;
  final String? sourceTestId;

  @override
  ConsumerState<QuestionPlayerScreen> createState() =>
      _QuestionPlayerScreenState();
}

class _QuestionPlayerScreenState extends ConsumerState<QuestionPlayerScreen> {
  List<PracticeQuestion>? _questions;
  int _index = 0;
  AnswerCheckResult? _lastCheck;
  final List<_AnswerOutcome> _outcomes = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _questions = null;
      _error = null;
    });
    try {
      final learner = ref.read(learnerStateProvider).valueOrNull;
      final picker = QuestionPicker(ref.read(contentRepositoryProvider));
      final questions = await picker.pick(
        mode: widget.mode,
        topicId: widget.topicId,
        count: widget.count,
        learner: learner,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _index = 0;
        _lastCheck = null;
        _outcomes.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _onSubmit(QuestionData question, UserAnswer answer) async {
    final check = checkAnswer(question, answer);
    setState(() => _lastCheck = check);
    try {
      await ref.read(learnerStateProvider.notifier).recordAnswer(
            question: question,
            correct: check.isCorrect,
            source: widget.sourceTestId != null ? 'test' : 'practice',
          );
    } catch (e) {
      debugPrint('Failed to record answer: $e');
    }
  }

  void _next() {
    final check = _lastCheck!;
    _outcomes.add(_AnswerOutcome(
      question: _questions![_index].question,
      correct: check.isCorrect,
    ));
    setState(() {
      _lastCheck = null;
      _index += 1;
    });
  }

  void _restartWrong() {
    final wrong = _outcomes.where((o) => !o.correct).toList();
    if (wrong.isEmpty) return;
    setState(() {
      _questions = [
        for (final w in wrong)
          PracticeQuestion(
            question: w.question,
            topicTitle: _questions!.firstWhere((p) => p.question.id == w.question.id).topicTitle,
            levelTitle: _questions!.firstWhere((p) => p.question.id == w.question.id).levelTitle,
          ),
      ];
      _index = 0;
      _lastCheck = null;
      _outcomes.clear();
    });
  }

  bool get _finished =>
      _questions != null && _index >= _questions!.length && _lastCheck == null;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: ErrorState(
          message: friendlyErrorMessage(_error!),
          onRetry: _load,
        ),
      );
    }
    if (_questions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const LoadingView(label: 'Preparing questions…'),
      );
    }
    if (_finished) {
      return _ResultsView(
        outcomes: _outcomes,
        onReview: wrongCount > 0 ? _restartWrong : null,
        onDone: () => context.pop(),
      );
    }

    final item = _questions![_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          Text(
            '${_index + 1} / ${_questions!.length}',
            style: AppTypography.caption,
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_index + (_lastCheck == null ? 0 : 1)) / _questions!.length,
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _lastCheck == null
                    ? _QuestionCard(
                        item: item,
                        onSubmit: (a) => _onSubmit(item.question, a),
                      )
                    : _AnswerExperience(
                        item: item,
                        check: _lastCheck!,
                        onNext: _next,
                        isLast: _index == _questions!.length - 1,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get wrongCount => _outcomes.where((o) => !o.correct).length;
}

class _AnswerOutcome {
  const _AnswerOutcome({required this.question, required this.correct});
  final QuestionData question;
  final bool correct;
}

// ---------------------------------------------------------------------------

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item, required this.onSubmit});

  final PracticeQuestion item;
  final ValueChanged<UserAnswer> onSubmit;

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Chip(label: Text(item.levelTitle)),
            Chip(
              label: Text('${q.difficulty.starsLabel} ${q.difficulty.label}'),
              backgroundColor: q.difficulty.accent.withValues(alpha: 0.12),
            ),
            Chip(label: Text(q.type.label)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(q.stem, style: AppTypography.title.copyWith(fontSize: 19)),
        const SizedBox(height: AppSpacing.xl),
        AnswerInput(question: q, onSubmit: onSubmit),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _AnswerExperience extends StatelessWidget {
  const _AnswerExperience({
    required this.item,
    required this.check,
    required this.onNext,
    required this.isLast,
  });

  final PracticeQuestion item;
  final AnswerCheckResult check;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    final correct = check.isCorrect;
    final color = correct ? AppColors.emerald : AppColors.coral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct ? 'Correct' : 'Not quite',
                      style: AppTypography.title.copyWith(color: color),
                    ),
                    if (!correct) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Correct answer: ${correctAnswerText(q)}',
                        style: AppTypography.label,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (q.explanation.isNotEmpty) ...[
          _Block(
            icon: Icons.lightbulb_rounded,
            title: 'Why this is correct',
            body: q.explanation,
          ),
        ],
        if (q.whyOthersWrong.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Block(
            icon: Icons.alt_route_rounded,
            title: 'Why the others are wrong',
            body: q.whyOthersWrong
                .map((e) => '${e.key}: ${e.why}')
                .join('\n'),
          ),
        ],
        if (q.commonMistake != null && q.commonMistake!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Block(
            icon: Icons.warning_amber_rounded,
            title: 'Common mistake',
            body: q.commonMistake!,
            color: AppColors.amber,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Related concept: ${item.topicTitle}',
                  style: AppTypography.label,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onNext,
            child: Text(isLast ? 'See results' : 'Next question'),
          ),
        ),
      ],
    );
  }
}

String correctAnswerText(QuestionData q) {
  switch (q.type) {
    case QuestionType.mcq:
    case QuestionType.trueFalse:
      final optionText = q.options
          .where((o) => q.answer.keys.contains(o.key))
          .map((o) => '${o.key}: ${o.text}')
          .join('; ');
      return optionText.isEmpty ? q.answer.keys.join(', ') : optionText;
    case QuestionType.numerical:
      return q.answer.value ?? q.answer.accepted.firstOrNull ?? '';
    case QuestionType.fillBlank:
      return q.answer.accepted.firstOrNull ?? '';
    case QuestionType.journalEntry:
      return q.answer.journalLines
          .map((l) =>
              '${l.side == 'debit' ? 'Dr' : 'Cr'} ${l.account} ${l.amount}')
          .join('\n');
    default:
      return q.answer.keys.join(', ');
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.body,
    this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTypography.subtitle),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTypography.body),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.outcomes,
    required this.onReview,
    required this.onDone,
  });

  final List<_AnswerOutcome> outcomes;
  final VoidCallback? onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final correct = outcomes.where((o) => o.correct).length;
    final accuracy = outcomes.isEmpty ? 0.0 : correct / outcomes.length;
    final wrong = outcomes.where((o) => !o.correct).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(
                    '${(accuracy * 100).round()}%',
                    style: AppTypography.displayLarge.copyWith(
                      color: accuracy >= 0.7
                          ? AppColors.emerald
                          : AppColors.coral,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$correct of ${outcomes.length} correct',
                    style: AppTypography.body,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Mistake analysis', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            wrong.isEmpty
                ? 'No mistakes this round — outstanding work. '
                    'Keep the streak going!'
                : '${wrong.length} question${wrong.length == 1 ? '' : 's'} missed. '
                    'These are now in your mistake bank and revision queue.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (wrong.isNotEmpty)
            for (final w in wrong)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.replay_rounded,
                      color: AppColors.coral),
                  title: Text(
                    w.question.stem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                  subtitle: Text(
                    'Correct answer: ${correctAnswerText(w.question)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.xl),
          if (onReview != null)
            OutlinedButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Review the missed questions'),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(onPressed: onDone, child: const Text('Done')),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
