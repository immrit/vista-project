import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../../../model/ProfileModel.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../theme/chat_theme.dart';
import 'document_upload_sheet.dart';

enum ChatAttachmentType {
  gallery,
  camera,
  file,
}

class AttachmentSelection {
  final ChatAttachmentType type;
  final List<SelectedAttachmentFile> files;
  final String? caption;

  const AttachmentSelection({
    required this.type,
    required this.files,
    this.caption,
  });
}

class SelectedAttachmentFile {
  final File file;
  final String displayFileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioAlbum;

  const SelectedAttachmentFile({
    required this.file,
    required this.displayFileName,
    this.mimeType,
    this.sizeBytes,
    this.audioTitle,
    this.audioArtist,
    this.audioAlbum,
  });
}

class ChatAttachmentSheet extends StatefulWidget {
  final Function(AttachmentSelection) onSelected;
  final ProfileModel? currentUserProfile;

  const ChatAttachmentSheet({
    super.key,
    required this.onSelected,
    this.currentUserProfile,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(AttachmentSelection) onSelected,
    ProfileModel? currentUserProfile,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatAttachmentSheet(
        onSelected: onSelected,
        currentUserProfile: currentUserProfile,
      ),
    );
  }

  @override
  State<ChatAttachmentSheet> createState() => _ChatAttachmentSheetState();
}

class _ChatAttachmentSheetState extends State<ChatAttachmentSheet>
    with TickerProviderStateMixin {
  static const Color _galleryLightColor = Color(0xFF7C3AED);
  static const Color _galleryDarkColor = Color(0xFFC4B5FD);
  static const Color _cameraLightColor = Color(0xFF0EA5E9);
  static const Color _cameraDarkColor = Color(0xFF7DD3FC);
  static const Color _fileLightColor = Color(0xFFF97316);
  static const Color _fileDarkColor = Color(0xFFFDBA74);

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _galleryScrollController = ScrollController();

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _mediaList = [];
  final Set<AssetEntity> _selectedAssets = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 60;

  bool _showGallery = true;
  double _sheetHeight = 0.55;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideController.forward();
    _loadAlbums();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _captionController.dispose();
    _galleryScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );

      if (!mounted) return;
      if (albums.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _albums = albums;
        _currentAlbum = albums.first;
      });
      await _loadMedia(refresh: true);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMedia({bool refresh = false}) async {
    if (_currentAlbum == null) return;
    if (_isLoadingMore && !refresh) return;
    if (!_hasMore && !refresh) return;

    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _mediaList.clear();
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    if (mounted) setState(() {});

    try {
      final media = await _currentAlbum!.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _mediaList = media;
          _isLoading = false;
        } else {
          _mediaList.addAll(media);
          _isLoadingMore = false;
        }
        if (media.length < _pageSize) {
          _hasMore = false;
        } else {
          _currentPage++;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _toggleSelection(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else if (_selectedAssets.length < 10) {
        _selectedAssets.add(asset);
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'حداکثر ۱۰ تصویر می‌توانید انتخاب کنید',
        );
      }
    });
  }

  Future<void> _sendSelected() async {
    if (_selectedAssets.isEmpty) return;
    HapticFeedback.mediumImpact();

    final files = <SelectedAttachmentFile>[];
    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(
          SelectedAttachmentFile(
            file: file,
            displayFileName: p.basename(file.path),
          ),
        );
      }
    }
    if (files.isEmpty) return;

    widget.onSelected(
      AttachmentSelection(
        type: ChatAttachmentType.gallery,
        files: files,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
      ),
    );
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
    if (image == null) return;
    widget.onSelected(
      AttachmentSelection(
        type: ChatAttachmentType.camera,
        files: [
          SelectedAttachmentFile(
            file: File(image.path),
            displayFileName: p.basename(image.path),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final onSelected = widget.onSelected;
    final profile = widget.currentUserProfile;

    Navigator.pop(context);

    final result = await DocumentUploadSheet.show(
      context: rootContext,
      profile: profile,
    );
    if (result == null) return;
    onSelected(
      AttachmentSelection(
        type: ChatAttachmentType.file,
        files: [
          SelectedAttachmentFile(
            file: result.file,
            displayFileName: result.displayFileName,
            mimeType: result.mimeType,
            sizeBytes: result.sizeBytes,
            audioTitle: result.audioTitle,
            audioArtist: result.audioArtist,
            audioAlbum: result.audioAlbum,
          ),
        ],
        caption: result.caption.isEmpty ? null : result.caption,
      ),
    );
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              _buildHandle(theme),
              _buildOptionsRow(theme),
              Expanded(
                child: _showGallery
                    ? _buildGalleryGrid(theme)
                    : _buildExpandedOptions(theme),
              ),
              if (_selectedAssets.isNotEmpty) _buildSelectedPreview(theme),
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
      child: Padding(
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
    final galleryColor = theme.isDark ? _galleryDarkColor : _galleryLightColor;
    final cameraColor = theme.isDark ? _cameraDarkColor : _cameraLightColor;
    final fileColor = theme.isDark ? _fileDarkColor : _fileLightColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (_showGallery && _currentAlbum != null)
            _buildAlbumSelector(theme)
          else
            _OptionChip(
              icon: Icons.photo_library_rounded,
              label: 'گالری',
              color: galleryColor,
              isSelected: _showGallery,
              onTap: () => setState(() => _showGallery = true),
            ),
          const SizedBox(width: 8),
          _OptionChip(
            icon: Icons.camera_alt_rounded,
            label: 'دوربین',
            color: cameraColor,
            onTap: _pickFromCamera,
          ),
          const SizedBox(width: 8),
          _OptionChip(
            icon: Icons.insert_drive_file_rounded,
            label: 'فایل',
            color: fileColor,
            onTap: _pickFile,
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _showGallery = !_showGallery),
            icon: Icon(
              _showGallery
                  ? Icons.grid_view_rounded
                  : Icons.photo_library_rounded,
              color: theme.iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumSelector(ChatTheme theme) {
    return InkWell(
      onTap: () => _showAlbumSelectionSheet(context, theme),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentAlbum?.name ?? 'گالری',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: theme.secondaryTextColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAlbumSelectionSheet(BuildContext context, ChatTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: ListView.builder(
            itemCount: _albums.length,
            itemBuilder: (_, index) {
              final album = _albums[index];
              final selected = album == _currentAlbum;
              return ListTile(
                title: Text(
                  album.name,
                  style: TextStyle(
                    color: selected ? theme.sendButtonColor : theme.textColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentAlbum = album;
                  });
                  _loadMedia(refresh: true);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGalleryGrid(ChatTheme theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.sendButtonColor),
      );
    }
    if (_mediaList.isEmpty) {
      return Center(
        child: Text(
          'تصویری یافت نشد',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingMore &&
            _hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMedia();
        }
        return false;
      },
      child: GridView.builder(
        controller: _galleryScrollController,
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _mediaList.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == _mediaList.length) {
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.sendButtonColor,
                ),
              ),
            );
          }
          final asset = _mediaList[index];
          final selected = _selectedAssets.contains(asset);
          final selectionIndex = _selectedAssets.toList().indexOf(asset);
          return _GalleryItem(
            asset: asset,
            isSelected: selected,
            selectionIndex: selectionIndex,
            onTap: () => _toggleSelection(asset),
          );
        },
      ),
    );
  }

  Widget _buildExpandedOptions(ChatTheme theme) {
    final galleryColor = theme.isDark ? _galleryDarkColor : _galleryLightColor;
    final cameraColor = theme.isDark ? _cameraDarkColor : _cameraLightColor;
    final fileColor = theme.isDark ? _fileDarkColor : _fileLightColor;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBigOption(
            icon: Icons.photo_library_rounded,
            label: 'گالری',
            color: galleryColor,
            onTap: () => setState(() => _showGallery = true),
          ),
          _buildBigOption(
            icon: Icons.camera_alt_rounded,
            label: 'دوربین',
            color: cameraColor,
            onTap: _pickFromCamera,
          ),
          _buildBigOption(
            icon: Icons.insert_drive_file_rounded,
            label: 'فایل',
            color: fileColor,
            onTap: _pickFile,
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
            Text(label, style: TextStyle(color: theme.textColor, fontSize: 13)),
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
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 70,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedAssets.length,
                    itemBuilder: (_, index) {
                      final asset = _selectedAssets.elementAt(index);
                      return _SelectedThumbnail(
                        asset: asset,
                        onRemove: () => _toggleSelection(asset),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildSendButton(theme),
              ],
            ),
          ),
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
          color: theme.sendButtonColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
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
    required this.onTap,
    this.isSelected = false,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withOpacity(0.2) : theme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? color : theme.textColor,
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

  Future<Widget> _buildThumbnail(ChatTheme theme) async {
    final bytes =
        await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    if (bytes == null) {
      return Container(
        color: theme.dividerColor,
        child: Icon(Icons.image_rounded, color: theme.secondaryTextColor),
      );
    }
    return Image.memory(bytes, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FutureBuilder<Widget>(
              future: _buildThumbnail(theme),
              builder: (_, snapshot) =>
                  snapshot.data ?? const SizedBox.shrink(),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? theme.sendButtonColor : Colors.transparent,
                width: 3,
              ),
              color: isSelected ? Colors.black26 : Colors.transparent,
            ),
          ),
          if (isSelected)
            Positioned(
              top: 6,
              right: 6,
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
        ],
      ),
    );
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
    final bytes =
        await asset.thumbnailDataWithSize(const ThumbnailSize(120, 120));
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(bytes, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: FutureBuilder<Widget>(
                future: _buildThumbnail(),
                builder: (_, snap) => snap.data ?? const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
