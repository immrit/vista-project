import '../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/publicPostModel.dart';
import '../view/screen/PublicPosts/VistaStoryTemplateScreen.dart';
import '../view/widgets/share_bottom_sheet.dart';

class SmartShareService {
  static final SmartShareService _instance = SmartShareService._internal();
  factory SmartShareService() => _instance;
  SmartShareService._internal();

  /// اشتراک‌گذاری هوشمند پست
  /// شامل لینک وب و اپ
  Future<void> sharePost(PublicPostModel post, {BuildContext? context}) async {
    try {
      final String webUrl = 'https://cafevista.ir/post/${post.id}';

      String shareText = '  Vista پست جدید ${post.username} در ';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      logInfo('Error sharing post: $e');
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
      final String webUrl = 'https://cafevista.ir/profile/$username';

      String shareText = '👤 پروفایل $username در Vista\n\n';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      logInfo('Error sharing profile: $e');
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
      final String webUrl = 'https://cafevista.ir/feed';

      String shareText = '📱 فید Vista\n\n';
      shareText += '🌐 مشاهده در Vista: $webUrl';

      await Share.share(shareText);
    } catch (e) {
      logInfo('Error sharing feed: $e');
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
      logInfo('Error opening URL: $e');
    }
  }

  /// اشتراک‌گذاری با انتخاب نوع لینک
  Future<void> shareWithLinkChoice(PublicPostModel post,
      {BuildContext? context}) async {
    try {
      final String webUrl = 'https://cafevista.ir/post/${post.id}';

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
      logInfo('Error sharing with choice: $e');
    }
  }

  /// نمایش دیالوگ انتخاب نوع اشتراک‌گذاری (متنی یا تصویری)
  Future<void> showShareOptions(
      PublicPostModel post, BuildContext context) async {
    // استفاده از bottom sheet جدید
    showShareBottomSheet(context, post);
  }

  /// باز کردن صفحه قالب استوری Vista (برای استفاده در جاهای دیگر)
  void openVistaStoryTemplate(BuildContext context, PublicPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VistaStoryTemplateScreen(post: post),
      ),
    );
  }
}
