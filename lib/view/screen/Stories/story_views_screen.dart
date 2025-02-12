import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../main.dart';

class StoryViewsScreen extends ConsumerWidget {
  final String storyId;

  const StoryViewsScreen({required this.storyId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازدیدها'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _fetchStoryViews(storyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطا: ${snapshot.error}'));
          }

          final views = snapshot.data as List<Map<String, dynamic>>;

          return ListView.builder(
            itemCount: views.length,
            itemBuilder: (context, index) {
              final view = views[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    view['profiles']['avatar_url'] ??
                        'assets/images/default-avatar.jpg',
                  ),
                ),
                title: Text(view['profiles']['username'] ?? 'کاربر ناشناس'),
                subtitle: Text(
                  timeago.format(DateTime.parse(view['viewed_at']),
                      locale: 'fa'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStoryViews(String storyId) async {
    final response = await supabase.from('story_views').select('''
          viewer_id,
          viewed_at,
          profiles:viewer_id(
            username,
            avatar_url
          )
        ''').eq('story_id', storyId).order('viewed_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
