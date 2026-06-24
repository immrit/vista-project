import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../../../model/ProfileModel.dart';
import '../../../utils/directional_navigation.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../theme/chat_theme.dart';
import 'document_upload_sheet.dart';
import 'media_editor_result.dart';
import 'telegram_image_editor.dart';
import 'telegram_video_editor.dart';

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
  static const int _maxAlbumItems = 10;
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
  final List<AssetEntity> _selectedAssets = <AssetEntity>[];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 60;

  bool _showGallery = true;
  double _sheetHeight = 0.55;
  bool _isPreparingPreview = false;

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
      final existingIndex = _selectedAssets.indexWhere((a) => a.id == asset.id);
      if (existingIndex != -1) {
        _selectedAssets.removeAt(existingIndex);
      } else if (_selectedAssets.length < _maxAlbumItems) {
        _selectedAssets.add(asset);
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'حداکثر $_maxAlbumItems تصویر می‌توانید انتخاب کنید',
        );
      }
    });
  }

  Future<List<SelectedAttachmentFile>> _resolveSelectedAssetFiles(
    Iterable<AssetEntity> assets,
  ) async {
    final files = <SelectedAttachmentFile>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) {
        final displayName = await _resolveAssetDisplayFileName(asset, file);
        files.add(
          SelectedAttachmentFile(
            file: file,
            displayFileName: displayName,
          ),
        );
      }
    }
    return files;
  }

  Future<void> _onGalleryItemTap(AssetEntity asset) async {
    if (_selectedAssets.isNotEmpty) {
      _toggleSelection(asset);
      return;
    }
    await _openAssetPreviewFlow(assets: [asset], initialIndex: 0);
  }

  void _onGalleryItemLongPress(AssetEntity asset) {
    _toggleSelection(asset);
  }

  Future<void> _openSelectedAssetsPreview() async {
    if (_selectedAssets.isEmpty) return;
    final ordered = List<AssetEntity>.from(_selectedAssets, growable: false);
    await _openAssetPreviewFlow(assets: ordered, initialIndex: 0);
  }

  void _reorderSelectedAssets(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _selectedAssets.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= _selectedAssets.length) return;
    if (target == oldIndex) return;

    setState(() {
      final moved = _selectedAssets.removeAt(oldIndex);
      _selectedAssets.insert(target, moved);
    });
  }

  Future<void> _openAssetPreviewFlow({
    required List<AssetEntity> assets,
    required int initialIndex,
  }) async {
    if (assets.isEmpty || !mounted) return;
    if (assets.length > _maxAlbumItems) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'حداکثر $_maxAlbumItems تصویر در هر آلبوم مجاز است',
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isPreparingPreview = true);
    List<SelectedAttachmentFile> files;
    try {
      files = await _resolveSelectedAssetFiles(assets);
    } catch (_) {
      files = const [];
    }
    if (!mounted) return;
    setState(() => _isPreparingPreview = false);

    if (files.isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'فایل تصویری قابل استفاده پیدا نشد',
      );
      return;
    }

    AttachmentSelection? result;

    if (files.length == 1) {
      final isVideo = _isVideo(files.first.file.path);
      final mediaResult = await Navigator.of(context).push<MediaEditorResult>(
        MaterialPageRoute(
          builder: (_) => isVideo 
              ? TelegramVideoEditor(
                  file: files.first.file,
                  initialCaption: _captionController.text.trim(),
                )
              : TelegramImageEditor(
                  file: files.first.file,
                  initialCaption: _captionController.text.trim(),
                ),
        ),
      );

      if (mediaResult != null) {
        result = AttachmentSelection(
          type: ChatAttachmentType.gallery,
          files: [
            SelectedAttachmentFile(
              file: mediaResult.file,
              displayFileName: p.basename(mediaResult.file.path),
            )
          ],
          caption: mediaResult.caption,
        );
      }
    } else {
      result = await Navigator.of(context).push<AttachmentSelection>(
        MaterialPageRoute(
          builder: (_) => _ChatImagePreviewScreen(
            type: ChatAttachmentType.gallery,
            files: files,
            initialIndex: initialIndex.clamp(0, files.length - 1).toInt(),
            initialCaption: _captionController.text.trim(),
          ),
        ),
      );
    }

    if (result == null || !mounted) return;
    widget.onSelected(result);
    Navigator.pop(context);
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image == null) return;
    if (!mounted) return;

    AttachmentSelection? result;

    if (_isVideo(image.path)) {
      final mediaResult = await Navigator.of(context).push<MediaEditorResult>(
        MaterialPageRoute(
          builder: (_) => TelegramVideoEditor(
            file: File(image.path),
            initialCaption: '',
          ),
        ),
      );

      if (mediaResult != null) {
        result = AttachmentSelection(
          type: ChatAttachmentType.camera,
          files: [
            SelectedAttachmentFile(
              file: mediaResult.file,
              displayFileName: p.basename(mediaResult.file.path),
            )
          ],
          caption: mediaResult.caption,
        );
      }
    } else {
      final mediaResult = await Navigator.of(context).push<MediaEditorResult>(
        MaterialPageRoute(
          builder: (_) => TelegramImageEditor(
            file: File(image.path),
            initialCaption: '',
          ),
        ),
      );

      if (mediaResult != null) {
        result = AttachmentSelection(
          type: ChatAttachmentType.camera,
          files: [
            SelectedAttachmentFile(
              file: mediaResult.file,
              displayFileName: p.basename(mediaResult.file.path),
            )
          ],
          caption: mediaResult.caption,
        );
      }
    }
    if (result == null || !mounted) return;
    widget.onSelected(result);
    Navigator.pop(context);
  }

  Future<String> _resolveAssetDisplayFileName(
    AssetEntity asset,
    File file,
  ) async {
    final fallback = p.basename(file.path);
    String? title = asset.title?.trim();
    if (title == null || title.isEmpty) {
      try {
        title = (await asset.titleAsync).trim();
      } catch (_) {
        title = null;
      }
    }

    final normalized = title?.trim() ?? '';
    if (normalized.isEmpty) return fallback;
    if (p.extension(normalized).isNotEmpty) return normalized;

    final fallbackExt = p.extension(fallback);
    if (fallbackExt.isNotEmpty) {
      return '$normalized$fallbackExt';
    }
    return normalized;
  }

  bool _isVideo(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi');
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
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHandle(theme),
              _buildOptionsRow(theme),
              if (_isPreparingPreview)
                const LinearProgressIndicator(minHeight: 2),
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
            isSelectionMode: _selectedAssets.isNotEmpty,
            selectionIndex: selectionIndex,
            onTap: () => unawaited(_onGalleryItemTap(asset)),
            onLongPress: () => _onGalleryItemLongPress(asset),
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
                color: color.withValues(alpha: 0.15),
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
    final selectedCount = _selectedAssets.length;
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
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    onReorder: _reorderSelectedAssets,
                    itemCount: _selectedAssets.length,
                    itemBuilder: (_, index) {
                      final asset = _selectedAssets[index];
                      return Container(
                        key: ValueKey('selected_${asset.id}'),
                        width: 72,
                        alignment: Alignment.center,
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: _SelectedThumbnail(
                            asset: asset,
                            orderLabel: '${index + 1}',
                            onRemove: () => _toggleSelection(asset),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildOpenPreviewButton(theme, selectedCount),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 14, color: theme.secondaryTextColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'نگه‌داشتن طولانی روی عکس = انتخاب چندتایی، لمس عادی = پیش‌نمایش',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenPreviewButton(ChatTheme theme, int selectedCount) {
    return GestureDetector(
      onTap: _openSelectedAssetsPreview,
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
            Icon(directionalForwardIcon(context),
                color: Colors.white, size: 24),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Text(
                  '$selectedCount',
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
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : theme.inputBackgroundColor,
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
  final bool isSelectionMode;
  final int selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GalleryItem({
    required this.asset,
    required this.isSelected,
    required this.isSelectionMode,
    required this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
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
      onLongPress: onLongPress,
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
                color: isSelectionMode
                    ? (isSelected ? theme.sendButtonColor : Colors.white30)
                    : Colors.transparent,
                width: isSelectionMode ? 2.5 : 0,
              ),
              color: isSelected
                  ? Colors.black26
                  : (isSelectionMode ? Colors.black12 : Colors.transparent),
            ),
          ),
          if (isSelectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? theme.sendButtonColor : Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: isSelected
                      ? Text(
                          '${selectionIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          color: Colors.white,
                          size: 12,
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
  final String orderLabel;
  final VoidCallback onRemove;

  const _SelectedThumbnail({
    required this.asset,
    required this.orderLabel,
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
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                orderLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.drag_handle_rounded,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatImagePreviewScreen extends StatefulWidget {
  final ChatAttachmentType type;
  final List<SelectedAttachmentFile> files;
  final int initialIndex;
  final String? initialCaption;

  const _ChatImagePreviewScreen({
    required this.type,
    required this.files,
    this.initialIndex = 0,
    this.initialCaption,
  });

  @override
  State<_ChatImagePreviewScreen> createState() =>
      _ChatImagePreviewScreenState();
}

class _ChatImagePreviewScreenState extends State<_ChatImagePreviewScreen> {
  static const int _maxAlbumItems = 10;
  late final PageController _pageController;
  late final TextEditingController _captionController;
  late final List<SelectedAttachmentFile> _previewFiles;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _previewFiles = List<SelectedAttachmentFile>.from(widget.files);
    _currentIndex = _previewFiles.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _previewFiles.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
    _captionController =
        TextEditingController(text: widget.initialCaption ?? '');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _editCurrentMedia() async {
    if (_previewFiles.isEmpty) return;
    final currentFile = _previewFiles[_currentIndex].file;

    final ext = currentFile.path.toLowerCase();
    final isVideo = ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi');

    if (isVideo) {
      final videoResult = await Navigator.push<MediaEditorResult>(
        context,
        MaterialPageRoute(
          builder: (context) => TelegramVideoEditor(
            file: currentFile,
            initialCaption: _previewFiles[_currentIndex].displayFileName == p.basename(currentFile.path) 
                ? '' 
                : _previewFiles[_currentIndex].displayFileName, // Not ideal, but we keep it empty or use existing logic
          ),
        ),
      );

      if (videoResult != null && mounted) {
        setState(() {
          _previewFiles[_currentIndex] = SelectedAttachmentFile(
            file: videoResult.file,
            displayFileName: p.basename(videoResult.file.path),
          );
        });
      }
    } else {
      final imageResult = await Navigator.push<MediaEditorResult>(
        context,
        MaterialPageRoute(
          builder: (context) => TelegramImageEditor(
            file: currentFile,
            initialCaption: _previewFiles[_currentIndex].displayFileName == p.basename(currentFile.path) 
                ? '' 
                : _previewFiles[_currentIndex].displayFileName,
          ),
        ),
      );

      if (imageResult != null && mounted) {
        setState(() {
          _previewFiles[_currentIndex] = SelectedAttachmentFile(
            file: imageResult.file,
            displayFileName: p.basename(imageResult.file.path),
          );
        });
      }
    }
  }

  void _send() {
    if (_previewFiles.isEmpty) return;
    if (_previewFiles.length > _maxAlbumItems) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'حداکثر $_maxAlbumItems تصویر در هر آلبوم مجاز است',
      );
      return;
    }
    final caption = _captionController.text.trim();
    Navigator.of(context).pop(
      AttachmentSelection(
        type: widget.type,
        files: _previewFiles,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _previewFiles.length) return;
    HapticFeedback.selectionClick();

    if (_previewFiles.length == 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _previewFiles.removeAt(index);
      if (_currentIndex >= _previewFiles.length) {
        _currentIndex = _previewFiles.length - 1;
      } else if (index < _currentIndex) {
        _currentIndex -= 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _previewFiles.isEmpty) {
        return;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  void _reorderPreviewFiles(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _previewFiles.length) return;
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= _previewFiles.length) return;
    if (targetIndex == oldIndex) return;

    setState(() {
      final moved = _previewFiles.removeAt(oldIndex);
      _previewFiles.insert(targetIndex, moved);

      if (_currentIndex == oldIndex) {
        _currentIndex = targetIndex;
      } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
        _currentIndex -= 1;
      } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
        _currentIndex += 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _previewFiles.isEmpty) {
        return;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_previewFiles.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final theme = context.chatTheme;
    final isAlbum = _previewFiles.length > 1;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafeArea = mediaQuery.padding.bottom;
    final isKeyboardVisible = keyboardInset > 0;
    final showAlbumStrip = isAlbum && keyboardInset <= 0;
    final composerBottomPadding =
        isKeyboardVisible ? keyboardInset : bottomSafeArea;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          isAlbum ? 'پیش‌نمایش آلبوم' : 'پیش‌نمایش عکس',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: _editCurrentMedia,
            tooltip: 'ویرایش',
          ),
          if (isAlbum)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${_previewFiles.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _previewFiles.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (_, index) {
                final file = _previewFiles[index].file;
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white70,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Stack(
                children: [
                  if (!isKeyboardVisible)
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.52, 1.0],
                        ).createShader(rect),
                        child: BackdropFilter(
                          // Blur only when keyboard is hidden to keep keyboard transition smooth.
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.40),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.38),
                            ],
                            stops: const [0.0, 0.42, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      showAlbumStrip ? 12 : 18,
                      12,
                      10 + composerBottomPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showAlbumStrip)
                          SizedBox(
                            height: 70,
                            child: ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 4),
                              buildDefaultDragHandles: false,
                              onReorder: _reorderPreviewFiles,
                              itemCount: _previewFiles.length,
                              itemBuilder: (_, index) {
                                final isActive = index == _currentIndex;
                                final file = _previewFiles[index].file;
                                return Container(
                                  key: ValueKey(
                                      'preview_${_previewFiles[index].file.path}'),
                                  width: 64,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: ReorderableDelayedDragStartListener(
                                    index: index,
                                    child: GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(
                                          index,
                                          duration:
                                              const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isActive
                                                ? theme.sendButtonColor
                                                : Colors.white24,
                                            width: isActive ? 2 : 1,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              filterQuality: FilterQuality.low,
                                              cacheWidth: 220,
                                              cacheHeight: 220,
                                            ),
                                            if (isActive)
                                              Container(
                                                color: Colors.black26,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 4,
                                              left: 4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.drag_handle_rounded,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _removeAt(index),
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.62),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (showAlbumStrip) const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5F6169)
                                      .withValues(alpha: 0.68),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                  child: TextField(
                                    controller: _captionController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    cursorColor: Colors.white,
                                    maxLines: 3,
                                    minLines: 1,
                                    maxLength: 1024,
                                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                    textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: isAlbum
                                        ? 'نوشتن کپشن برای آلبوم...'
                                        : 'نوشتن کپشن...',
                                    hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.78),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.sendButtonColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: _send,
                                child: const Icon(Icons.send_rounded),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
