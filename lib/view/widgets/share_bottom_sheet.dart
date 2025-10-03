import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../model/publicPostModel.dart';
import '../../services/vista_story_template_generator.dart';
import '../../services/smart_share_service.dart';
import 'vista_story_template_widget.dart';
import 'UserSelectionBottomSheet.dart';

/// ویجت bottom sheet برای اشتراک‌گذاری پست
class ShareBottomSheet extends StatefulWidget {
  final PublicPostModel post;

  const ShareBottomSheet({super.key, required this.post});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final VistaStoryTemplateGenerator _generator = VistaStoryTemplateGenerator();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'اشتراک‌گذاری پست',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // Send via Direct Message option
              _buildDirectMessageOption(),

              // Divider
              Container(
                height: 1,
                color: Colors.grey[800],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),

              // Action buttons row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.link,
                      label: 'کپی لینک',
                      onTap: _copyLink,
                    ),
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'اشتراک‌گذاری...',
                      onTap: _shareVia,
                      customIcon: Image.asset(
                        'lib/view/util/images/component/send.png',
                        width: 24,
                        height: 24,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                color: Colors.grey[800],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),

              // App icons row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAppIcon(
                      icon: _buildInstagramIcon(),
                      label: 'استوری اینستاگرام',
                      onTap: _shareToInstagramStories,
                    ),
                    _buildAppIcon(
                      icon: _buildWhatsAppIcon(),
                      label: 'واتساپ',
                      onTap: _shareToWhatsApp,
                    ),
                    _buildAppIcon(
                      icon: _buildTelegramIcon(),
                      label: 'تلگرام',
                      onTap: _shareToTelegram,
                    ),
                    _buildAppIcon(
                      icon: _buildGmailIcon(),
                      label: 'جیمیل',
                      onTap: _shareToGmail,
                    ),
                    _buildAppIcon(
                      icon: _buildRubikaIcon(),
                      label: 'روبیکا',
                      onTap: _shareToRubika,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),

        // Hidden widget for story image generation (Twitter/X approach)
        Positioned(
          left: -9999,
          top: -9999,
          child: SizedBox(
            width: 1080,
            height: 1920,
            child: VistaStoryTemplateWidget(
              post: widget.post,
              repaintBoundaryKey: _repaintBoundaryKey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectMessageOption() {
    return ListTile(
      leading: Icon(Icons.mail_outline, color: Colors.white, size: 24),
      title: Text(
        'ارسال از طریق پیام مستقیم',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        showUserSelectionBottomSheet(context, widget.post);
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? customIcon,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: customIcon ?? Icon(icon, color: Colors.black, size: 24),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildAppIcon({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // App icons
  Widget _buildInstagramIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'lib/view/util/images/share_icons/Instagram.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildWhatsAppIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white, // بک‌گراند سفید
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'lib/view/util/images/share_icons/whatsapp.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Color(0xFF0088CC), // رنگ آبی تلگرام
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'lib/view/util/images/share_icons/telegram.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildGmailIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white, // بک‌گراند سفید
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'lib/view/util/images/share_icons/gmail.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildRubikaIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Color(0xFF6C5CE7), // رنگ بنفش روبیکا
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'lib/view/util/images/share_icons/Rubika.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // Action methods
  void _copyLink() {
    Navigator.pop(context);
    final String webUrl = 'https://cafevista.ir/post/${widget.post.id}';
    Clipboard.setData(ClipboardData(text: webUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لینک پست کپی شد'), backgroundColor: Colors.green),
    );
  }

  void _shareVia() {
    Navigator.pop(context);
    SmartShareService().sharePost(widget.post, context: context);
  }

  // App sharing methods
  Future<void> _shareToInstagramStories() async {
    Navigator.pop(context);

    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      // Show initial loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('در حال تولید تصویر استوری...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Generate single combined story image (Twitter/X approach)
      final storyFile = await _generator.generateStoryTemplate(
        post: widget.post,
        repaintBoundaryKey: _repaintBoundaryKey,
      );

      if (storyFile != null) {
        // Show success message for image generation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تصویر استوری آماده شد، در حال اشتراک‌گذاری به اینستاگرام...',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Share the single combined story image (Twitter/X approach)
        await _shareToInstagramDirectly(storyFile);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ خطا در تولید تصویر استوری. لطفا دوباره امتحان کنید.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Instagram sharing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ خطا در اشتراک‌گذاری به اینستاگرام: لطفا دوباره امتحان کنید',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'دوباره امتحان',
              textColor: Colors.white,
              onPressed: _shareToInstagramStories,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// اشتراک‌گذاری مستقیم به اینستاگرام
  Future<void> _shareToInstagramDirectly(File imageFile) async {
    try {
      // تصویر ترکیبی را مستقیماً به اینستاگرام ارسال می‌کنیم
      await _shareToInstagramViaIntent(imageFile);
    } catch (e) {
      print('Direct sharing failed: $e');
      // اگر روش مستقیم کار نکرد، از روش fallback استفاده می‌کنیم
      await _generator.shareToInstagramStory(imageFile);
    }
  }

  /// اشتراک‌گذاری به اینستاگرام از طریق Intent
  Future<void> _shareToInstagramViaIntent(File imageFile) async {
    try {
      // ایجاد Intent برای اشتراک‌گذاری
      const platform = MethodChannel('com.vista.app/share');

      // ارسال تصویر ترکیبی به اینستاگرام
      final result = await platform.invokeMethod('shareToInstagram', {
        'imagePath': imageFile.path,
        'packageName': 'com.instagram.android',
      });

      if (mounted) {
        if (result == "Instagram opened successfully") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('در حال باز کردن اینستاگرام...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('در حال تلاش برای باز کردن اینستاگرام...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // اگر Intent کار نکرد، از روش قدیمی استفاده می‌کنیم
      print('Intent failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('در حال تلاش با روش جایگزین...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Wait a moment before trying fallback
      await Future.delayed(Duration(seconds: 1));

      await _generator.shareToInstagramStory(imageFile);
    }
  }

  void _shareToWhatsApp() {
    Navigator.pop(context);
    SmartShareService().sharePost(widget.post, context: context);
  }

  void _shareToTelegram() {
    Navigator.pop(context);
    SmartShareService().sharePost(widget.post, context: context);
  }

  void _shareToGmail() {
    Navigator.pop(context);
    SmartShareService().sharePost(widget.post, context: context);
  }

  void _shareToRubika() {
    Navigator.pop(context);
    SmartShareService().sharePost(widget.post, context: context);
  }
}

/// نمایش bottom sheet اشتراک‌گذاری
void showShareBottomSheet(BuildContext context, PublicPostModel post) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ShareBottomSheet(post: post),
  );
}
