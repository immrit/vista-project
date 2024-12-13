import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

import '../../Model/PublicPostsModel.dart';
import '../../Provider/appwriteProvider.dart';
import '../../Provider/publicPostProvider.dart';

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
                      Text(post['full_name'] ?? ''),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ));
  }
}
