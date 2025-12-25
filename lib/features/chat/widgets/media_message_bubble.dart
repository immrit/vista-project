// lib/features/chat/widgets/media_message_bubble.dart
// Cleaned MediaMessageBubble implementation — syntactically correct and compatible
// with callers in `improved_animated_message_bubble.dart`.

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'full_screen_image_viewer.dart';
import '../../../services/telegram_read_receipt_service.dart';
import '../theme/chat_theme.dart';
import '../../../model/message_model.dart';
import '../../../services/network_status_service.dart';
import '../../../provider/settings_providers.dart';
import 'telegram_message_status.dart';

enum MediaType { image, video, gif }

class MediaMessageBubble extends ConsumerStatefulWidget {
  final MessageModel? message;
  final String mediaUrl;
  final String? thumbnailUrl;
  final MediaType mediaType;
  final bool isMe;
  final DateTime time;
  final String? caption;
  final int? width;
  final int? height;
  final VoidCallback? onTap;
  final bool isUploading;
  final int? videoDuration;

  const MediaMessageBubble({
    super.key,
    this.message,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.isMe,
    required this.time,
    this.caption,
    this.width,
    this.height,
    this.onTap,
    this.isUploading = false,
    this.videoDuration,
  });

  @override
  ConsumerState<MediaMessageBubble> createState() => _MediaMessageBubbleState();
}

class _MediaMessageBubbleState extends ConsumerState<MediaMessageBubble> {
  bool _isFileCached = false;
  bool _isManuallyDownloading = false;
  File? _cachedFile;

  // ✅ تابع دقیق برای تشخیص لینک اینترنتی (جلوگیری از خطای PathNotFound)
  bool get _isNetworkUrl {
    final url = widget.mediaUrl.trim().toLowerCase();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  Future<void> _checkCacheStatus() async {
    // 1. اگر لینک اینترنتی نیست، یعنی فایل لوکال است
    if (!_isNetworkUrl) {
      final file = File(widget.mediaUrl);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isFileCached = true;
            _cachedFile = file;
          });
        }
      }
      return;
    }

    // 2. اگر لینک اینترنتی است، در کش بررسی کن
    try {
      final fileInfo =
          await DefaultCacheManager().getFileFromCache(widget.mediaUrl);
      if (fileInfo != null && mounted) {
        setState(() {
          _isFileCached = true;
          _cachedFile = fileInfo.file;
        });
      }
    } catch (e) {
      // خطا در خواندن کش را نادیده بگیر
    }
  }

  bool _shouldAutoDownload(
      ConnectivityResult connType, Map<String, dynamic> settings) {
    if (_isFileCached || _isManuallyDownloading || widget.isUploading) {
      return true;
    }

    // اگر فایل لوکال است نیازی به دانلود نیست
    if (!_isNetworkUrl) return true;

    final isWifi = connType == ConnectivityResult.wifi;
    final isMobile = connType == ConnectivityResult.mobile;

    final bool dlMobileImage = settings['auto_download_mobile_image'] ?? true;
    final bool dlMobileVideo = settings['auto_download_mobile_video'] ?? false;
    final bool dlWifiImage = settings['auto_download_wifi_image'] ?? true;
    final bool dlWifiVideo = settings['auto_download_wifi_video'] ?? true;

    if (widget.mediaType == MediaType.image) {
      if (isWifi && dlWifiImage) return true;
      if (isMobile && dlMobileImage) return true;
    } else if (widget.mediaType == MediaType.video) {
      if (isWifi && dlWifiVideo) return true;
      if (isMobile && dlMobileVideo) return true;
    }

    return false;
  }

  void _openFullScreenViewer(String heroTag) {
    if (widget.mediaType == MediaType.image) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FullScreenImageViewer(
            galleryItems: [
              GalleryItem(
                  imageUrl: widget.mediaUrl,
                  cachedFile: _cachedFile,
                  caption: widget.caption,
                  heroTag: heroTag),
            ],
            initialIndex: 0,
            onForward: () {
              // اینجا می‌توانید متد فوروارد ویستا را صدا بزنید
              // مثلا: ForwardMessageSheet.show(...)
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.value ?? {};
    final networkService = NetworkStatusService();

    final shouldDownload =
        _shouldAutoDownload(networkService.connectionType, settings);

    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    final double aspectRatio = (widget.width != null && widget.height != null)
        ? widget.width! / widget.height!
        : 1.0;

    // ✅ ساخت تگ یکتا برای جلوگیری از خطای Multiple Heroes
    final String uniqueHeroTag = widget.message != null
        ? '${widget.message!.id}_${widget.mediaUrl}'
        : widget.mediaUrl;

    // ✅ شرط مهم: بررسی اینکه آیا واقعاً متنی برای نمایش وجود دارد یا خیر
    final bool hasCaption =
        widget.caption != null && widget.caption!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!_isFileCached && !shouldDownload && !_isManuallyDownloading) {
          setState(() {
            _isManuallyDownloading = true;
          });
        } else {
          _openFullScreenViewer(uniqueHeroTag);
        }
      },
      child: Container(
        constraints:
            BoxConstraints(maxWidth: maxWidth, minWidth: 100, maxHeight: 450),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // مهم برای جلوگیری از کش آمدن
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: uniqueHeroTag,
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildContent(theme, shouldDownload),
                    ),
                  ),
                ),

                if (!_isFileCached &&
                    !shouldDownload &&
                    !_isManuallyDownloading)
                  _buildDownloadButton(),

                if (_isManuallyDownloading && !_isFileCached)
                  _buildLoadingIndicator(),

                // اگر کپشن نداریم، ساعت را روی عکس نشان بده
                if (!hasCaption)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _buildTimestampPill(theme),
                  ),
              ],
            ),
            // فقط اگر کپشن واقعی داشتیم نمایش بده
            if (hasCaption) _buildCaption(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ChatTheme theme, bool shouldDownload) {
    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            _buildNetworkImage(theme), // Fallback
      );
    }

    if (!_isNetworkUrl) {
      return Image.file(
        File(widget.mediaUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
      );
    }

    if (shouldDownload || _isManuallyDownloading) {
      return _buildNetworkImage(theme);
    }

    return _buildBlurPreview(theme);
  }

  Widget _buildNetworkImage(ChatTheme theme) {
    return CachedNetworkImage(
      imageUrl: widget.mediaUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildBlurPreview(theme),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      imageBuilder: (context, imageProvider) {
        if (!_isFileCached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _checkCacheStatus();
          });
        }
        return Image(image: imageProvider, fit: BoxFit.cover);
      },
    );
  }

  Widget _buildBlurPreview(ChatTheme theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl != null)
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl!,
            fit: BoxFit.cover,
            memCacheHeight: 50,
            memCacheWidth: 50,
            errorWidget: (_, __, ___) =>
                Container(color: theme.otherBubbleColor.withOpacity(0.3)),
          )
        else
          Container(color: theme.otherBubbleColor.withOpacity(0.3)),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ChatTheme theme) {
    return Container(
      color: theme.otherBubbleColor.withOpacity(0.3),
      child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey)),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.arrow_downward, color: Colors.white, size: 28),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(12),
      child:
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _buildTimestampPill(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isMe) ...[
            _buildStatusIcon(Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            _formatTime(widget.time),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption(ChatTheme theme) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(10, 8, 10, 24), // پدینگ پایین برای جای ساعت
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            widget.caption!,
            style: TextStyle(
              color: widget.isMe
                  ? theme.myBubbleTextColor
                  : theme.otherBubbleTextColor,
              fontSize: 15,
              fontFamily: 'Vazir',
            ),
          ),
          Positioned(
            bottom: -20,
            right: 0,
            child: Row(
              children: [
                if (widget.isMe) ...[
                  _buildStatusIcon(widget.isMe
                      ? theme.myBubbleTextColor.withOpacity(0.6)
                      : theme.otherBubbleTextColor.withOpacity(0.6)),
                  const SizedBox(width: 3),
                ],
                Text(
                  _formatTime(widget.time),
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withOpacity(0.6)
                        : theme.otherBubbleTextColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color color) {
    if (widget.message != null) {
      return ValueListenableBuilder<MessageDeliveryStatus>(
        valueListenable: widget.message!.statusNotifier,
        builder: (context, status, _) {
          return TelegramMessageStatus(
              status: status, size: 14, customColor: color);
        },
      );
    }
    return Icon(Icons.access_time, size: 12, color: color);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
