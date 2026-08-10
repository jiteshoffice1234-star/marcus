import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/state_views.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<SearchHit> _hits = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) {
      setState(() {
        _hits = [];
        _loading = false;
      });
      return;
    }
    final content = ref.read(contentRepositoryProvider);
    final hits = await content.search(query);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search lessons, topics, concepts…',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _search,
          textInputAction: TextInputAction.search,
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: _query.isEmpty
                ? const EmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search the curriculum',
                    message:
                        'Find lessons, topics, concepts, standards and your own notes.',
                    compact: true,
                  )
                : learnerAsync.when(
                    loading: () => const LoadingView(compact: true),
                    error: (e, _) => ErrorState(message: e.toString()),
                    data: (learner) => ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (_hits.isEmpty && !_loading)
                          const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message: 'Try a different term.',
                            compact: true,
                          ),
                        for (final hit in _hits)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                _iconFor(hit.type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(hit.title,
                                  style: AppTypography.label),
                              subtitle: Text(hit.subtitle,
                                  style: AppTypography.caption),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  context.push('/learn/topic/${hit.topicId}'),
                            ),
                          ),
                        // Notes are searched locally too.
                        ..._noteHits(learner).map(
                          (note) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.sticky_note_2_rounded),
                              title: Text(note.title,
                                  style: AppTypography.label),
                              subtitle: Text(note.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption),
                              onTap: () => context.push('/notes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'lesson' => Icons.menu_book_rounded,
        'concept' => Icons.lightbulb_rounded,
        'reference' => Icons.library_books_rounded,
        _ => Icons.topic_rounded,
      };

  List<dynamic> _noteHits(dynamic learner) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return const [];
    return learner.notes
        .where((n) =>
            n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
  }
}
