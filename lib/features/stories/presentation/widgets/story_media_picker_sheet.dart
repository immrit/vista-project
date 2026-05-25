// lib/features/stories/presentation/widgets/story_media_picker_sheet.dart
//
// Bottom Sheet انتخاب رسانه استوری - با الهام از ویستا
//
// ویژگی‌ها:
// ✅ گرید گالری با پیش‌نمایش
// ✅ دوربین و ویدیو
// ✅ انیمیشن‌های روان
// ✅ فقط یک رسانه انتخاب
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/story_enums.dart';

/// نتیجه انتخاب رسانه استوری
class StoryMediaSelection {
  final File file;
  final StoryMediaType type;

  const StoryMediaSelection({
    required this.file,
    required this.type,
  });
}

/// Bottom Sheet انتخاب رسانه استوری
class StoryMediaPickerSheet extends StatefulWidget {
  final Function(StoryMediaSelection) onSelected;

  const StoryMediaPickerSheet({
    super.key,
    required this.onSelected,
  });

  /// نمایش sheet
  static Future<void> show(
    BuildContext context, {
    required Function(StoryMediaSelection) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryMediaPickerSheet(onSelected: onSelected),
    );
  }

  @override
  State<StoryMediaPickerSheet> createState() => _StoryMediaPickerSheetState();
}

class _StoryMediaPickerSheetState extends State<StoryMediaPickerSheet>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _galleryScrollController = ScrollController();

  // State
  List<AssetEntity> _recentMedia = [];
  bool _isLoading = true;
  double _sheetHeight = 0.55;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRecentMedia();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  Future<void> _loadRecentMedia() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        setState(() => _isLoading = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // عکس و ویدیو
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          videoOption: const FilterOption(
            durationConstraint: DurationConstraint(max: Duration(seconds: 60)),
          ),
        ),
      );

      if (albums.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final recentAlbum = albums.first;
      final media = await recentAlbum.getAssetListRange(start: 0, end: 50);

      if (mounted) {
        setState(() {
          _recentMedia = media;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectMedia(AssetEntity asset) async {
    HapticFeedback.mediumImpact();

    final file = await asset.file;
    if (file != null) {
      final type = asset.type == AssetType.video
          ? StoryMediaType.video
          : StoryMediaType.image;

      widget.onSelected(StoryMediaSelection(
        file: file,
        type: type,
      ));

      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickFromCamera() async {
    Navigator.pop(context);

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (image != null) {
      widget.onSelected(StoryMediaSelection(
        file: File(image.path),
        type: StoryMediaType.image,
      ));
    }
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);

    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );

    if (video != null) {
      widget.onSelected(StoryMediaSelection(
        file: File(video.path),
        type: StoryMediaType.video,
      ));
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _galleryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _sheetHeight -= details.delta.dy / mediaQuery.size.height;
            _sheetHeight = _sheetHeight.clamp(0.4, 0.85);
          });
        },
        child: Container(
          height: mediaQuery.size.height * _sheetHeight,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              _buildHandle(isDark),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'انتخاب رسانه',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Options row
              _buildOptionsRow(isDark, theme),

              // Gallery
              Expanded(
                child: _buildGalleryGrid(isDark, theme),
              ),

              // Safe area
              SizedBox(height: mediaQuery.padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sheetHeight = _sheetHeight > 0.6 ? 0.55 : 0.85;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsRow(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // دوربین عکس
          _buildOptionChip(
            icon: Icons.camera_alt_rounded,
            label: 'عکس',
            color: Colors.blue,
            isDark: isDark,
            onTap: _pickFromCamera,
          ),

          const SizedBox(width: 12),

          // دوربین ویدیو
          _buildOptionChip(
            icon: Icons.videocam_rounded,
            label: 'ویدیو',
            color: Colors.red,
            isDark: isDark,
            onTap: _pickVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid(bool isDark, ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      );
    }

    if (_recentMedia.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ رسانه‌ای یافت نشد',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _galleryScrollController,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _recentMedia.length,
      itemBuilder: (context, index) {
        final asset = _recentMedia[index];
        return _GalleryItem(
          asset: asset,
          onTap: () => _selectMedia(asset),
        );
      },
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _GalleryItem({
    required this.asset,
    required this.onTap,
  });

  Future<Widget> _buildThumbnail() async {
    final thumbData = await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (thumbData != null) {
      return Image.memory(
        thumbData,
        fit: BoxFit.cover,
      );
    }
    return const SizedBox();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Widget>(
              future: _buildThumbnail(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                }
                return Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                );
              },
            ),
          ),

          // Video duration
          if (asset.type == AssetType.video)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(Duration(seconds: asset.duration)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tap effect
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
