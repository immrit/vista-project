import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/publicPostModel.dart';
import '../view/screen/PublicPosts/VistaStoryTemplateScreen.dart';

class SmartShareService {
  static final SmartShareService _instance = SmartShareService._internal();
  factory SmartShareService() => _instance;
  SmartShareService._internal();

  /// اشتراک‌گذاری هوشمند پست
  /// شامل لینک وب و اپ
  Future<void> sharePost(PublicPostModel post, {BuildContext? context}) async {
    try {
      final String webUrl = 'https://coffevista.ir/post/${post.id}';

      String shareText = '  Vista پست جدید ${post.username} در ';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      print('Error sharing post: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')),
        );
      }
    }
  }

  /// اشتراک‌گذاری پروفایل
  Future<void> shareProfile(String username, {BuildContext? context}) async {
    try {
      final String webUrl = 'https://coffevista.ir/profile/$username';

      String shareText = '👤 پروفایل $username در Vista\n\n';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      print('Error sharing profile: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')),
        );
      }
    }
  }

  /// اشتراک‌گذاری فید
  Future<void> shareFeed({BuildContext? context}) async {
    try {
      final String webUrl = 'https://coffevista.ir/feed';

      String shareText = '📱 فید Vista\n\n';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      print('Error sharing feed: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')),
        );
      }
    }
  }

  /// باز کردن لینک در مرورگر
  Future<void> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Error opening URL: $e');
    }
  }

  /// اشتراک‌گذاری با انتخاب نوع لینک
  Future<void> shareWithLinkChoice(PublicPostModel post,
      {BuildContext? context}) async {
    try {
      final String webUrl = 'https://coffevista.ir/post/${post.id}';

      // نمایش دیالوگ انتخاب نوع لینک
      if (context != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اشتراک‌گذاری'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('اشتراک‌گذاری پست'),
                  subtitle: Text(webUrl),
                  onTap: () {
                    Navigator.pop(context);
                    sharePost(post, context: context);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لغو'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error sharing with choice: $e');
    }
  }

  /// نمایش دیالوگ انتخاب نوع اشتراک‌گذاری (متنی یا تصویری)
  Future<void> showShareOptions(
      PublicPostModel post, BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'انتخاب نوع اشتراک‌گذاری',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildShareOption(
                    context: context,
                    icon: Icons.text_fields,
                    title: 'اشتراک‌گذاری متنی',
                    subtitle: 'لینک و متن پست',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      sharePost(post, context: context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShareOption(
                    context: context,
                    icon: Icons.auto_stories,
                    title: 'قالب استوری Vista',
                    subtitle: 'قالب سفارشی برای استوری',
                    color: const Color(0xFF833AB4),
                    onTap: () {
                      Navigator.pop(context);
                      _openVistaStoryTemplate(context, post);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'لغو',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// باز کردن صفحه قالب استوری Vista
  void _openVistaStoryTemplate(BuildContext context, PublicPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VistaStoryTemplateScreen(post: post),
      ),
    );
  }
}
