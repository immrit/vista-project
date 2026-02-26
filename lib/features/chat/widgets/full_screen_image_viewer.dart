import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../utils/user_friendly_error_utils.dart';

class GalleryItem {
  final String imageUrl;
  final File? cachedFile;
  final String? caption;
  final String heroTag;

  GalleryItem({
    required this.imageUrl,
    this.cachedFile,
    this.caption,
    required this.heroTag,
  });
}

class FullScreenImageViewer extends StatefulWidget {
  final List<GalleryItem> galleryItems;
  final int initialIndex;
  final VoidCallback? onForward;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const FullScreenImageViewer({
    super.key,
    required this.galleryItems,
    this.initialIndex = 0,
    this.onForward,
    this.onReply,
    this.onDelete,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  bool _isSaving = false;
  bool _isSharing = false;
  bool _captionExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  // Vertical drag to dismiss variables
  double _dragDistance = 0.0;
  double _dragScale = 1.0;
  bool _isDragging = false;
  bool _isZoomed = false;

  // PhotoView controllers for each page
  final Map<int, PhotoViewController> _photoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailScrollController = ScrollController();

    // تنظیم Status Bar به رنگ شفاف
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailStripToCurrent(animated: false);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    for (var controller in _photoControllers.values) {
      controller.dispose();
    }
    // بازگرداندن Status Bar به حالت عادی
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  PhotoViewController _getPhotoController(int index) {
    if (!_photoControllers.containsKey(index)) {
      final controller = PhotoViewController();
      controller.outputStateStream.listen((state) {
        setState(() {
          _isZoomed = state.scale != null && state.scale! > 1.0;
        });
      });
      _photoControllers[index] = controller;
    }
    return _photoControllers[index]!;
  }

  void _toggleControls() {
    if (_isDragging) return;
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  bool _isNetworkUrl(String url) {
    final trimmedUrl = url.trim().toLowerCase();
    return trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://');
  }

  bool get _shouldTruncateCaption {
    final caption = widget.galleryItems[_currentIndex].caption;
    return caption != null && caption.length > 100;
  }

  String get _displayedCaption {
    final caption = widget.galleryItems[_currentIndex].caption;
    if (caption == null) return '';
    if (!_shouldTruncateCaption || _captionExpanded) {
      return caption;
    }
    return '${caption.substring(0, 100)}...';
  }

  Future<String> _getFilePath(GalleryItem item) async {
    // اگر فایل کش شده داریم، از آن استفاده کن
    if (item.cachedFile != null && await item.cachedFile!.exists()) {
      return item.cachedFile!.path;
    }

    // اگر فایل لوکال است
    if (!_isNetworkUrl(item.imageUrl)) {
      return item.imageUrl;
    }

    // دانلود از اینترنت
    final tempDir = await getTemporaryDirectory();
    final fileName = item.imageUrl.split('/').last.split('?').first;
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);

    // اگر قبلاً دانلود شده، استفاده کن
    if (await file.exists()) {
      return filePath;
    }

    // دانلود جدید
    final dio = Dio();
    await dio.download(item.imageUrl, filePath);
    return filePath;
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final currentItem = widget.galleryItems[_currentIndex];
      final filePath = await _getFilePath(currentItem);

      // ذخیره در گالری با استفاده از gal
      await Gal.putImage(filePath);

      if (mounted) {
        _showSuccessSnackBar('تصویر در گالری ذخیره شد');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(UserFriendlyErrorUtils.getUserFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final currentItem = widget.galleryItems[_currentIndex];
      final filePath = await _getFilePath(currentItem);

      // اشتراک‌گذاری با استفاده از share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        text: currentItem.caption ?? 'تصویر از ویستا',
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(UserFriendlyErrorUtils.getUserFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _handleForward() {
    if (widget.onForward != null) {
      Navigator.pop(context);
      widget.onForward!();
    } else {
      _shareImage();
    }
  }

  void _handleReply() {
    if (widget.onReply != null) {
      Navigator.pop(context);
      widget.onReply!();
    }
  }

  void _handleDelete() {
    if (widget.onDelete != null) {
      // نمایش دیالوگ تأیید حذف
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حذف تصویر'),
          content: const Text('آیا از حذف این تصویر اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // بستن دیالوگ
                Navigator.pop(context); // بستن Viewer
                widget.onDelete!();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    setState(() {
      _isDragging = true;
      _showControls = false;
      _animationController.reverse();
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragDistance += details.delta.dy;
      // محاسبه opacity و scale بر اساس فاصله drag
      final progress = (_dragDistance.abs() / 300).clamp(0.0, 1.0);
      _dragScale = 1.0 - (progress * 0.3); // کوچک شدن تا 70%
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    const threshold = 150.0; // آستانه برای بستن

    if (_dragDistance.abs() > threshold) {
      // بستن با انیمیشن
      _closeWithAnimation();
    } else {
      // برگشت به حالت عادی
      setState(() {
        _dragDistance = 0.0;
        _dragScale = 1.0;
        _isDragging = false;
        _showControls = true;
        _animationController.forward();
      });
    }
  }

  void _closeWithAnimation() {
    // اضافه کردن انیمیشن بستن
    Navigator.pop(context);
  }

  void _handleThumbnailTap(int index) {
    if (index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollThumbnailStripToCurrent({bool animated = true}) {
    if (!_thumbnailScrollController.hasClients ||
        widget.galleryItems.length <= 1) {
      return;
    }

    const itemWidth = 64.0;
    const spacing = 6.0;
    final viewport = _thumbnailScrollController.position.viewportDimension;
    final target =
        (_currentIndex * (itemWidth + spacing)) - ((viewport - itemWidth) / 2);
    final clamped = target
        .clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    )
        .toDouble();

    if (animated) {
      _thumbnailScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _thumbnailScrollController.jumpTo(clamped);
    }
  }

  Widget _buildThumbnailStrip() {
    if (widget.galleryItems.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _thumbnailScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.galleryItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = widget.galleryItems[index];
          final isActive = index == _currentIndex;
          return GestureDetector(
            onTap: () => _handleThumbnailTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white24,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: _isNetworkUrl(item.imageUrl)
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    )
                  : Image.file(
                      item.cachedFile ?? File(item.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Stack(
          children: [
            // PageView for gallery navigation
            PageView.builder(
              controller: _pageController,
              itemCount: widget.galleryItems.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _captionExpanded = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollThumbnailStripToCurrent();
                });
              },
              itemBuilder: (context, index) {
                final item = widget.galleryItems[index];
                final photoController = _getPhotoController(index);

                return Transform.scale(
                  scale: _isDragging ? _dragScale : 1.0,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    child: Hero(
                      tag: item.heroTag,
                      child: PhotoView(
                        imageProvider: item.cachedFile != null
                            ? FileImage(item.cachedFile!) as ImageProvider
                            : _isNetworkUrl(item.imageUrl)
                                ? CachedNetworkImageProvider(item.imageUrl)
                                : FileImage(File(item.imageUrl)),
                        controller: photoController,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        initialScale: PhotoViewComputedScale.contained,
                        backgroundDecoration: const BoxDecoration(
                          color: Colors.black,
                        ),
                        loadingBuilder: (context, event) => Center(
                          child: CircularProgressIndicator(
                            value: event == null
                                ? null
                                : event.cumulativeBytesLoaded /
                                    (event.expectedTotalBytes ?? 1),
                            color: Colors.white,
                          ),
                        ),
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // App Bar بالا (با انیمیشن Fade) - Telegram Style
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: child,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        // Back Button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'بستن',
                        ),
                        const Spacer(),
                        // Forward Button
                        IconButton(
                          icon: const Icon(Icons.forward, color: Colors.white),
                          onPressed: _handleForward,
                          tooltip: 'فوروارد',
                        ),
                        // Menu Button
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onSelected: (String result) {
                            switch (result) {
                              case 'reply':
                                _handleReply();
                                break;
                              case 'save':
                                _saveToGallery();
                                break;
                              case 'share':
                                _shareImage();
                                break;
                              case 'delete':
                                _handleDelete();
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'reply',
                              child: Text('پاسخ'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'save',
                              child: Text('ذخیره در گالری'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'share',
                              child: Text('اشتراک‌گذاری'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(
                                'حذف',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Bar پایین (با انیمیشن Fade)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: child,
                  ),
                );
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Caption section
                        if (widget.galleryItems[_currentIndex].caption != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _captionExpanded = !_captionExpanded;
                                });
                              },
                              child: Text(
                                _displayedCaption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: _captionExpanded ? null : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        _buildThumbnailStrip(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
