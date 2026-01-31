// lib/utils/navigation_helper.dart
//
// Helper utility for navigating to user profiles and hashtag posts
// from anywhere in the app.
//

import 'package:flutter/material.dart';
import '../features/posts/screens/profileScreen.dart';
import '../features/posts/screens/hashtag_posts_screen.dart';
import '../utils/const.dart';

/// Navigation helper for mentions and hashtags
class NavigationHelper {
  NavigationHelper._();

  /// Navigate to user profile by username
  /// Looks up user ID from username and navigates to ProfileScreen
  static Future<void> navigateToUserProfile(
    BuildContext context,
    String username,
  ) async {
    // Remove @ if present
    final cleanUsername =
        username.startsWith('@') ? username.substring(1) : username;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch user by username
      final response = await supabase
          .from('profiles')
          .select('id, username')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کاربر @$cleanUsername یافت نشد')),
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
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در یافتن کاربر: $e')),
      );
    }
  }

  /// Navigate to hashtag posts screen
  static void navigateToHashtagPosts(BuildContext context, String hashtag) {
    // Remove # if present for consistency (screen handles it)
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
