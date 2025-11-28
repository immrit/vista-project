// lib/features/chat/widgets/chat_attachment_sheet.dart
//
// Bottom Sheet انتخاب پیوست - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ گرید گالری با انتخاب چندتایی
// ✅ پیش‌نمایش انتخاب‌شده‌ها
// ✅ دوربین، فایل، موقعیت
// ✅ انیمیشن‌های روان
// ✅ کپشن برای عکس
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import '../theme/chat_theme.dart';

/// نوع پیوست
enum ChatAttachmentType {
  gallery,
  camera,
  video,
  file,
  location,
  contact,
}

/// نتیجه انتخاب
class AttachmentSelection {
  final ChatAttachmentType type;
  final List<File> files;
  final String? caption;

  const AttachmentSelection({
    required this.type,
    required this.files,
    this.caption,
  });
}

/// Bottom Sheet انتخاب پیوست
class ChatAttachmentSheet extends StatefulWidget {
  final Function(AttachmentSelection) onSelected;

  const ChatAttachmentSheet({
    super.key,
    required this.onSelected,
  });

  /// نمایش sheet
  static Future<void> show(
    BuildContext context, {
    required Function(AttachmentSelection) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatAttachmentSheet(onSelected: onSelected),
    );
  }

  @override
  State<ChatAttachmentSheet> createState() => _ChatAttachmentSheetState();
}

class _ChatAttachmentSheetState extends State<ChatAttachmentSheet>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _slideController;
  late AnimationController _optionsController;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _galleryScrollController = ScrollController();

  // State
  List<AssetEntity> _recentMedia = [];
  final Set<AssetEntity> _selectedAssets = {};
  bool _isLoading = true;
  bool _showGallery = true;
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

    _optionsController = AnimationController(
      duration: const Duration(milliseconds: 200),
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
    _optionsController.forward();
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
            durationConstraint: DurationConstraint(max: Duration(minutes: 5)),
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

  void _toggleSelection(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        if (_selectedAssets.length < 10) {
          _selectedAssets.add(asset);
        } else {
          _showMaxSelectionWarning();
        }
      }
    });
  }

  void _showMaxSelectionWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('حداکثر ۱۰ فایل می‌توانید انتخاب کنید'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendSelected() async {
    if (_selectedAssets.isEmpty) return;

    HapticFeedback.mediumImpact();

    final files = <File>[];
    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }

    if (files.isNotEmpty) {
      widget.onSelected(AttachmentSelection(
        type: ChatAttachmentType.gallery,
        files: files,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
      ));
    }

    if (mounted) Navigator.pop(context);
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
      widget.onSelected(AttachmentSelection(
        type: ChatAttachmentType.camera,
        files: [File(image.path)],
      ));
    }
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);

    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (video != null) {
      widget.onSelected(AttachmentSelection(
        type: ChatAttachmentType.video,
        files: [File(video.path)],
      ));
    }
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'zip', 'rar', 'mp3', 'wav', 'apk',
      ],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      if (files.isNotEmpty) {
        widget.onSelected(AttachmentSelection(
          type: ChatAttachmentType.file,
          files: files,
        ));
      }
    }
  }

  void _showLocation() {
    Navigator.pop(context);
    // TODO: Location picker
    widget.onSelected(const AttachmentSelection(
      type: ChatAttachmentType.location,
      files: [],
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _optionsController.dispose();
    _captionController.dispose();
    _galleryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          // درگ برای تغییر سایز
          setState(() {
            _sheetHeight -= details.delta.dy / mediaQuery.size.height;
            _sheetHeight = _sheetHeight.clamp(0.4, 0.85);
          });
        },
        child: Container(
          height: mediaQuery.size.height * _sheetHeight,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              _buildHandle(theme),

              // Options row
              _buildOptionsRow(theme),

              // Gallery or options
              Expanded(
                child: _showGallery
                    ? _buildGalleryGrid(theme)
                    : _buildExpandedOptions(theme),
              ),

              // Selected preview & send
              if (_selectedAssets.isNotEmpty) _buildSelectedPreview(theme),

              // Safe area
              SizedBox(height: mediaQuery.padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(ChatTheme theme) {
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
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsRow(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // گالری toggle
          _OptionChip(
            icon: Icons.photo_library_rounded,
            label: 'گالری',
            isSelected: _showGallery,
            color: Colors.purple,
            onTap: () => setState(() => _showGallery = true),
          ),

          const SizedBox(width: 8),

          // دوربین
          _OptionChip(
            icon: Icons.camera_alt_rounded,
            label: 'دوربین',
            color: Colors.blue,
            onTap: _pickFromCamera,
          ),

          const SizedBox(width: 8),

          // فایل
          _OptionChip(
            icon: Icons.insert_drive_file_rounded,
            label: 'فایل',
            color: Colors.orange,
            onTap: _pickFile,
          ),

          const Spacer(),

          // Toggle view
          IconButton(
            onPressed: () => setState(() => _showGallery = !_showGallery),
            icon: Icon(
              _showGallery ? Icons.grid_view_rounded : Icons.photo_library_rounded,
              color: theme.iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(ChatTheme theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.sendButtonColor),
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
              color: theme.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'عکسی یافت نشد',
              style: TextStyle(color: theme.secondaryTextColor),
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
        final isSelected = _selectedAssets.contains(asset);
        final selectionIndex = _selectedAssets.toList().indexOf(asset);

        return _GalleryItem(
          asset: asset,
          isSelected: isSelected,
          selectionIndex: selectionIndex,
          onTap: () => _toggleSelection(asset),
        );
      },
    );
  }

  Widget _buildExpandedOptions(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBigOption(
                icon: Icons.photo_library_rounded,
                label: 'گالری',
                color: Colors.purple,
                onTap: () => setState(() => _showGallery = true),
              ),
              _buildBigOption(
                icon: Icons.camera_alt_rounded,
                label: 'دوربین',
                color: Colors.blue,
                onTap: _pickFromCamera,
              ),
              _buildBigOption(
                icon: Icons.videocam_rounded,
                label: 'ویدیو',
                color: Colors.red,
                onTap: _pickVideo,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBigOption(
                icon: Icons.insert_drive_file_rounded,
                label: 'فایل',
                color: Colors.orange,
                onTap: _pickFile,
              ),
              _buildBigOption(
                icon: Icons.location_on_rounded,
                label: 'موقعیت',
                color: Colors.green,
                onTap: _showLocation,
              ),
              _buildBigOption(
                icon: Icons.music_note_rounded,
                label: 'موزیک',
                color: Colors.pink,
                onTap: () {
                  // TODO: Music picker
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = context.chatTheme;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPreview(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.inputBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview row
          SizedBox(
            height: 70,
            child: Row(
              children: [
                // Selected thumbnails
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _selectedAssets.elementAt(index);
                      return _SelectedThumbnail(
                        asset: asset,
                        onRemove: () => _toggleSelection(asset),
                      );
                    },
                  ),
                ),

                // Send button
                const SizedBox(width: 12),
                _buildSendButton(theme),
              ],
            ),
          ),

          // Caption input
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'افزودن توضیح...',
              hintStyle: TextStyle(color: theme.inputHintColor),
              filled: true,
              fillColor: theme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.sendButtonColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ChatTheme theme) {
    return GestureDetector(
      onTap: _sendSelected,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.sendButtonColor,
              theme.sendButtonColor.withBlue(
                (theme.sendButtonColor.blue + 30).clamp(0, 255),
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.sendButtonColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 24,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_selectedAssets.length}',
                  style: TextStyle(
                    color: theme.sendButtonColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : theme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : theme.textColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int selectionIndex;
  final VoidCallback onTap;

  const _GalleryItem({
    required this.asset,
    required this.isSelected,
    required this.selectionIndex,
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

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FutureBuilder<Widget>(
              future: _buildThumbnail(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                }
                return Container(
                  color: theme.dividerColor,
                  child: Icon(
                    Icons.image_rounded,
                    color: theme.secondaryTextColor,
                  ),
                );
              },
            ),
          ),

          // Video duration
          if (asset.type == AssetType.video)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Selection overlay
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? theme.sendButtonColor : Colors.transparent,
                width: 3,
              ),
              color: isSelected ? Colors.black26 : Colors.transparent,
            ),
          ),

          // Selection badge
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.sendButtonColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${selectionIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _SelectedThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onRemove;

  const _SelectedThumbnail({
    required this.asset,
    required this.onRemove,
  });

  Future<Widget> _buildThumbnail() async {
    final thumbData = await asset.thumbnailDataWithSize(
      const ThumbnailSize(120, 120),
    );
    if (thumbData != null) {
      return Image.memory(
        thumbData,
        fit: BoxFit.cover,
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: FutureBuilder<Widget>(
                future: _buildThumbnail(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  }
                  return Container(
                    color: theme.dividerColor,
                    child: Icon(
                      Icons.image_rounded,
                      color: theme.secondaryTextColor,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

