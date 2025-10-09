import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class TelegramGalleryBottomSheet extends StatefulWidget {
  final Function(File) onImageSelected;
  final Function(List<File>)? onImagesSelected;

  const TelegramGalleryBottomSheet({
    super.key,
    required this.onImageSelected,
    this.onImagesSelected,
  });

  @override
  State<TelegramGalleryBottomSheet> createState() =>
      _TelegramGalleryBottomSheetState();
}

class _TelegramGalleryBottomSheetState extends State<TelegramGalleryBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  final Set<String> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadImages();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    try {
      debugPrint('🖼️ Starting to load images...');

      final result = await PhotoManager.requestPermissionExtend();
      debugPrint('📱 Permission result: ${result.isAuth}');

      if (!result.isAuth) {
        debugPrint('❌ Permission denied');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      debugPrint('📁 Found ${albums.length} albums');

      if (albums.isEmpty) {
        debugPrint('❌ No albums found');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final recent = albums.first;
      debugPrint('📂 Using album: ${recent.name}');

      final images = await recent.getAssetListPaged(page: 0, size: 200);
      debugPrint('🖼️ Loaded ${images.length} images');

      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
        });
        debugPrint('✅ Images set in state');
      }
    } catch (e) {
      debugPrint('❌ Error loading images: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeSheet() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectImage(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        // Close this sheet first, then invoke callback to open preview
        await _closeSheet();
        widget.onImageSelected(file);
      }
    } catch (e) {
      _showErrorDialog('خطا در انتخاب تصویر');
    }
  }

  void _toggleImageSelection(String assetId) {
    setState(() {
      if (_selectedImages.contains(assetId)) {
        _selectedImages.remove(assetId);
      } else {
        _selectedImages.add(assetId);
      }
    });
  }

  Future<void> _sendSelectedImages() async {
    if (_selectedImages.isEmpty) return;

    final List<File> files = [];
    for (final assetId in _selectedImages) {
      final asset = _images.firstWhere((img) => img.id == assetId);
      try {
        final file = await asset.file;
        if (file != null) files.add(file);
      } catch (e) {
        debugPrint('Error preparing image: $e');
      }
    }
    if (files.isNotEmpty) {
      // Close this sheet before opening preview in callback
      await _closeSheet();
      if (widget.onImagesSelected != null) {
        widget.onImagesSelected!(files);
      } else {
        // Fallback to sequential single-callback
        for (final f in files) {
          widget.onImageSelected(f);
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطا'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4A4A4A)
                            : const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            'انتخاب تصویر',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedImages.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_selectedImages.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: _closeSheet,
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF6B6B6B),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gallery grid
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.primaryColor,
                              ),
                            )
                          : _images.isEmpty
                              ? _buildEmptyState(theme, isDark)
                              : _buildTelegramStyleGallery(theme, isDark),
                    ),

                    // Bottom action bar
                    if (_selectedImages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3A3A3A)
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          theme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _sendSelectedImages,
                                  icon:
                                      const Icon(Icons.send_rounded, size: 20),
                                  label: Text(
                                    'ارسال ${_selectedImages.length} تصویر',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3A3A3A)
                                      : const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.clear();
                                  });
                                },
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: isDark
                                      ? const Color(0xFF9E9E9E)
                                      : const Color(0xFF6B6B6B),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ تصویری یافت نشد',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramStyleGallery(ThemeData theme, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final asset = _images[index];
        final isSelected = _selectedImages.contains(asset.id);

        return GestureDetector(
          onTap: () => _selectImage(asset),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _toggleImageSelection(asset.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: theme.primaryColor,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(300, 300),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              child: Icon(
                                Icons.broken_image,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                                size: 24,
                              ),
                            );
                          },
                        );
                      }

                      return Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.image,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                // Video indicator (if it's a video)
                if (asset.type == AssetType.video)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
