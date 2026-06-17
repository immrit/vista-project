import '../../security/logging_utility.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/publicPostModel.dart';
import '../../services/vista_story_template_generator.dart';
import '../../services/vista_story_image_preloader.dart';
import '../../services/smart_share_service.dart';
import '../../features/stories/core/story_enums.dart';
import '../../features/stories/domain/entities/story_editor_models.dart';
import '../../features/stories/domain/repositories/i_story_repository.dart';
import '../../features/stories/presentation/providers/story_providers.dart';
import '../../features/stories/presentation/screens/story_editor_screen.dart';
import '../../features/chat/widgets/modern_context_menu.dart';
import 'vista_story_template_widget.dart';
import 'vista_story_share_theme.dart';
import 'UserSelectionBottomSheet.dart';

/// ویجت bottom sheet برای اشتراک‌گذاری پست
class ShareBottomSheet extends ConsumerStatefulWidget {
  final PublicPostModel post;

  const ShareBottomSheet({super.key, required this.post});

  @override
  ConsumerState<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<ShareBottomSheet> {
  final VistaStoryTemplateGenerator _generator = VistaStoryTemplateGenerator();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _addToStoryButtonKey = GlobalKey();
  bool _isGenerating = false;
  VistaStoryShareTheme _selectedTheme = VistaStoryShareTheme.dark;
  Uint8List? _avatarBytes;
  Uint8List? _postImageBytes;
  Uint8List? _videoThumbnailBytes;

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
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.link,
                        label: 'کپی لینک',
                        onTap: _copyLink,
                      ),
                    ),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.share,
                        label: 'اشتراک‌گذاری...',
                        onTap: _shareVia,
                        customIcon: Image.asset(
                          'lib/utils/images/component/send.png',
                          width: 24,
                          height: 24,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildActionButton(
                        key: _addToStoryButtonKey,
                        icon: Icons.auto_stories_outlined,
                        label: 'افزودن به استوری',
                        onTap: _isGenerating ? () {} : _showStoryThemeMenu,
                        customIcon: Image.asset(
                          'lib/utils/images/share_icons/story.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAppIcon(
                        icon: _buildSocialIcon(),
                        label: 'استوری',
                        onTap: _shareToSocialStories,
                      ),
                    ),
                    Expanded(
                      child: _buildAppIcon(
                        icon: _buildWhatsAppIcon(),
                        label: 'پیام‌رسان',
                        onTap: _shareToWhatsApp,
                      ),
                    ),
                    Expanded(
                      child: _buildAppIcon(
                        icon: _buildGmailIcon(),
                        label: 'جیمیل',
                        onTap: _shareToGmail,
                      ),
                    ),
                    Expanded(
                      child: _buildAppIcon(
                        icon: _buildRubikaIcon(),
                        label: 'روبیکا',
                        onTap: _shareToRubika,
                      ),
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
              theme: _selectedTheme,
              avatarBytes: _avatarBytes,
              postImageBytes: _postImageBytes,
              videoThumbnailBytes: _videoThumbnailBytes,
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
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? customIcon,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: customIcon ?? Icon(icon, color: Colors.black, size: 24),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  void _showStoryThemeMenu() {
    final renderBox =
        _addToStoryButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final anchorRect =
        Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    ModernContextMenu.show(
      context: context,
      messageWidget: const SizedBox.shrink(),
      messageRect: anchorRect,
      isMyMessage: false,
      showReactions: false,
      showAnchorPreview: false,
      openAboveAnchor: true,
      items: [
        ModernContextMenuItem(
          icon: Icons.dark_mode_outlined,
          label: 'قالب تیره',
          onTap: () => _addToVistaStory(theme: VistaStoryShareTheme.dark),
        ),
        const ModernContextMenuItem.divider(),
        ModernContextMenuItem(
          icon: Icons.wb_sunny_outlined,
          label: 'قالب روشن',
          onTap: () => _addToVistaStory(theme: VistaStoryShareTheme.light),
        ),
        const ModernContextMenuItem.divider(),
        ModernContextMenuItem(
          icon: Icons.bolt_rounded,
          label: 'قالب ویستا',
          onTap: () => _addToVistaStory(theme: VistaStoryShareTheme.vista),
        ),
      ],
      onDismiss: () {},
    );
  }

  Future<File?> _prepareAndGenerateStory({
    required VistaStoryShareTheme theme,
  }) async {
    final preloaded =
        await VistaStoryImagePreloader.preloadForPost(widget.post);

    if (!mounted) return null;

    setState(() {
      _selectedTheme = theme;
      _avatarBytes = preloaded.avatarBytes;
      _postImageBytes = preloaded.postImageBytes;
      _videoThumbnailBytes = preloaded.videoThumbnailBytes;
    });

    if (_avatarBytes != null) {
      await precacheImage(MemoryImage(_avatarBytes!), context);
    }
    if (_postImageBytes != null) {
      await precacheImage(MemoryImage(_postImageBytes!), context);
    }
    if (_videoThumbnailBytes != null) {
      await precacheImage(MemoryImage(_videoThumbnailBytes!), context);
    }

    final author = StoryPostAuthor.fromPost(widget.post);
    if (_avatarBytes == null && author.avatarUrl.isNotEmpty) {
      await precacheImage(NetworkImage(author.avatarUrl), context);
    }

    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 200));

    return _generator.generateStoryTemplate(
      post: widget.post,
      repaintBoundaryKey: _repaintBoundaryKey,
      waitForRender: true,
    );
  }

  Widget _buildAppIcon({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: icon,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // App icons
  Widget _buildSocialIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'lib/utils/images/share_icons/Social.png',
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
            'lib/utils/images/share_icons/whatsapp.png',
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
            'lib/utils/images/share_icons/gmail.png',
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
            'lib/utils/images/share_icons/Rubika.png',
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

  /// تولید تصویر قالب و باز کردن ویرایشگر استوری ویستا
  Future<void> _addToVistaStory({
    required VistaStoryShareTheme theme,
  }) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uploadNotifier = ref.read(storyUploadProvider.notifier);

    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('در حال آماده‌سازی تصویر استوری...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      final storyFile = await _prepareAndGenerateStory(theme: theme);

      if (!mounted) return;

      if (storyFile == null) {
        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('خطا در تولید تصویر استوری. لطفاً دوباره امتحان کنید.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      navigator.pop();

      final result = await navigator.push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => StoryEditorScreen(
            mediaFile: storyFile,
            mediaType: StoryMediaType.image,
          ),
        ),
      );

      if (result == null) return;

      final params = StoryUploadParams(
        mediaFile: result['media'] as File,
        mediaType: StoryMediaType.image,
        caption: result['caption'] as String?,
        interactiveElements: result['elements'] as List<StoryElement>?,
        duration:
            (result['duration'] as StoryDuration?) ?? StoryDuration.hours24,
        privacyType: (result['privacy'] as StoryPrivacyType?) ??
            StoryPrivacyType.everyone,
      );

      uploadNotifier.uploadStory(params);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('در حال آپلود استوری...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      logInfo('Add to Vista story error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('خطا در افزودن به استوری. لطفاً دوباره امتحان کنید.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // App sharing methods
  Future<void> _shareToSocialStories() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('در حال تولید تصویر استوری...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );

      final storyFile = await _prepareAndGenerateStory(
        theme: VistaStoryShareTheme.dark,
      );

      if (!mounted) return;

      if (storyFile == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'خطا در تولید تصویر استوری. لطفاً دوباره امتحان کنید.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      navigator.pop();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('تصویر استوری آماده شد، در حال اشتراک‌گذاری...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await _shareToSocialDirectly(storyFile);
    } catch (e) {
      logInfo('Social sharing error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('خطا در اشتراک‌گذاری. لطفاً دوباره امتحان کنید.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// اشتراک‌گذاری مستقیم به ویستا
  Future<void> _shareToSocialDirectly(File imageFile) async {
    try {
      // تصویر ترکیبی را مستقیماً به ویستا ارسال می‌کنیم
      await _shareToSocialViaIntent(imageFile);
    } catch (e) {
      logInfo('Direct sharing failed: $e');
      // اگر روش مستقیم کار نکرد، از روش fallback استفاده می‌کنیم
      await _generator.shareToSocialStory(imageFile);
    }
  }

  /// اشتراک‌گذاری به ویستا از طریق Intent
  Future<void> _shareToSocialViaIntent(File imageFile) async {
    try {
      // ایجاد Intent برای اشتراک‌گذاری
      const platform = MethodChannel('com.vista.app/share');

      // ارسال تصویر ترکیبی به ویستا
      final result = await platform.invokeMethod('shareToSocial', {
        'imagePath': imageFile.path,
        'packageName': 'com.social.android',
      });

      if (mounted) {
        if (result == "Social opened successfully") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('در حال باز کردن برنامه مقصد...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('در حال تلاش برای باز کردن برنامه مقصد...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // اگر Intent کار نکرد، از روش قدیمی استفاده می‌کنیم
      logInfo('Intent failed: $e');

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

      await _generator.shareToSocialStory(imageFile);
    }
  }

  void _shareToWhatsApp() {
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
