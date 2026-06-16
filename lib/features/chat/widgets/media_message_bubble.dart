// lib/features/chat/widgets/media_message_bubble.dart
// Cleaned MediaMessageBubble implementation — syntactically correct and compatible
// with callers in `improved_animated_message_bubble.dart`.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;

import 'full_screen_image_viewer.dart';
import '../theme/chat_theme.dart';
import '../utils/chat_image_dimensions.dart';
import '../utils/chat_media_bubble_layout.dart';
import '../../../model/message_model.dart';
import '../../../services/network_status_service.dart';
import '../../../provider/settings_providers.dart';
import '../services/chat_transfer_manager.dart';
import 'modern_message_status.dart';
import '../performance/chat_performance_profile.dart';
import '../utils/chat_text_direction.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/modern_emoji_text.dart';

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
  final ChatEffectsLevel effectsLevel;
  final bool allowHeavyEffects;
  final bool isSecretMode;
  final List<GalleryItem>? conversationGalleryItems;
  final int? initialGalleryIndex;

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
    this.effectsLevel = ChatEffectsLevel.high,
    this.allowHeavyEffects = true,
    this.isSecretMode = false,
    this.conversationGalleryItems,
    this.initialGalleryIndex,
  });

  @override
  ConsumerState<MediaMessageBubble> createState() => _MediaMessageBubbleState();
}

class _MediaMessageBubbleState extends ConsumerState<MediaMessageBubble> {
  bool _isFileCached = false;
  bool _isManuallyDownloading = false;
  File? _cachedFile;
  File? _offlineFile;
  ChatTransferTask? _transferTask;
  final ChatTransferManager _transferManager = ChatTransferManager();
  StreamSubscription<ChatTransferTask?>? _transferSub;
  SizeInt? _resolvedDimensions;

  // ✅ تابع دقیق برای تشخیص لینک اینترنتی (جلوگیری از خطای PathNotFound)
  bool get _isNetworkUrl {
    final url = widget.mediaUrl.trim().toLowerCase();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String? get _preferredLocalPath {
    final direct = widget.message?.localFilePath;
    if (direct != null && direct.isNotEmpty) return direct;
    final image = widget.message?.localImagePath;
    if (image != null && image.isNotEmpty) return image;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
    _bindTransferTask();
    _resolveImageDimensions();
  }

  @override
  void didUpdateWidget(covariant MediaMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.message?.localFilePath != widget.message?.localFilePath ||
        oldWidget.message?.localImagePath != widget.message?.localImagePath) {
      _resolveImageDimensions();
    }
  }

  Future<void> _resolveImageDimensions() async {
    final dimensions = await ChatImageDimensions.resolve(
      cacheKey: _dimensionCacheKey,
      knownWidth: widget.width,
      knownHeight: widget.height,
      localPath: _preferredLocalPath ??
          (_cachedFile?.path ?? _offlineFile?.path) ??
          (!_isNetworkUrl ? widget.mediaUrl : null),
      networkUrl: _isNetworkUrl ? widget.mediaUrl : null,
    );
    if (!mounted) return;
    if (_resolvedDimensions == dimensions) return;
    setState(() => _resolvedDimensions = dimensions);
  }

  String get _dimensionCacheKey =>
      widget.message?.id ?? widget.mediaUrl.hashCode.toString();

  String get _transferMessageId =>
      widget.message?.id ?? widget.mediaUrl.hashCode.toString();

  String get _mediaFileName {
    final uri = Uri.tryParse(widget.mediaUrl);
    final segment =
        uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    final parsedName = segment.isEmpty ? '' : segment;
    final ext = widget.mediaType == MediaType.video ? '.mp4' : '.jpg';
    final withExt =
        parsedName.isEmpty ? 'media_$_transferMessageId$ext' : parsedName;
    if (p.extension(withExt).isNotEmpty) return withExt;
    return '$withExt$ext';
  }

  Future<void> _bindTransferTask() async {
    if (widget.isSecretMode) return;
    final preferredLocalPath = _preferredLocalPath;
    if (preferredLocalPath != null && preferredLocalPath.isNotEmpty) {
      final localFile = File(preferredLocalPath);
      if (localFile.existsSync() && mounted) {
        setState(() {
          _offlineFile = localFile;
          _cachedFile = localFile;
          _isFileCached = true;
        });
      }
    }

    if (!_isNetworkUrl) return;
    _transferSub?.cancel();
    _transferSub =
        _transferManager.watchTask(_transferMessageId).listen((task) {
      if (!mounted) return;
      setState(() {
        _transferTask = task;
        _isManuallyDownloading = task?.status == TransferTaskStatus.downloading;
        final localPath = task?.localPath;
        if (localPath != null && localPath.isNotEmpty) {
          final file = File(localPath);
          _offlineFile = file.existsSync() ? file : null;
          if (_offlineFile != null) {
            _cachedFile = _offlineFile;
            _isFileCached = true;
            unawaited(_resolveImageDimensions());
          }
        } else if ((_offlineFile?.existsSync() ?? false) == false) {
          _offlineFile = null;
        }
      });
    });

    final existing =
        await _transferManager.getLocalFileIfExists(_transferMessageId);
    if (!mounted || existing == null) return;
    setState(() {
      _offlineFile = existing;
      _cachedFile = existing;
      _isFileCached = true;
    });
    unawaited(_resolveImageDimensions());
  }

  Future<void> _checkCacheStatus() async {
    final preferredLocalPath = _preferredLocalPath;
    if (preferredLocalPath != null && preferredLocalPath.isNotEmpty) {
      final localFile = File(preferredLocalPath);
      if (await localFile.exists()) {
        if (mounted) {
          setState(() {
            _isFileCached = true;
            _cachedFile = localFile;
            _offlineFile = localFile;
          });
          unawaited(_resolveImageDimensions());
        }
        return;
      }
    }

    // 1. اگر لینک اینترنتی نیست، یعنی فایل لوکال است
    if (!_isNetworkUrl) {
      final file = File(widget.mediaUrl);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isFileCached = true;
            _cachedFile = file;
          });
          unawaited(_resolveImageDimensions());
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
        unawaited(_resolveImageDimensions());
      }
    } catch (e) {
      // خطا در خواندن کش را نادیده بگیر
    }
  }

  bool _shouldAutoDownload(
      ConnectivityResult connType, Map<String, dynamic> settings) {
    if (widget.isSecretMode) return true;
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
      final providedGallery = widget.conversationGalleryItems;
      final hasProvidedGallery =
          providedGallery != null && providedGallery.isNotEmpty;
      final galleryItems = hasProvidedGallery
          ? providedGallery
          : <GalleryItem>[
              GalleryItem(
                imageUrl: widget.mediaUrl,
                cachedFile:
                    (_cachedFile?.existsSync() ?? false) ? _cachedFile : null,
                caption: widget.caption,
                heroTag: heroTag,
              ),
            ];

      int initialIndex = widget.initialGalleryIndex ?? -1;
      if (initialIndex < 0 || initialIndex >= galleryItems.length) {
        initialIndex =
            galleryItems.indexWhere((item) => item.heroTag == heroTag);
      }
      if (initialIndex < 0 || initialIndex >= galleryItems.length) {
        initialIndex = 0;
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => FullScreenImageViewer(
            galleryItems: galleryItems,
            initialIndex: initialIndex,
            isSecretMode: widget.isSecretMode,
            onForward: () {
              // اینجا می‌توانید متد فوروارد ویستا را صدا بزنید
              // مثلا: ForwardMessageSheet.show(...)
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeOutCubic,
            );
            return FadeTransition(opacity: curvedAnimation, child: child);
          },
        ),
      );
    } else {
      widget.onTap?.call();
    }
  }

  @override
  void dispose() {
    _transferSub?.cancel();
    super.dispose();
  }

  Future<void> _handleTransferAction() async {
    if (widget.isSecretMode) {
      _openFullScreenViewer(
        widget.message != null
            ? '${widget.message!.id}_${widget.mediaUrl}'
            : widget.mediaUrl,
      );
      return;
    }
    final status = _transferTask?.status;
    if (_offlineFile != null && _offlineFile!.existsSync()) {
      _openFullScreenViewer(
        widget.message != null
            ? '${widget.message!.id}_${widget.mediaUrl}'
            : widget.mediaUrl,
      );
      return;
    }
    if (status == TransferTaskStatus.downloading) {
      await _transferManager.pause(_transferTask!.taskId);
      return;
    }
    if (status == TransferTaskStatus.paused ||
        status == TransferTaskStatus.queued) {
      if (mounted) setState(() => _isManuallyDownloading = true);
      await _transferManager.resume(_transferTask!.taskId);
      return;
    }
    if (mounted) setState(() => _isManuallyDownloading = true);
    await _transferManager.startDownload(
      _transferMessageId,
      widget.mediaUrl,
      _mediaFileName,
    );
  }

  Future<void> _cancelTransfer() async {
    final taskId = _transferTask?.taskId;
    if (taskId == null) return;
    await _transferManager.cancel(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.value ?? {};
    final networkService = NetworkStatusService();

    final shouldDownload =
        _shouldAutoDownload(networkService.connectionType, settings);

    final screenSize = MediaQuery.sizeOf(context);
    final displaySize = ChatMediaBubbleLayout.computeBubblePhotoSize(
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      imageWidth: _resolvedDimensions?.width ?? widget.width,
      imageHeight: _resolvedDimensions?.height ?? widget.height,
      bubbleMaxWidth: screenSize.width * 0.75,
      useFullWidth: true,
    );
    final decodeWidth = _computeDecodeWidth(displaySize.width);

    // ✅ ساخت تگ یکتا برای جلوگیری از خطای Multiple Heroes
    final String uniqueHeroTag = widget.message != null
        ? '${widget.message!.id}_${widget.mediaUrl.hashCode}'
        : 'media_${widget.mediaUrl.hashCode}';

    // ✅ شرط مهم: بررسی اینکه آیا واقعاً متنی برای نمایش وجود دارد یا خیر
    final bool hasCaption =
        widget.caption != null && widget.caption!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!_isFileCached && !shouldDownload && !_isManuallyDownloading) {
          unawaited(_handleTransferAction());
        } else {
          _openFullScreenViewer(uniqueHeroTag);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Hero(
                tag: uniqueHeroTag,
                child: SizedBox(
                  width: displaySize.width,
                  height: displaySize.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildContent(
                      theme,
                      shouldDownload,
                      decodeWidth: decodeWidth,
                    ),
                  ),
                ),
              ),

                if (!_isFileCached &&
                    !shouldDownload &&
                    !_isManuallyDownloading &&
                    !widget.isSecretMode)
                  _buildDownloadButton(),

                if (_isManuallyDownloading && !_isFileCached)
                  _buildLoadingIndicator(),

                if (!widget.isSecretMode &&
                    _isNetworkUrl &&
                    _transferTask != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _buildTransferControls(),
                  ),
                if (!hasCaption)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _buildTimestampPill(theme),
                  ),
              ],
            ),
          if (hasCaption) _buildCaption(theme),
        ],
      ),
    );
  }

  int _computeDecodeWidth(double displayWidth) {
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.5);
    return (displayWidth * dpr).round().clamp(120, 1600);
  }

  Future<void> _captureProviderDimensions(ImageProvider provider) async {
    final dimensions = await ChatImageDimensions.fromImageProvider(provider);
    if (!mounted || dimensions == null) return;
    if (_resolvedDimensions?.width == dimensions.width &&
        _resolvedDimensions?.height == dimensions.height) {
      return;
    }
    ChatImageDimensions.remember(_dimensionCacheKey, dimensions);
    setState(() => _resolvedDimensions = dimensions);
  }

  Widget _buildContent(
    ChatTheme theme,
    bool shouldDownload, {
    required int decodeWidth,
  }) {
    if (_offlineFile != null && _offlineFile!.existsSync()) {
      return Image.file(
        _offlineFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: decodeWidth,
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
      );
    }

    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: decodeWidth,
        errorBuilder: (ctx, err, stack) =>
            _buildNetworkImage(theme, memCacheWidth: decodeWidth),
      );
    }

    if (!_isNetworkUrl) {
      return Image.file(
        File(widget.mediaUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: decodeWidth,
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
      );
    }

    final transferDownloading =
        _transferTask?.status == TransferTaskStatus.downloading;

    if (shouldDownload || _isManuallyDownloading || transferDownloading) {
      return _buildNetworkImage(
        theme,
        memCacheWidth: decodeWidth,
      );
    }

    return _buildBlurPreview(theme);
  }

  Widget _buildNetworkImage(
    ChatTheme theme, {
    int? memCacheWidth,
  }) {
    return CachedNetworkImage(
      imageUrl: widget.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) => _buildBlurPreview(theme),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      imageBuilder: (context, imageProvider) {
        unawaited(_captureProviderDimensions(imageProvider));
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  Widget _buildBlurPreview(ChatTheme theme) {
    final thumbSize = switch (widget.effectsLevel) {
      ChatEffectsLevel.low => 40,
      ChatEffectsLevel.medium => 64,
      ChatEffectsLevel.high => 96,
    };
    final useHeavyBlur = widget.allowHeavyEffects &&
        widget.effectsLevel == ChatEffectsLevel.high &&
        !widget.isUploading &&
        !_isManuallyDownloading;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl != null)
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl!,
            fit: BoxFit.cover,
            memCacheHeight: thumbSize,
            memCacheWidth: thumbSize,
            errorWidget: (_, __, ___) =>
                Container(color: theme.otherBubbleColor.withValues(alpha: 0.3)),
          )
        else
          Container(color: theme.otherBubbleColor.withValues(alpha: 0.3)),
        if (useHeavyBlur)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          )
        else
          Container(color: Colors.black.withValues(alpha: 0.18)),
      ],
    );
  }

  Widget _buildPlaceholder(ChatTheme theme) {
    return Container(
      color: theme.otherBubbleColor.withValues(alpha: 0.3),
      child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey)),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
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
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(12),
      child:
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _buildTransferControls() {
    final status = _transferTask?.status;
    if (status == null || status == TransferTaskStatus.completed) {
      return const SizedBox.shrink();
    }

    final progress = _transferTask?.progress ?? 0;
    final isDownloading = status == TransferTaskStatus.downloading;
    final isPaused = status == TransferTaskStatus.paused;
    final isQueued = status == TransferTaskStatus.queued;
    final isFailed = status == TransferTaskStatus.failed;

    final label = isDownloading
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : isPaused
            ? 'ادامه'
            : isQueued
                ? 'در صف'
                : isFailed
                    ? 'تلاش مجدد'
                    : 'دانلود';

    final icon = isDownloading
        ? Icons.pause_rounded
        : isPaused || isQueued
            ? Icons.play_arrow_rounded
            : Icons.refresh_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => unawaited(_handleTransferAction()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isDownloading || isPaused || isQueued) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => unawaited(_cancelTransfer()),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimestampPill(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
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
    final captionDirection = kChatLayoutTextDirection;

    return Container(
        padding: const EdgeInsets.fromLTRB(
            10, 8, 10, 24), // پدینگ پایین برای جای ساعت
        child: Directionality(
          textDirection: captionDirection,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ModernEmojiText(
                widget.caption!,
                useModernEmoji: EmojiRenderPolicy.useModernEmojiRenderer(),
                textDirection: captionDirection,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: widget.isMe
                      ? theme.myBubbleTextColor
                      : theme.otherBubbleTextColor,
                  fontSize: 15,
                  fontFamily: 'Vazir',
                ),
              ),
              PositionedDirectional(
                bottom: -20,
                end: 0,
                child: Row(
                  children: [
                    if (widget.isMe) ...[
                      _buildStatusIcon(widget.isMe
                          ? theme.myBubbleTextColor.withValues(alpha: 0.6)
                          : theme.otherBubbleTextColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      _formatTime(widget.time),
                      style: TextStyle(
                        color: widget.isMe
                            ? theme.myBubbleTextColor.withValues(alpha: 0.6)
                            : theme.otherBubbleTextColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildStatusIcon(Color color) {
    if (widget.message != null && widget.message!.isMe) {
      return ModernMessageStatus(
        status: widget.message!.resolvedDeliveryStatus,
        size: 14,
        customColor: color,
      );
    }
    return Icon(Icons.access_time, size: 12, color: color);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
