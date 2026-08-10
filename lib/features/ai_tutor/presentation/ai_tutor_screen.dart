import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/ai_tutor_service.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key, this.topicId, this.questionId});

  final String? topicId;
  final String? questionId;

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();
  final List<TutorMessage> _messages = [];
  bool _busy = false;
  TutorContext? _context;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContext();
    _messages.add(const TutorMessage(
      role: 'assistant',
      text: 'Hi! I\'m your accounting tutor. Ask me anything — "why is this '
          'account debited?", "explain depreciation simply", "check my journal '
          'entry", or "give me a harder question". I teach through reasoning '
          'first, and I adapt to your level.',
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final content = ref.read(contentRepositoryProvider);
    if (widget.topicId != null) {
      final location = await content.findTopic(widget.topicId!);
      if (location != null && mounted) {
        setState(() {
          _context = TutorContext(
            lessonTitle: location.topic.lesson?.title ?? location.topic.title,
            lessonSummary: location.topic.lesson?.summary,
            lessonSections: [
              for (final s in location.topic.lesson?.sections ?? const [])
                '${s.heading}: ${s.body}',
            ],
            skill: location.topic.skills.isEmpty ? null : location.topic.skills.first,
          );
        });
      }
    }
    if (widget.questionId != null) {
      final question = await content.findQuestion(widget.questionId!);
      if (question != null && mounted) {
        setState(() {
          _context = TutorContext(
            question: question.stem,
            skill: question.skills.isEmpty ? null : question.skills.first,
          );
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(TutorMessage(role: 'user', text: text));
      _busy = true;
      _error = null;
    });
    _controller.clear();

    final level = tutorLevelFromIndex(
        ref.read(learnerStateProvider).valueOrNull?.profile.startingLevelIndex ?? 1);
    final service = ref.read(aiTutorServiceProvider);
    try {
      final answer = await service.ask(
        prompt: text,
        level: level,
        context: _context,
        history: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(TutorMessage(role: 'assistant', text: answer));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = tutorLevelFromIndex(
        ref.watch(learnerStateProvider).valueOrNull?.profile.startingLevelIndex ?? 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting Tutor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.school_rounded, size: 16),
                label: Text(tutorLevelLabel(level)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final message in _messages)
                  _MessageBubble(message: message),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Text('Thinking…'),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.coral, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(_error!,
                              style: AppTypography.bodySmall),
                        ),
                        TextButton(
                          onPressed: () {
                            // Retry the last user question.
                            final lastUser = _messages.lastWhere(
                                (m) => m.role == 'user',
                                orElse: () => const TutorMessage(
                                    role: 'user', text: ''));
                            if (lastUser.text.isNotEmpty) _send();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask the tutor…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TutorMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            bottomLeft: Radius.circular(isUser ? AppSpacing.radiusLg : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppSpacing.radiusLg),
          ),
          border: isUser
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Text(
          message.text,
          style: isUser ? AppTypography.body : AppTypography.bodySmall,
        ),
      ),
    );
  }
}
