import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/entities/story_user.dart';
import '../domain/entities/story.dart';

class StoryPreloader {
  /// Preloads a single story's media and waits for it to complete.
  /// Useful for showing a loading spinner on the avatar before opening the viewer.
  static Future<void> preloadStory(BuildContext context, Story story) async {
    try {
      if (story.media.isVideo) {
        await DefaultCacheManager().downloadFile(story.media.url);
      } else {
        await precacheImage(CachedNetworkImageProvider(story.media.url), context);
      }
    } catch (e) {
      debugPrint('Story preload error: $e');
    }
  }

  /// Precaches the next [count] stories in the background without awaiting.
  /// Iterates through the current user's remaining stories, then moves to next users.
  /// Limits video preloading to [maxVideos] to prevent hardware decoder limits and high data usage.
  static void preloadNextStories(
      BuildContext context, List<StoryUser> allUsers, int currentUserIndex, int currentStoryIndex,
      {int count = 10, int maxVideos = 2}) {
    int preloadedCount = 0;
    int preloadedVideosCount = 0;
    int uIndex = currentUserIndex;
    int sIndex = currentStoryIndex + 1; // Start from next story

    while (preloadedCount < count && uIndex < allUsers.length) {
      final user = allUsers[uIndex];
      
      while (sIndex < user.stories.length && preloadedCount < count) {
        final story = user.stories[sIndex];
        
        if (story.media.isVideo) {
          if (preloadedVideosCount < maxVideos) {
            _preloadInBackground(context, story);
            preloadedVideosCount++;
            preloadedCount++;
          }
        } else {
          _preloadInBackground(context, story);
          preloadedCount++;
        }
        
        sIndex++;
      }
      
      uIndex++;
      sIndex = 0;
    }
  }

  static Future<void> _preloadInBackground(BuildContext context, Story story) async {
    try {
      if (story.media.isVideo) {
        // Download file in background
        DefaultCacheManager().downloadFile(story.media.url);
      } else {
        // Precache image in background
        precacheImage(CachedNetworkImageProvider(story.media.url), context);
      }
    } catch (e) {
      // Ignore background precache errors
    }
  }
}
