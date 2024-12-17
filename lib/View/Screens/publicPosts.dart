import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Provider/publicPostProvider.dart';
import 'addPosts.dart';

class PublicPostsScreen extends ConsumerWidget {
  const PublicPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // از پرووایدر صحیح استفاده کنید: postsWithProfilesProvider
    final publicPostsAsync = ref.watch(postsWithProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Posts'),
      ),
      body: publicPostsAsync.when(
        data: (posts) {
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(post['avatar_url'] ?? ''),
                ),
                title: Text(post['username'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['content'] ?? ''),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        post['isLiked']
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post['isLiked'] ? Colors.red : null,
                      ),
                      onPressed: () {
                        ref
                            .read(likePostProvider.notifier)
                            .toggleLike(post['id']);
                      },
                    ),
                    Text('${post['likeCount']}'),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => CreatePostWidget()))),
    );
  }
}
