import 'package:flutter/material.dart';

import '../features/profile/data/profile_repository.dart';
import '../features/posts/screens/hashtag_posts_screen.dart';
import '../features/posts/screens/profileScreen.dart';
import 'user_friendly_error_utils.dart';

class NavigationHelper {
  NavigationHelper._();

  static Future<void> navigateToUserProfile(
    BuildContext context,
    String username,
  ) async {
    final cleanUsername =
        username.startsWith('@') ? username.substring(1) : username;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response =
          await ProfileRepository().fetchProfileByUsername(cleanUsername);

      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            userId: response['id']?.toString() ??
                response['user_id']?.toString() ??
                '',
            username: response['username']?.toString() ?? cleanUsername,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        error,
      );
    }
  }

  static void navigateToHashtagPosts(BuildContext context, String hashtag) {
    final cleanHashtag =
        hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagPostsScreen(hashtag: cleanHashtag),
      ),
    );
  }
}
