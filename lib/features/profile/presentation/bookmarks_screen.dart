import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/learner.dart';
import '../../../shared/widgets/state_views.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerAsync = ref.watch(learnerStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: learnerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (learner) {
          if (learner.bookmarks.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarks yet',
              message:
                  'Tap the bookmark icon on any lesson to save it for later.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final bookmark in learner.bookmarks)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        _iconFor(bookmark.contentType),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        bookmark.title ?? bookmark.contentId,
                        style: AppTypography.label,
                      ),
                      subtitle: Text(
                        _subtitleFor(bookmark.contentType),
                        style: AppTypography.caption,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => ref
                            .read(learnerStateProvider.notifier)
                            .removeBookmark(
                                bookmark.contentType, bookmark.contentId),
                      ),
                      onTap: () => _open(context, bookmark),
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

  void _open(BuildContext context, BookmarkRecord bookmark) {
    switch (bookmark.contentType) {
      case 'topic':
        context.push('/learn/topic/${bookmark.contentId}');
      case 'question':
        context.push('/ai-tutor?questionId=${bookmark.contentId}');
      default:
        context.push('/learn/topic/${bookmark.contentId}');
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'lesson' => Icons.menu_book_rounded,
        'question' => Icons.quiz_rounded,
        'reference' => Icons.library_books_rounded,
        _ => Icons.bookmark_rounded,
      };

  String _subtitleFor(String type) => switch (type) {
        'lesson' => 'Lesson',
        'question' => 'Question',
        'reference' => 'Reference',
        _ => 'Saved item',
      };
}
