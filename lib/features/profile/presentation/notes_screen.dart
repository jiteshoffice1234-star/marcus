import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/learner.dart';
import '../../../shared/widgets/state_views.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) {
          if (learner.notes.isEmpty) {
            return const EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet',
              message: 'Capture concepts, formulas and your own explanations.',
              actionLabel: 'Write your first note',
              onAction: null,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final note in learner.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        note.isMistakeNote
                            ? Icons.report_problem_rounded
                            : Icons.sticky_note_2_rounded,
                        color: note.isMistakeNote
                            ? AppColors.coral
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(note.title, style: AppTypography.label),
                      subtitle: Text(
                        note.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () =>
                            ref.read(learnerStateProvider.notifier).deleteNote(note.id),
                      ),
                      onTap: () => _showEditor(context, ref, existing: note),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, {NoteRecord? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NoteEditor(
        existing: existing,
        onSave: (title, body, isMistake) async {
          final notifier = ref.read(learnerStateProvider.notifier);
          if (existing != null) {
            await notifier.deleteNote(existing.id);
          }
          await notifier.addNote(NoteRecord(
            id: existing?.id ?? const Uuid().v4(),
            title: title,
            body: body,
            isMistakeNote: isMistake,
          ));
        },
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.existing, required this.onSave});

  final NoteRecord? existing;
  final Future<void> Function(String title, String body, bool isMistake) onSave;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _isMistake = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _body = TextEditingController(text: widget.existing?.body ?? '');
    _isMistake = widget.existing?.isMistakeNote ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'New note' : 'Edit note',
              style: AppTypography.title),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Note',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark as mistake note',
                style: AppTypography.label),
            value: _isMistake,
            onChanged: (v) => setState(() => _isMistake = v),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () async {
              final title = _title.text.trim();
              final body = _body.text.trim();
              if (title.isEmpty || body.isEmpty) return;
              await widget.onSave(title, body, _isMistake);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save note'),
          ),
        ],
      ),
    );
  }
}
