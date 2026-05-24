import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../model/publicPostModel.dart';
import '../providers/saved_posts_provider.dart';
import 'PostDetailPage.dart';

class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent * 0.75;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(savedPostsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(savedPostsProvider.notifier).refresh();
    await ref.read(savedPostIdsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedPostsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('پست‌های ذخیره‌شده'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Builder(
          builder: (_) {
            if (state.isLoading && state.posts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.posts.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'خطا در دریافت داده‌ها\n${state.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            if (state.posts.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 52,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(height: 10),
                          const Text('هنوز پستی ذخیره نشده است'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final itemCount = state.posts.length + 1;
            return ListView.separated(
              controller: _scrollController,
              itemCount: itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == state.posts.length) {
                  if (state.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!state.hasMore) {
                    return const SizedBox(height: 12);
                  }
                  return const SizedBox.shrink();
                }

                final post = state.posts[index];
                return _SavedPostTile(post: post);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  final PublicPostModel post;

  const _SavedPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl?.isNotEmpty ?? false;
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsPage(postId: post.id)),
      ),
      leading: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.image_not_supported),
              ),
            )
          : const CircleAvatar(
              child: Icon(Icons.article_outlined),
            ),
      title: Text(
        post.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        post.content.isEmpty ? '(بدون متن)' : post.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_left_rounded),
    );
  }
}
