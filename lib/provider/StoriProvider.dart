import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view/screen/Stories/story_system.dart';

final storyUsersProvider =
    StateNotifierProvider<StoryUsersNotifier, List<StoryUser>>((ref) {
  return StoryUsersNotifier();
});

class StoryUsersNotifier extends StateNotifier<List<StoryUser>> {
  StoryUsersNotifier() : super([]);

  void updateStoryViewed(String userId, String storyId) {
    state = [
      for (final user in state)
        if (user.id == userId)
          user.copyWith(
            stories: user.stories.map((story) {
              if (story.id == storyId) {
                return story.copyWith(isViewed: true);
              }
              return story;
            }).toList(),
          )
        else
          user,
    ];
  }
}
