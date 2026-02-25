import 'package:flutter/material.dart';

import '../features/posts/screens/hashtag_posts_screen.dart';
import '../features/posts/screens/profileScreen.dart';
import '../utils/const.dart';
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
      final response = await supabase
          .from('profiles')
          .select('id, username')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (response == null) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'کاربر @$cleanUsername پیدا نشد',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            userId: response['id'] as String,
            username: response['username'] as String,
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
