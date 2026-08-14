import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/question.dart';
import '../../../domain/assessment/assessment_engine.dart';
import '../../../domain/assessment/roadmap_builder.dart';
import '../../../shared/widgets/answer_input.dart';
import '../../../shared/widgets/state_views.dart';

enum _Step { welcome, assessment, result, roadmap }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.welcome;

  // Assessment state
  List<QuestionData> _questions = [];
  int _index = 0;
  final List<String> _answeredSkills = [];
  final List<bool> _correctness = [];
  AssessmentResult? _result;
  List<RoadmapItem> _roadmap = [];

  Future<void> _startAssessment() async {
    setState(() => _step = _Step.assessment);
    final questions =
        await ref.read(contentRepositoryProvider).loadAssessmentQuestions();
    if (!mounted) return;
    setState(() {
      _questions = (questions.take(AppConfig.assessmentQuestionCount)).toList();
      _index = 0;
    });
  }

  void _onAnswered(QuestionData question, UserAnswer answer) {
    final result = checkAnswer(question, answer);
    setState(() {
      _answeredSkills
          .add(question.skills.isNotEmpty ? question.skills.first : 'foundation');
      _correctness.add(result.isCorrect);
      _index += 1;
    });
    if (_index >= _questions.length) {
      _finalizeAssessment();
    }
  }

  Future<void> _finalizeAssessment() async {
    final result = scoreAssessment(
      answeredSkills: _answeredSkills,
      correctness: _correctness,
      totalQuestions: _questions.length,
    );
    await ref.read(learnerStateProvider.notifier).applyAssessment(result);
    if (!mounted) return;
    setState(() {
      _result = result;
      _step = _Step.result;
    });
  }

  Future<void> _buildRoadmap() async {
    final content = ref.read(contentRepositoryProvider);
    final index = await content.loadIndex();
    final levels = <RoadmapLevelInput>[];
    for (final meta in index.levels) {
      final level = await content.loadLevel(meta.id);
      levels.add(level.toRoadmapInput());
    }
    final roadmap = RoadmapBuilder.build(
      assessment: _result!,
      levels: levels,
    );
    if (!mounted) return;
    setState(() {
      _roadmap = roadmap;
      _step = _Step.roadmap;
    });
  }

  Future<void> _finish() async {
    await ref
        .read(learnerStateProvider.notifier)
        .setOnboarded(assessmentTaken: true);
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          _Step.welcome => _WelcomeStep(onBegin: _startAssessment),
          _Step.assessment => _AssessmentStep(
              questions: _questions,
              index: _index,
              onAnswered: _onAnswered,
            ),
          _Step.result => _ResultStep(
              result: _result!,
              onNext: _buildRoadmap,
            ),
          _Step.roadmap => _RoadmapStep(
              items: _roadmap,
              onFinish: _finish,
            ),
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onBegin});

  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.account_balance_rounded,
                  size: 56, color: scheme.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Welcome to ${AppConfig.appName}',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A complete accounting journey — from your first journal entry '
                'to CA Final-level financial reporting.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Your journey starts with a short knowledge assessment',
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Answer ${AppConfig.assessmentQuestionCount} questions and we will '
                'map your strengths and weaknesses, recommend your starting '
                'level, and build a personalized roadmap.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onBegin, child: const Text('Begin assessment')),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Create account / Sign in'),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppConfig.qualificationDisclaimer,
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AssessmentStep extends StatelessWidget {
  const _AssessmentStep({
    required this.questions,
    required this.index,
    required this.onAnswered,
  });

  final List<QuestionData> questions;
  final int index;
  final void Function(QuestionData, UserAnswer) onAnswered;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const LoadingView(label: 'Preparing your assessment…');
    }
    // After the last answer the index is advanced to questions.length before
    // the results step is shown — render a scoring state instead of indexing
    // out of range.
    if (index >= questions.length) {
      return const LoadingView(label: 'Scoring your assessment…');
    }
    final question = questions[index];
    final progress = (index) / questions.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Knowledge assessment',
                    style: AppTypography.subtitle,
                  ),
                  const Spacer(),
                  Text(
                    '${index + 1} / ${questions.length}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.stem, style: AppTypography.title),
                  const SizedBox(height: AppSpacing.xl),
                  AnswerInput(
                    question: question,
                    onSubmit: (answer) => onAnswered(question, answer),
                    submitLabel: index == questions.length - 1
                        ? 'Finish assessment'
                        : 'Next question',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultStep extends StatelessWidget {
  const _ResultStep({required this.result, required this.onNext});

  final AssessmentResult result;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (result.accuracy * 100).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your skill profile',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Text(
                        '$pct%',
                        style: AppTypography.displayLarge.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${result.correctAnswers} of ${result.totalQuestions} correct',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Recommended starting level:',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _levelTitle(result.recommendedLevelIndex),
                        style: AppTypography.title,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Skills breakdown', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              for (final skill in result.skills)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SkillBar(skill: skill),
                ),
              if (result.weakSkills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'We will start by strengthening: '
                  '${result.weakSkills.map((s) => s.label).join(', ')}.',
                  style: AppTypography.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onNext, child: const Text('View my roadmap')),
            ],
          ),
        ),
      ),
    );
  }
}

String _levelTitle(int levelIndex) => switch (levelIndex) {
      1 => 'Level 1 · Accounting Foundation',
      2 => 'Level 2 · Professional Accounting',
      3 => 'Level 3 · Advanced Accounting',
      _ => 'Level 4 · CA Final Level',
    };

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.skill});

  final SkillScore skill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (skill.accuracy * 100).round();
    final color = skill.isWeak
        ? AppColors.coral
        : skill.isStrong
            ? AppColors.emerald
            : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(skill.label, style: AppTypography.label)),
            Text('$pct%',
                style: AppTypography.caption.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: skill.accuracy,
            minHeight: 8,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({required this.items, required this.onFinish});

  final List<RoadmapItem> items;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your personalized roadmap',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Weak areas are prioritized first, then the curriculum from '
                'your recommended level onward.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < items.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: items[i].isPriority
                            ? AppColors.coral.withValues(alpha: 0.12)
                            : scheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: items[i].isPriority
                              ? AppColors.coral
                              : scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].reason,
                              style: AppTypography.label),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Level ${items[i].levelIndex}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (i != items.length - 1) const SizedBox(height: AppSpacing.lg),
              ],
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(onPressed: onFinish, child: const Text('Start learning')),
            ],
          ),
        ),
      ),
    );
  }
}
