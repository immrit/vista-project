import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/story_enums.dart';
import '../../domain/entities/story_editor_models.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../providers/story_providers.dart';
import 'story_editor_screen.dart';
import 'story_privacy_settings_screen.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// صفحه ایجاد استوری - مشابه ویستا
class StoryCreationScreen extends ConsumerStatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  ConsumerState<StoryCreationScreen> createState() =>
      _StoryCreationScreenState();
}

class _StoryCreationScreenState extends ConsumerState<StoryCreationScreen>
    with WidgetsBindingObserver {
  // دوربین
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRearCamera = true;
  bool _isFlashOn = false;
  bool _isRecording = false;

  // گالری
  final DraggableScrollableController _galleryController =
      DraggableScrollableController();
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _mediaItems = [];
  bool _isLoadingMedia = true;
  
  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 30;
  bool _hasMoreMedia = true;
  bool _isLoadingMoreMedia = false;

  // UI state
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadAlbums();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final camera = _isRearCamera
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            )
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        setState(() => _isLoadingMedia = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          videoOption: const FilterOption(
            durationConstraint: DurationConstraint(max: Duration(seconds: 60)),
          ),
        ),
      );

      if (albums.isNotEmpty && mounted) {
        setState(() {
          _albums = albums;
          _selectedAlbum = albums.first;
        });
        _loadMediaFromAlbum(albums.first);
      }
    } catch (e) {
      debugPrint('Albums load error: $e');
      setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _loadMediaFromAlbum(AssetPathEntity album, {bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoadingMedia = true;
        _currentPage = 0;
        _mediaItems.clear();
        _hasMoreMedia = true;
      });
    } else {
      if (!_hasMoreMedia || _isLoadingMoreMedia) return;
      setState(() => _isLoadingMoreMedia = true);
    }

    try {
      final media = await album.getAssetListPaged(page: _currentPage, size: _itemsPerPage);
      if (mounted) {
        setState(() {
          if (refresh) {
            _mediaItems = media;
          } else {
            _mediaItems.addAll(media);
          }
          _hasMoreMedia = media.length == _itemsPerPage;
          if (refresh) {
            _isLoadingMedia = false;
          } else {
            _isLoadingMoreMedia = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Media load error: $e');
      if (mounted) {
        setState(() {
          _isLoadingMedia = false;
          _isLoadingMoreMedia = false;
        });
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isRearCamera = !_isRearCamera;
    });

    final oldController = _cameraController;

    final camera = _isRearCamera
        ? _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          )
        : _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          );

    final newController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await newController.initialize();
      if (mounted) {
        setState(() {
          _cameraController = newController;
        });
        await oldController?.dispose();
      } else {
        await newController.dispose();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;

    HapticFeedback.lightImpact();
    setState(() => _isFlashOn = !_isFlashOn);

    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      await _processMedia(File(image.path), StoryMediaType.image);
    } catch (e) {
      debugPrint('Take photo error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || _isRecording) return;

    HapticFeedback.heavyImpact();

    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_isRecording) return;

    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final video = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);
      await _processMedia(File(video.path), StoryMediaType.video);
    } catch (e) {
      debugPrint('Stop recording error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _selectMedia(AssetEntity asset) async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final file = await asset.file;
      if (file != null) {
        final type = asset.type == AssetType.video
            ? StoryMediaType.video
            : StoryMediaType.image;
        await _processMedia(file, type);
      }
    } catch (e) {
      debugPrint('Select media error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processMedia(File file, StoryMediaType type) async {
    // رفتن به ویرایشگر (برای عکس و ویدیو)
    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => StoryEditorScreen(
          mediaFile: file,
          mediaType: type,
        ),
      ),
    );

    if (result != null && mounted) {
      // اگر استوری با موفقیت ساخته شد، شروع آپلود
      await _uploadStory(
        result['media'] as File,
        type,
        caption: result['caption'] as String?,
        interactiveElements:
            result['elements'] as List<StoryElement>?, // Send elements
        duration:
            (result['duration'] as StoryDuration?) ?? StoryDuration.hours24,
        privacy: (result['privacy'] as StoryPrivacyType?) ??
            StoryPrivacyType.everyone,
      );
    }
  }

  Future<void> _uploadStory(
    File media,
    StoryMediaType type, {
    String? caption,
    List<StoryElement>? interactiveElements,
    StoryDuration duration = StoryDuration.hours24,
    StoryPrivacyType privacy = StoryPrivacyType.everyone,
  }) async {
    // بستن صفحه ساخت استوری و برگشتن به خانه
    // آپلود در پس‌زمینه انجام می‌شود (توسط StoryBar نمایش داده می‌شود)
    if (mounted) {
      Navigator.pop(context);
    }

    // شروع آپلود از طریق Provider
    final params = StoryUploadParams(
      mediaFile: media,
      mediaType: type,
      caption: caption,
      interactiveElements: interactiveElements,
      duration: duration,
      privacyType: privacy,
    );

    ref.read(storyUploadProvider.notifier).uploadStory(params);
  }

  void _showAlbumPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlbumPickerSheet(
        albums: _albums,
        selectedAlbum: _selectedAlbum,
        onAlbumSelected: (album) {
          setState(() => _selectedAlbum = album);
          _loadMediaFromAlbum(album, refresh: true);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // باز کردن گالری با سوایپ به بالا
          if ((details.primaryVelocity ?? 0) < -500) {
            _galleryController.animateTo(
              0.6,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // دوربین
            _buildCameraPreview(),

            // هدر
            _buildHeader(),

            // دکمه شاتر
            _buildShutterButton(),

            // گالری (کشیدنی از پایین)
            _buildDraggableGallery(bottomPadding),

            // لودینگ
            if (_isProcessing) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ClipRRect(
      child: CameraPreview(_cameraController!),
    );
  }

  // ... (Header and Shutter buttons remain similar, skipping to keep context if needed, but tool replaces contiguous block)
  // To avoid replacing too much, I will target the build method specifically if possible, but _buildDraggableGallery is further down.
  // I'll stick to replacing the build method first.

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          // بستن
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          const Spacer(),

          // فلش
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.yellow : Colors.white,
              size: 26,
            ),
          ),

          // تغییر دوربین
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.flip_camera_ios,
                color: Colors.white, size: 26),
          ),

          // تنظیمات
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoryPrivacySettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _takePhoto,
          onLongPressStart: (_) => _startVideoRecording(),
          onLongPressEnd: (_) => _stopVideoRecording(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isRecording ? 90 : 72,
            height: _isRecording ? 90 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isRecording ? Colors.red : Colors.white,
                width: 4,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableGallery(double bottomPadding) {
    return DraggableScrollableSheet(
      controller: _galleryController,
      initialChildSize: 0.05, // ارتفاع خیلی کم، فقط هندل
      minChildSize: 0.05,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.05, 0.5, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              GestureDetector(
                onTap: () {
                  if (_galleryController.size < 0.2) {
                    _galleryController.animateTo(
                      0.5,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    _galleryController.animateTo(
                      0.05,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16), // فضای لمس بیشتر
                  color: Colors.transparent, // برای دریافت تاچ
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              // انتخاب فولدر
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _showAlbumPicker,
                  child: Row(
                    children: [
                      Text(
                        _selectedAlbum?.name ?? 'گالری',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // گرید عکس‌ها
              Expanded(
                child: _buildMediaGrid(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid(ScrollController scrollController) {
    if (_isLoadingMedia) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_mediaItems.isEmpty) {
      return Center(
        child: Text(
          'هیچ رسانه‌ای یافت نشد',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 && !_isLoadingMoreMedia && _hasMoreMedia) {
          if (_selectedAlbum != null) {
            _currentPage++;
            _loadMediaFromAlbum(_selectedAlbum!, refresh: false);
          }
        }
        return false;
      },
      child: GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _mediaItems.length + (_isLoadingMoreMedia ? 4 : 0),
        itemBuilder: (context, index) {
          if (index >= _mediaItems.length) {
            return Container(
              color: Colors.grey[900],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            );
          }
          final asset = _mediaItems[index];
          return _MediaThumbnail(
            asset: asset,
            onTap: () => _selectMedia(asset),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Colors.white,
          size: 50,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _MediaThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _MediaThumbnail({
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              }
              return Container(color: Colors.grey[800]);
            },
          ),

          // مدت ویدیو
          if (asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(Duration(seconds: asset.duration)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _AlbumPickerSheet extends StatelessWidget {
  final List<AssetPathEntity> albums;
  final AssetPathEntity? selectedAlbum;
  final Function(AssetPathEntity) onAlbumSelected;

  const _AlbumPickerSheet({
    required this.albums,
    required this.selectedAlbum,
    required this.onAlbumSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // عنوان
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'انتخاب فولدر',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // لیست فولدرها
          Expanded(
            child: ListView.builder(
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final isSelected = album.id == selectedAlbum?.id;

                return FutureBuilder<int>(
                  future: album.assetCountAsync,
                  builder: (context, countSnapshot) {
                    return ListTile(
                      leading: FutureBuilder<List<AssetEntity>>(
                        future: album.getAssetListRange(start: 0, end: 1),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            return FutureBuilder<Uint8List?>(
                              future:
                                  snapshot.data!.first.thumbnailDataWithSize(
                                const ThumbnailSize(80, 80),
                              ),
                              builder: (context, thumbSnapshot) {
                                if (thumbSnapshot.hasData) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      thumbSnapshot.data!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }
                                return Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[800],
                                );
                              },
                            );
                          }
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.folder,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      title: Text(
                        album.name,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${countSnapshot.data ?? 0} آیتم',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () => onAlbumSelected(album),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
