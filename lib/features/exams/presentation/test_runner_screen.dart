import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/question.dart';
import '../../../data/models/test_definition.dart';
import '../../../shared/widgets/answer_input.dart';
import '../../../shared/widgets/state_views.dart';
import '../../practice/presentation/question_player_screen.dart' show correctAnswerText;

final testDefinitionProvider = FutureProvider.family((ref, String testId) {
  return ref.read(contentRepositoryProvider).loadTests().then(
        (tests) => tests.where((t) => t.id == testId).firstOrNull,
      );
});

/// Resolves the questions a test covers (explicit list or scope).
Future<List<QuestionData>> resolveTestQuestions(
  TestDefinition test,
  dynamic content,
) async {
  if (test.questionIds.isNotEmpty) {
    final questions = <QuestionData>[];
    for (final id in test.questionIds) {
      final q = await content.findQuestion(id);
      if (q != null) questions.add(q);
    }
    return questions;
  }
  if (test.chapterId != null) {
    final location = await content.findChapter(test.chapterId!);
    if (location == null) return [];
    return [
      for (final topic in location.chapter.topics) ...topic.questions,
    ];
  }
  final index = await content.loadIndex();
  final levels = <QuestionData>[];
  for (final meta in index.levels) {
    if (test.kind == TestKind.professional && meta.levelIndex != 2) continue;
    if (test.levelIndex != null && meta.levelIndex != test.levelIndex) continue;
    final level = await content.loadLevel(meta.id);
    levels.addAll(level.allQuestions);
  }
  return levels;
}

class TestRunnerScreen extends ConsumerStatefulWidget {
  const TestRunnerScreen({super.key, required this.testId});

  final String testId;

  @override
  ConsumerState<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends ConsumerState<TestRunnerScreen> {
  final Map<String, UserAnswer> _answers = {};
  final Set<String> _marked = {};
  int _index = 0;
  Timer? _timer;
  int _elapsed = 0;
  bool _submitted = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit(TestDefinition test, List<QuestionData> questions) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit test?'),
        content: Text(
          '${_answers.length} of ${questions.length} answered. '
          'Unanswered questions are marked skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _timer?.cancel();

    final results = <_TestQuestionResult>[];
    var correctCount = 0;
    var wrongCount = 0;
    var skippedCount = 0;
    var score = 0.0;
    var maxScore = 0.0;
    for (final q in questions) {
      final answer = _answers[q.id];
      maxScore += q.marks;
      if (answer == null || answer.isEmpty) {
        skippedCount++;
        results.add(_TestQuestionResult(q, null, null));
        continue;
      }
      final check = checkAnswer(q, answer);
      if (check.isCorrect) {
        correctCount++;
        score += q.marks;
        results.add(_TestQuestionResult(q, check, true));
      } else {
        wrongCount++;
        score -= q.negativeMarks;
        results.add(_TestQuestionResult(q, check, false));
      }
      // Feed the mistake intelligence + revision engine.
      await ref
          .read(learnerStateProvider.notifier)
          .recordAnswer(question: q, correct: check.isCorrect, source: 'test');
    }
    await ref.read(learnerStateProvider.notifier).completeTest(
          correctCount: correctCount,
          totalCount: questions.length,
        );

    if (!mounted) return;
    setState(() => _submitted = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TestResultsSheet(
        test: test,
        results: results,
        score: score,
        maxScore: maxScore,
        correctCount: correctCount,
        wrongCount: wrongCount,
        skippedCount: skippedCount,
        onDone: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testAsync = ref.watch(testDefinitionProvider(widget.testId));
    return testAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingView(label: 'Preparing test…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: e.toString()),
      ),
      data: (test) {
        if (test == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorState(message: 'Test not found.'),
          );
        }
        return FutureBuilder(
          future: resolveTestQuestions(
              test, ref.read(contentRepositoryProvider)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                appBar: AppBar(),
                body: const LoadingView(label: 'Loading questions…'),
              );
            }
            final questions = snapshot.data ?? const <QuestionData>[];
            if (questions.isEmpty) {
              return Scaffold(
                appBar: AppBar(),
                body: const EmptyState(
                  icon: Icons.quiz_outlined,
                  title: 'No questions',
                  message: 'This test has no questions yet.',
                ),
              );
            }
            if (_submitted) {
              return Scaffold(appBar: AppBar(), body: const LoadingView());
            }
            _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) setState(() => _elapsed += 1);
            });
            return _Runner(
              test: test,
              questions: questions,
              index: _index,
              answers: _answers,
              marked: _marked,
              elapsed: _elapsed,
              onAnswer: (q, a) => setState(() => _answers[q.id] = a),
              onNavigate: (i) => setState(() => _index = i),
              onToggleMark: (id) => setState(() {
                if (_marked.contains(id)) {
                  _marked.remove(id);
                } else {
                  _marked.add(id);
                }
              }),
              onSubmit: () => _submit(test, questions),
            );
          },
        );
      },
    );
  }
}

class _Runner extends StatelessWidget {
  const _Runner({
    required this.test,
    required this.questions,
    required this.index,
    required this.answers,
    required this.marked,
    required this.elapsed,
    required this.onAnswer,
    required this.onNavigate,
    required this.onToggleMark,
    required this.onSubmit,
  });

  final TestDefinition test;
  final List<QuestionData> questions;
  final int index;
  final Map<String, UserAnswer> answers;
  final Set<String> marked;
  final int elapsed;
  final void Function(QuestionData, UserAnswer) onAnswer;
  final void Function(int) onNavigate;
  final void Function(String) onToggleMark;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    final minutes = (test.durationMinutes * 60 - elapsed) ~/ 60;
    final seconds = (test.durationMinutes * 60 - elapsed) % 60;
    final timeUp = test.durationMinutes * 60 - elapsed <= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(test.title, style: AppTypography.subtitle),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: timeUp
                  ? AppColors.coral.withValues(alpha: 0.15)
                  : AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              timeUp ? 'TIME UP' : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: AppTypography.label.copyWith(
                color: timeUp ? AppColors.coral : AppColors.emeraldDark,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (index + 1) / questions.length,
            minHeight: 3,
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Chip(label: Text(q.difficulty.starsLabel)),
                      Chip(
                        label: Text('${q.marks} mark${q.marks == 1 ? '' : 's'}'),
                      ),
                      if (q.negativeMarks > 0)
                        Chip(
                          label: Text('-${q.negativeMarks} wrong'),
                          backgroundColor:
                              AppColors.coral.withValues(alpha: 0.1),
                        ),
                      Chip(label: Text('${index + 1} of ${questions.length}')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(q.stem, style: AppTypography.title.copyWith(fontSize: 19)),
                  const SizedBox(height: AppSpacing.xl),
                  AnswerInput(
                    question: q,
                    onSubmit: (a) => onAnswer(q, a),
                    submitLabel: 'Save answer',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onToggleMark(q.id),
                        icon: Icon(
                          marked.contains(q.id)
                              ? Icons.flag_rounded
                              : Icons.flag_outlined,
                          size: 18,
                        ),
                        label: Text(
                          marked.contains(q.id)
                              ? 'Marked for review'
                              : 'Mark for review',
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed:
                            index > 0 ? () => onNavigate(index - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        onPressed: index < questions.length - 1
                            ? () => onNavigate(index + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Question palette', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (var i = 0; i < questions.length; i++)
                        _PaletteDot(
                          number: i + 1,
                          state: i == index
                              ? _PaletteState.current
                              : answers[questions[i].id] != null
                                  ? _PaletteState.answered
                                  : marked.contains(questions[i].id)
                                      ? _PaletteState.marked
                                      : _PaletteState.unanswered,
                          onTap: () => onNavigate(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSubmit,
                      child: const Text('Submit test'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PaletteState { current, answered, marked, unanswered }

class _PaletteDot extends StatelessWidget {
  const _PaletteDot({
    required this.number,
    required this.state,
    required this.onTap,
  });

  final int number;
  final _PaletteState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (state) {
      _PaletteState.current => (scheme.primary, scheme.onPrimary),
      _PaletteState.answered => (AppColors.emerald, Colors.white),
      _PaletteState.marked => (AppColors.amber, Colors.white),
      _PaletteState.unanswered => (scheme.surface, scheme.onSurface),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: state == _PaletteState.unanswered
                ? scheme.outline
                : Colors.transparent,
          ),
        ),
        child: Text(
          '$number',
          style: AppTypography.caption.copyWith(color: fg),
        ),
      ),
    );
  }
}

class _TestQuestionResult {
  const _TestQuestionResult(this.question, this.check, this.correct);
  final QuestionData question;
  final AnswerCheckResult? check;
  final bool? correct;
}

class _TestResultsSheet extends StatelessWidget {
  const _TestResultsSheet({
    required this.test,
    required this.results,
    required this.score,
    required this.maxScore,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.onDone,
  });

  final TestDefinition test;
  final List<_TestQuestionResult> results;
  final double score;
  final double maxScore;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pct = maxScore == 0 ? 0.0 : score / maxScore * 100;
    final passed = pct >= test.passPercentage;
    final accuracy = results.isEmpty
        ? 0.0
        : correctCount / (correctCount + wrongCount);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Test results', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Score', style: AppTypography.caption),
                      Text(
                        '$score / $maxScore',
                        style: AppTypography.title,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Percentage', style: AppTypography.caption),
                      Text('${pct.round()}%', style: AppTypography.title),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Accuracy', style: AppTypography.caption),
                      Text('${(accuracy * 100).round()}%',
                          style: AppTypography.title),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Correct / Wrong / Skipped',
                          style: AppTypography.caption),
                      Text('$correctCount / $wrongCount / $skippedCount',
                          style: AppTypography.label),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: (passed ? AppColors.emerald : AppColors.coral)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      passed
                          ? 'PASSED — pass mark ${test.passPercentage.round()}%'
                          : 'NOT PASSED — pass mark ${test.passPercentage.round()}%',
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: passed ? AppColors.emerald : AppColors.coral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Question review', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < results.length; i++)
            _ReviewTile(result: results[i], number: i + 1),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: onDone, child: const Text('Done')),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.result, required this.number});

  final _TestQuestionResult result;
  final int number;

  @override
  Widget build(BuildContext context) {
    final q = result.question;
    final correct = result.correct;
    final color = correct == null
        ? AppColors.textTertiaryLight
        : correct
            ? AppColors.emerald
            : AppColors.coral;
    return Card(
      child: ExpansionTile(
        leading: Icon(
          correct == null
              ? Icons.help_outline_rounded
              : correct
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
          color: color,
        ),
        title: Text('$number. ${q.stem}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          correct == null
              ? 'Skipped'
              : correct
                  ? 'Correct'
                  : 'Incorrect — ${correctAnswerText(q)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: color),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (correct == false)
                  Text('Correct answer: ${correctAnswerText(q)}',
                      style: AppTypography.label),
                if (q.explanation.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(q.explanation, style: AppTypography.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
