// lib/features/chat/widgets/link_preview_bubble.dart
//
// ویجت پیش‌نمایش لینک در حباب پیام - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ استخراج metadata از لینک (عنوان، توضیحات، تصویر)
// ✅ نمایش favicon سایت
// ✅ کش کردن پیش‌نمایش‌ها
// ✅ باز کردن لینک در مرورگر
// ✅ انیمیشن‌های روان
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/chat_theme.dart';

/// مدل اطلاعات پیش‌نمایش لینک
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? favicon;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.favicon,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasTitle => title != null && title!.isNotEmpty;
  bool get hasDescription => description != null && description!.isNotEmpty;

  String get displayDomain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

/// ویجت پیش‌نمایش لینک در حباب پیام
class LinkPreviewBubble extends StatefulWidget {
  final String messageContent;
  final LinkPreviewData? previewData;
  final bool isMe;
  final DateTime time;
  final VoidCallback? onLinkTap;

  const LinkPreviewBubble({
    super.key,
    required this.messageContent,
    this.previewData,
    required this.isMe,
    required this.time,
    this.onLinkTap,
  });

  @override
  State<LinkPreviewBubble> createState() => _LinkPreviewBubbleState();
}

class _LinkPreviewBubbleState extends State<LinkPreviewBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    HapticFeedback.lightImpact();

    if (widget.onLinkTap != null) {
      widget.onLinkTap!();
      return;
    }

    final preview = widget.previewData;
    if (preview == null) return;

    try {
      final uri = Uri.parse(preview.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در باز کردن لینک')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final preview = widget.previewData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // متن پیام
        if (widget.messageContent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildMessageText(theme),
          ),

        // پیش‌نمایش لینک
        if (preview != null) _buildLinkPreview(theme, preview),
      ],
    );
  }

  Widget _buildMessageText(ChatTheme theme) {
    return SelectableText(
      widget.messageContent,
      style: TextStyle(
        color: widget.isMe ? theme.myBubbleTextColor : theme.otherBubbleTextColor,
        fontSize: 15,
        height: 1.35,
      ),
    );
  }

  Widget _buildLinkPreview(ChatTheme theme, LinkPreviewData preview) {
    return GestureDetector(
      onTap: _openLink,
      onTapDown: (_) {
        _hoverController.forward();
      },
      onTapUp: (_) {
        _hoverController.reverse();
      },
      onTapCancel: () {
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _hoverController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_hoverController.value * 0.02),
            child: child,
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.white.withOpacity(0.1)
                : theme.dividerColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isMe
                  ? Colors.white.withOpacity(0.15)
                  : theme.dividerColor,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // تصویر پیش‌نمایش
              if (preview.hasImage) _buildPreviewImage(theme, preview),

              // اطلاعات لینک
              _buildPreviewInfo(theme, preview),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage(ChatTheme theme, LinkPreviewData preview) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: preview.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: theme.dividerColor.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.image_rounded,
              color: theme.secondaryTextColor.withOpacity(0.3),
              size: 32,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPreviewInfo(ChatTheme theme, LinkPreviewData preview) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // نام سایت با favicon
          Row(
            children: [
              // Favicon
              if (preview.favicon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CachedNetworkImage(
                    imageUrl: preview.favicon!,
                    width: 16,
                    height: 16,
                    placeholder: (context, url) => Icon(
                      Icons.language_rounded,
                      size: 16,
                      color: theme.secondaryTextColor,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.language_rounded,
                      size: 16,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.language_rounded,
                    size: 16,
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withOpacity(0.6)
                        : theme.secondaryTextColor,
                  ),
                ),

              // نام سایت یا دامنه
              Expanded(
                child: Text(
                  preview.siteName ?? preview.displayDomain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withOpacity(0.6)
                        : theme.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ),

              // آیکون لینک خارجی
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: widget.isMe
                    ? theme.myBubbleTextColor.withOpacity(0.5)
                    : theme.secondaryTextColor.withOpacity(0.5),
              ),
            ],
          ),

          // عنوان
          if (preview.hasTitle) ...[
            const SizedBox(height: 6),
            Text(
              preview.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor
                    : theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],

          // توضیحات
          if (preview.hasDescription) ...[
            const SizedBox(height: 4),
            Text(
              preview.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (widget.isMe
                        ? theme.myBubbleTextColor
                        : theme.textColor)
                    .withOpacity(0.7),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔗 LINK DETECTOR UTILITY
// ═══════════════════════════════════════════════════════════════════════════

class LinkDetector {
  static final _urlRegex = RegExp(
    r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
    caseSensitive: false,
  );

  /// استخراج اولین لینک از متن
  static String? extractFirstUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    if (match != null) {
      var url = match.group(0);
      if (url != null && !url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }

  /// استخراج همه لینک‌ها از متن
  static List<String> extractAllUrls(String text) {
    return _urlRegex.allMatches(text).map((match) {
      var url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }).toList();
  }

  /// آیا متن شامل لینک هست؟
  static bool containsUrl(String text) {
    return _urlRegex.hasMatch(text);
  }
}

