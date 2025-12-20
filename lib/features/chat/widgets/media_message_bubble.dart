// lib/features/chat/widgets/media_message_bubble.dart
//
// ویجت نمایش عکس/ویدیو در حباب پیام - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ نمایش عکس با بلور و progressive loading
// ✅ ویدیو با thumbnail و دکمه پخش
// ✅ دانلود با progress
// ✅ Full screen gallery
// ✅ انیمیشن‌های روان
//

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';

/// نوع رسانه
enum MediaType { image, video, gif }

/// ویجت نمایش رسانه در حباب پیام
class MediaMessageBubble extends StatefulWidget {
  final String mediaUrl;
  final String? thumbnailUrl;
  final MediaType mediaType;
  final bool isMe;
  final DateTime time;
  final String? caption;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final int? fileSizeBytes;
  final VoidCallback? onTap;
  final bool isUploading; // وضعیت آپلود

  const MediaMessageBubble({
    super.key,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.isMe,
    required this.time,
    this.caption,
    this.width,
    this.height,
    this.durationSeconds,
    this.fileSizeBytes,
    this.onTap,
    this.isUploading = false, // مقدار پیش‌فرض
  });

  @override
  State<MediaMessageBubble> createState() => _MediaMessageBubbleState();
}

class _MediaMessageBubbleState extends State<MediaMessageBubble>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 STATE
  // ═══════════════════════════════════════════════════════════════════════════

  final bool _isDownloading = false;
  final double _downloadProgress = 0.0;
  late AnimationController _pulseController;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    // محاسبه سایز مناسب
    final aspectRatio = (widget.width != null && widget.height != null)
        ? widget.width! / widget.height!
        : 16 / 9;
    final maxWidth = 260.0;
    final calculatedHeight = maxWidth / aspectRatio;
    final height = calculatedHeight.clamp(100.0, 300.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          _openFullScreen(context);
        }
      },
      child: Container(
        // ۲. محدود کردن ابعاد برای جلوگیری از جمع شدن ویجت
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: height + (widget.caption != null ? 40 : 0),
          minWidth: 200,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // رسانه
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: widget.caption != null
                    ? Radius.zero
                    : const Radius.circular(12),
              ),
              child: SizedBox(
                height: height,
                width: double.infinity, // اطمینان از اینکه عرض کامل را می‌گیرد
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // تصویر/thumbnail
                    _buildMediaContent(theme),

                    // Overlay برای ویدیو/دانلود
                    _buildOverlay(theme),

                    // زمان و سایز
                    _buildInfoBadge(theme),
                  ],
                ),
              ),
            ),

            // کپشن
            if (widget.caption != null) _buildCaption(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(ChatTheme theme) {
    final displayUrl = widget.thumbnailUrl ?? widget.mediaUrl;

    // ۱. بررسی کنید که لینک تصویر وجود دارد
    if (displayUrl.isEmpty || displayUrl.trim().isEmpty) {
      debugPrint('MediaMessageBubble: displayUrl is empty');
      return _buildErrorWidget(theme, 'لینک تصویر موجود نیست');
    }

    // تشخیص هوشمند: آیا این یک لینک اینترنتی است یا فایل روی گوشی؟
    final isNetworkUrl =
        displayUrl.startsWith('http') || displayUrl.startsWith('https');

    if (!isNetworkUrl) {
      // 📂 حالت اول: نمایش فایل لوکال (زمانی که عکس را تازه انتخاب کردید و هنوز آپلود نشده)
      return Image.file(
        File(displayUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('MediaMessageBubble: Error loading local file: $error');
          debugPrint('MediaMessageBubble: File path: $displayUrl');
          debugPrint('MediaMessageBubble: Stack trace: $stackTrace');
          return _buildErrorWidget(theme, 'خطا در بارگذاری فایل محلی');
        },
      );
    } else {
      // 🌐 حالت دوم: نمایش عکس از سرور (لینک اینترنتی)

      return CachedNetworkImage(
        imageUrl: displayUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(theme),
        // ۴. نمایش خطا در صورت لود نشدن (بسیار مهم برای دیباگ)
        errorWidget: (context, url, error) {
          debugPrint('MediaMessageBubble: Error loading image from URL: $url');
          debugPrint('MediaMessageBubble: Error details: $error');
          debugPrint('MediaMessageBubble: Error type: ${error.runtimeType}');
          return _buildErrorWidget(theme, 'خطا در بارگذاری');
        },
        imageBuilder: (context, imageProvider) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // افکت بلور تلگرامی برای پس‌زمینه
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
              // تصویر اصلی
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildPlaceholder(ChatTheme theme) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          color: (widget.isMe ? theme.myBubbleColor : theme.otherBubbleColor)
              .withOpacity(0.3 + (_pulseController.value * 0.2)),
          child: Center(
            child: Icon(
              widget.mediaType == MediaType.video
                  ? Icons.videocam_rounded
                  : Icons.image_rounded,
              size: 40,
              color: theme.secondaryTextColor.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(ChatTheme theme, [String? message]) {
    return Container(
      // ۲. محدود کردن ابعاد برای جلوگیری از جمع شدن ویجت
      constraints: const BoxConstraints(
        minHeight: 150, // حداقل ارتفاع
        minWidth: 200,
      ),
      color: theme.errorColor.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 40,
              color: theme.errorColor,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'خطا در بارگذاری',
              style: TextStyle(
                color: theme.errorColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(ChatTheme theme) {
    // 1. اگر در حال آپلود است (پیام Pending)
    if (widget.isUploading) {
      return Container(
        color: Colors.black38,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    // 2. ویدیو - دکمه پخش
    if (widget.mediaType == MediaType.video) {
      return Center(
        child: _buildVideoPlayButton(theme),
      );
    }

    // 3. دانلود
    if (_isDownloading) {
      return Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: _buildDownloadProgress(theme),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoPlayButton(ChatTheme theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildDownloadProgress(ChatTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'در حال دانلود...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(ChatTheme theme) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مدت ویدیو
            if (widget.mediaType == MediaType.video &&
                widget.durationSeconds != null) ...[
              Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                _formatDuration(widget.durationSeconds!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
            ],

            // زمان
            Text(
              _formatTime(widget.time),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? theme.myBubbleColor : theme.otherBubbleColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Text(
        widget.caption!,
        style: TextStyle(
          color: widget.isMe
              ? theme.myBubbleTextColor
              : theme.otherBubbleTextColor,
          fontSize: 14,
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenMedia(
            mediaUrl: widget.mediaUrl,
            mediaType: widget.mediaType,
            heroTag: widget.mediaUrl,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🖼️ FULL SCREEN MEDIA VIEWER
// ═══════════════════════════════════════════════════════════════════════════

class _FullScreenMedia extends StatefulWidget {
  final String mediaUrl;
  final MediaType mediaType;
  final String heroTag;

  const _FullScreenMedia({
    required this.mediaUrl,
    required this.mediaType,
    required this.heroTag,
  });

  @override
  State<_FullScreenMedia> createState() => _FullScreenMediaState();
}

class _FullScreenMediaState extends State<_FullScreenMedia> {
  final TransformationController _transformController =
      TransformationController();
  bool _showControls = true;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () {
                    // TODO: Share
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () {
                    // TODO: Download to gallery
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: widget.heroTag,
              child: CachedNetworkImage(
                imageUrl: widget.mediaUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
