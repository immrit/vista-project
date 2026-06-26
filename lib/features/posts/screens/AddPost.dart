import '../../../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../model/UserModel.dart';

import '../../../provider/provider.dart';
import '../../../services/current_user_service.dart';
import 'package:Vista/widgets/YourVideoTrimmerPage.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import '../providers/post_upload_provider.dart';
import '../widgets/hashtag_autocomplete_field.dart';
import '../widgets/social_text_editing_controller.dart';
import '../widgets/audio_equalizer_bars.dart';
import '../widgets/music_trim_sheet.dart';
import '../../profile/data/profile_repository.dart';
import 'package:Vista/core/theme/app_theme.dart';

class AddPublicPostScreen extends ConsumerStatefulWidget {
  /// فایل‌های از پیش انتخاب‌شده (از share intent)
  final List<File> preloadedFiles;
  /// متن از پیش پر‌شده (از share intent)
  final String? preloadedText;

  const AddPublicPostScreen({
    super.key,
    this.preloadedFiles = const [],
    this.preloadedText,
  });

  @override
  _AddPublicPostScreenState createState() => _AddPublicPostScreenState();
}

class _AddPublicPostScreenState extends ConsumerState<AddPublicPostScreen> {
  final SocialTextEditingController contentController =
      SocialTextEditingController();
  bool isLoading = false;

  int get _maxCharLength {
    final currentUser = ref.read(userProvider);
    if (currentUser?.hasBlueBadge == true) return 10000;
    if (currentUser?.hasGoldBadge == true ||
        currentUser?.hasBlackBadge == true ||
        currentUser?.isPremiumUser == true) {
      return 1000;
    }
    return 500;
  }

  /// Whether the current user has any premium tier (badge or active sub).
  bool get _isPremiumUser {
    final u = ref.read(userProvider);
    return u?.hasBlueBadge == true ||
        u?.hasGoldBadge == true ||
        u?.hasBlackBadge == true ||
        u?.isPremiumUser == true;
  }

  /// Carousel image cap: premium users 10, regular users 3.
  int get _maxGalleryImages => _isPremiumUser ? 10 : 3;

  File? _selectedImage;
  final List<File> _selectedImages = []; // گالری چندعکسی (موبایل)
  Uint8List? _selectedImageBytes; // برای وب
  String? _selectedImageName; // برای وب
  File? _selectedMusic;
  String? _musicFileName;
  Duration _musicTrimStart = Duration.zero;
  Duration _musicTrimEnd = Duration.zero;
  bool _musicBackgroundMode = false;
  File? _selectedVideo;
  File? _videoThumbnail; // متغیر جدید برای ذخیره تامبنیل ویدیو
  Uint8List? _selectedVideoBytes; // برای وب
  String? _selectedVideoName; // برای وب

  bool get _hasVideoSelected =>
      _selectedVideo != null || _selectedVideoBytes != null;
  final FocusNode _focusNode = FocusNode();
  VideoPlayerController? _videoPlayerController; // کنترلر ویدیو
  final PageController _galleryController = PageController();
  int _galleryPage = 0;

  @override
  void initState() {
    super.initState();
    contentController.addListener(() {
      if (mounted) setState(() {});
    });

    // استفاده از فایل‌های share شده بدون باز کردن picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPreloadedContent();
    });
  }

  Future<void> _applyPreloadedContent() async {
    if (!mounted) return;
    final files = widget.preloadedFiles;
    if (files.isEmpty && widget.preloadedText == null) return;

    if (widget.preloadedText != null) {
      setState(() {
        contentController.text = widget.preloadedText!;
      });
    }

    if (files.isNotEmpty) {
      final mimeHint = files.first.path.toLowerCase();
      final isVideo = mimeHint.endsWith('.mp4') ||
          mimeHint.endsWith('.mov') ||
          mimeHint.endsWith('.avi') ||
          mimeHint.endsWith('.mkv');

      if (isVideo) {
        final originalFile = files.first;
        final UserModel? currentUser = ref.read(userProvider);
        final maxDuration = currentUser?.hasAnyBadge == true
            ? const Duration(minutes: 2)
            : const Duration(minutes: 1);

        final String? trimmedPath = await Navigator.push<String?>(
          context,
          MaterialPageRoute(
            builder: (context) => YourVideoTrimmerPage(
              videoFile: originalFile,
              maxDuration: maxDuration,
            ),
          ),
        );

        if (trimmedPath != null && trimmedPath.isNotEmpty) {
          final File trimmedFile = File(trimmedPath);
          if (await trimmedFile.exists() && mounted) {
            setState(() {
              _selectedVideo = trimmedFile;
              _selectedVideoName = trimmedFile.path.split('/').last;
            });
            _generateMicroThumbnail(trimmedFile);
            _initVideoPlayer(trimmedFile);
          }
        } else {
          // اگر کنسل کرد، می‌تونه ویدیو اولیه رو مستقیم نشون بدیم یا هیچ چی
          // چون کاربر مستقیماً share کرده بود
        }
      } else {
        setState(() {
          // عکس یا چندین عکس
          if (files.length == 1) {
            _selectedImage = files.first;
            _selectedImages.add(files.first);
          } else {
            _selectedImages.addAll(files.take(_maxGalleryImages));
            _selectedImage = files.first;
          }
        });
      }
    }
  }

  Future<void> _initVideoPlayer(File file) async {
    try {
      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // متد جدید برای تولید میکرو-تامبنیل
  Future<void> _generateMicroThumbnail(File videoFile) async {
    if (kIsWeb) return; // در وب فعلا پشتیبانی نمی‌شود

    try {
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50, // کیفیت پایین برای کاهش حجم
        position: -1, // زمان پیش‌فرض
      );

      setState(() {
        _videoThumbnail = thumbnailFile;
      });

      logDebug(
          'Micro-Thumbnail generated: ${thumbnailFile.lengthSync()} bytes');
    } catch (e) {
      logDebug('Error generating thumbnail: $e');
    }
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImage = null;
            _selectedImages.clear();
            _selectedImageBytes = bytes;
            _selectedImageName = image.name;
            // Video is exclusive; music may coexist with the image (IG-style).
            _selectedVideo = null;
            _selectedVideoBytes = null;
            _selectedVideoName = null;
            _videoThumbnail = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImages
              ..clear()
              ..add(File(image.path));
            _selectedImageBytes = null;
            _selectedImageName = null;
            // Video is exclusive; music may coexist with the image (IG-style).
            _selectedVideo = null;
            _selectedVideoBytes = null;
            _selectedVideoName = null;
            _videoThumbnail = null;
          });
        }
      }
    } catch (e) {
      logDebug('Error picking image: $e');
    }
  }

  /// Multi-image gallery picker (mobile carousel). Web stays single-image.
  Future<void> _pickMultipleImages() async {
    if (kIsWeb) {
      // pickMultiImage bytes flow not wired for web; fall back to single.
      return _pickImage();
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      var files = picked.map((x) => File(x.path)).toList();
      final cap = _maxGalleryImages;
      if (files.length > cap) {
        files = files.sublist(0, cap);
        if (_isPremiumUser) {
          _showSnackBar('حداکثر $cap عکس در هر پست قابل انتخاب است');
        } else {
          _showGalleryUpgradeSnackBar(cap);
        }
      }

      setState(() {
        _selectedImages
          ..clear()
          ..addAll(files);
        _selectedImage = files.first;
        _selectedImageBytes = null;
        _selectedImageName = null;
        // Video exclusive; music may coexist.
        _selectedVideo = null;
        _selectedVideoBytes = null;
        _selectedVideoName = null;
        _videoThumbnail = null;
      });
    } catch (e) {
      logDebug('Error picking multiple images: $e');
      _showError('خطا در انتخاب تصاویر');
    }
  }

  void _removeAllImages() {
    setState(() {
      _selectedImage = null;
      _selectedImages.clear();
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  void _showError(dynamic error) {
    if (!mounted) return;
    UserFriendlyErrorUtils.showErrorSnackBar(context, error);
  }

  void _showUserBadgeInfo(UserModel user) {
    if (!mounted) return;
    String message = user.hasAnyBadge
        ? 'شما کاربر ویژه هستید. محدودیت آپلود: ۲ دقیقه'
        : 'کاربر عادی. محدودیت آپلود: ۱ دقیقه';
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.blue));
  }

  Future<void> _pickMusicFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() {
            _selectedMusic = File(filePath);
            _musicFileName = result.files.single.name;
            _musicTrimStart = Duration.zero;
            _musicTrimEnd = Duration.zero;
            _musicBackgroundMode = false;
            _selectedVideo = null;
            _selectedVideoBytes = null;
            _selectedVideoName = null;
            _videoThumbnail = null;
          });
          await _openMusicTrimSheet();
        }
      }
    } catch (e) {
      logDebug('Error picking music: $e');
      _showError('خطا در انتخاب موزیک');
    }
  }

  Future<void> _openMusicTrimSheet() async {
    if (_selectedMusic == null) return;
    final result = await showMusicTrimSheet(
      context,
      file: _selectedMusic!,
      title: _displayMusicTitle(),
      initialStart: _musicTrimStart,
      initialEnd: _musicTrimEnd > Duration.zero ? _musicTrimEnd : null,
      initialBackgroundMode: _musicBackgroundMode,
    );
    if (result != null && mounted) {
      setState(() {
        _musicTrimStart = result.start;
        _musicTrimEnd = result.end;
        _musicBackgroundMode = result.backgroundMode;
      });
    }
  }

  Widget _buildVideoPreview() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController!),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                if (_videoPlayerController!.value.isPlaying) {
                  _videoPlayerController!.pause();
                } else {
                  _videoPlayerController!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _videoPlayerController!.value.isPlaying ? 0.0 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _videoPlayerController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVideo = null;
                  _selectedVideoBytes = null;
                  _selectedVideoName = null;
                  _videoThumbnail = null;
                  _videoPlayerController?.dispose();
                  _videoPlayerController = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoPlayerController!.setVolume(
                      _videoPlayerController!.value.volume > 0 ? 0.0 : 1.0);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _videoPlayerController!.value.volume > 0
                      ? Icons.volume_up
                      : Icons.volume_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLoading(bool isDarkMode) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? Colors.white10 : Colors.black12,
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      final UserModel? currentUser = ref.read(userProvider);
      if (currentUser == null) {
        _showError('اطلاعات کاربر در دسترس نیست. لطفاً دوباره وارد شوید.');
        return;
      }

      // محدودیت زمانی بر اساس نوع کاربر
      final Duration maxDuration = currentUser.hasAnyBadge
          ? const Duration(minutes: 2) // کاربر ویژه: ۲ دقیقه
          : const Duration(minutes: 1); // کاربر عادی: ۱ دقیقه

      debugPrint(
          'محدودیت زمانی برای کاربر ${currentUser.email}: ${maxDuration.inMinutes} دقیقه');

      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        if (kIsWeb) {
          final videoBytes = result.files.single.bytes;
          if (videoBytes == null) {
            _showError('خطا در خواندن فایل ویدیو');
            return;
          }
          final videoName = result.files.single.name;

          setState(() {
            _selectedVideo = null;
            _selectedVideoBytes = videoBytes;
            _selectedVideoName = videoName;
            _selectedImage = null;
            _selectedImageBytes = null;
            _selectedImageName = null;
            _selectedMusic = null;
            _musicFileName = null;
            _videoThumbnail = null;
          });

          try {
            if (_videoPlayerController != null) {
              await _videoPlayerController!.dispose();
            }

            _videoPlayerController = VideoPlayerController.networkUrl(
              Uri.dataFromBytes(videoBytes, mimeType: 'video/mp4'),
            );

            await _videoPlayerController!.initialize();

            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            logDebug('Error initializing video player: $e');
            _showError('خطا در بارگذاری ویدیو');
          }

          _showUserBadgeInfo(currentUser);
        } else {
          final filePath = result.files.single.path;
          if (filePath == null) {
            _showError('خطا در دریافت مسیر فایل ویدیو');
            return;
          }
          final originalFile = File(filePath);

          if (mounted) {
            final String? trimmedPath = await Navigator.push<String?>(
              context,
              MaterialPageRoute(
                builder: (context) => YourVideoTrimmerPage(
                  videoFile: originalFile,
                  maxDuration: maxDuration,
                ),
              ),
            );

            if (trimmedPath != null && trimmedPath.isNotEmpty) {
              final File trimmedFile = File(trimmedPath);
              if (await trimmedFile.exists()) {
                setState(() {
                  _selectedVideo = trimmedFile;
                  _selectedVideoName = trimmedFile.path.split('/').last;
                  _selectedVideoBytes = null;
                  _selectedImage = null;
                  _selectedImageBytes = null;
                  _selectedImageName = null;
                  _selectedMusic = null;
                  _musicFileName = null;
                  _videoThumbnail = null; // ریست کردن تامبنیل قبلی
                });

                // تولید تامبنیل جدید
                _generateMicroThumbnail(trimmedFile);

                try {
                  if (_videoPlayerController != null) {
                    await _videoPlayerController!.dispose();
                  }
                  _videoPlayerController =
                      VideoPlayerController.file(trimmedFile);
                  await _videoPlayerController!.initialize();

                  if (mounted) {
                    setState(() {});
                  }
                } catch (e) {
                  logDebug('Error initializing video player: $e');
                  _showError('خطا در بارگذاری ویدیو');
                }

                debugPrint(
                    'ویدیو در موبایل برش خورد و انتخاب شد: ${trimmedFile.path}');
              } else {
                _showError('فایل برش خورده ویدیو پیدا نشد.');
              }
            }
          }
        }
      }
    } catch (e, s) {
      logDebug('خطا در انتخاب/برش ویدیو: $e\n$s');
      _showError(
          'خطایی در انتخاب یا پردازش ویدیو رخ داد. لطفاً دوباره تلاش کنید.');
    }
  }

  // ... (keeping existing methods)

  Future<void> _addPost() async {
    final content = contentController.text.trim();
    final tags = _extractTagsFromContent(content);

    if (content.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null &&
        _selectedVideo == null &&
        _selectedVideoBytes == null &&
        _selectedMusic == null) {
      _showSnackBar('لطفاً متن یا تصویری برای پست انتخاب کنید');
      return;
    }

    final maxCharLength = _maxCharLength;
    if (content.length > maxCharLength) {
      _showSnackBar('متن پست نمی‌تواند بیشتر از $maxCharLength کاراکتر باشد');
      return;
    }

    final currentUserId = await CurrentUserService.instance.resolveUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      _showSnackBar('لطفاً ابتدا وارد حساب کاربری خود شوید');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Resolve @mentions → user ids so the backend can fire post_mention
      // notifications + push. Best-effort: unknown usernames are dropped.
      final mentionIds = await _resolveMentionIds(content);

      // شروع آپلود در پس‌زمینه
      await ref.read(postUploadProvider.notifier).startUpload(
            content: content,
            userId: currentUserId,
            image: _selectedImages.length > 1 ? null : _selectedImage,
            images: _selectedImages.length > 1 ? _selectedImages : null,
            imageBytes: _selectedImageBytes,
            imageName: _selectedImageName,
            video: _selectedVideo,
            videoBytes: _selectedVideoBytes,
            videoName: _selectedVideoName,
            music: _selectedMusic,
            musicName: _musicFileName,
            musicStartMs: _musicTrimStart.inMilliseconds > 0
                ? _musicTrimStart.inMilliseconds
                : null,
            musicEndMs: _musicTrimEnd.inMilliseconds > 0
                ? _musicTrimEnd.inMilliseconds
                : null,
            videoThumbnail: _videoThumbnail,
            tags: tags,
            mentionedUserIds: mentionIds,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar('پست در حال ارسال است...', isError: false);
      }
    } catch (e) {
      logDebug('خطا در شروع ارسال پست: $e');
      if (mounted) {
        _showSnackBar('خطا در ارسال پست');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Gallery cap reached for a regular user → nudge toward premium (10 images).
  void _showGalleryUpgradeSnackBar(int cap) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'کاربران عادی تا $cap عکس. با پریمیوم تا ۱۰ عکس در هر پست بگذارید.'),
        backgroundColor: const Color(0xFF4A90E2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'ارتقا',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/premium'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    contentController.dispose();
    _focusNode.dispose();
    _galleryController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context).brightness to ensure consistency with the current context (Scaffold, etc.)
    // avoiding discrepancies if provider and context update at different times or ways.
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // رنگ‌های اصلی برنامه - بروزرسانی شده
    final primaryColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor =
        isDarkMode ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    // Live #/@ token color in the compose field (Instagram link-blue).
    contentController.highlightColor = const Color(0xFF3897F0);

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            'افزودن پست جدید',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ?? backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Column(
                children: [
                  // بخش اصلی
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // نویسنده پست
                            _buildAuthorCard(
                                textColor, secondaryTextColor, cardColor),

                            const SizedBox(height: 16),

                            // فیلد متن

                            _buildContentTextField(
                                textColor, secondaryTextColor, cardColor),

                            const SizedBox(height: 16),

                            // مدیا: ویدیو انحصاری؛ موزیک می‌تواند روی تصویر بنشیند (IG-style).
                            _buildMediaArea(
                                isDarkMode, primaryColor, textColor),

                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // بخش پایین صفحه
                ],
              ),

              // نمایش تولتیپ تبلیغاتی برای کاربران عادی
              if (_maxCharLength == 500)
                Positioned(
                  bottom: 8,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/premium');
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2), // رنگ آبی تلگرامی
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ارتقا به پریمیوم',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '۴۰۰ کاراکتر بنویسید',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // فلش تولتیپ (مثلث)
                        Positioned(
                          bottom: -4,
                          right: 16, // تراز شده با مرکز شمارشگر
                          child: Transform.rotate(
                            angle: 45 * 3.14159 / 180,
                            child: Container(
                              width: 10,
                              height: 10,
                              color: const Color(0xFF4A90E2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar:
            _buildBottomActionBar(isDarkMode, primaryColor, textColor),
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }

  Widget _buildAuthorCard(
      Color textColor, Color secondaryTextColor, Color cardColor) {
    final userData = ref.watch(currentUserMapProvider);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // آواتار کاربر
            CircleAvatar(
              radius: 20,
              backgroundImage: userData.when(
                data: (data) => data != null && data['avatar_url'] != null
                    ? NetworkImage(data['avatar_url'])
                    : const AssetImage('lib/utils/images/default-avatar.jpg')
                        as ImageProvider,
                loading: () =>
                    const AssetImage('lib/utils/images/default-avatar.jpg')
                        as ImageProvider,
                error: (_, __) =>
                    const AssetImage('lib/utils/images/default-avatar.jpg')
                        as ImageProvider,
              ),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 12),
            // اطلاعات کاربر
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userData.when(
                    data: (data) => Row(
                      children: [
                        _buildVerificationBadge(data),

                        Text(
                          data?['username'] ?? 'بدون نام',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        // اضافه کردن نشان تأیید
                      ],
                    ),
                    loading: () => const Text('در حال بارگذاری...'),
                    error: (_, __) => const Text('خطا در بارگذاری نام کاربر'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'در حال ایجاد پست جدید...',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(Map<String, dynamic>? userData) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: VerificationBadgeIcon(
        isVerified: userData?['is_verified'] as bool? ?? false,
        verificationType: userData?['verification_type'],
        role: userData?['role']?.toString(),
        size: 16,
      ),
    );
  }

  Widget _buildContentTextField(
      Color textColor, Color secondaryTextColor, Color cardColor) {
    return HashtagAutocompleteField(
      controller: contentController,
      maxLines: 7,
      minLines: 3,
      hintText: 'چیزی بنویسید...',
      cardColor: cardColor,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
      ),
      hintStyle: TextStyle(color: secondaryTextColor),
    );
  }

  /// Extract tags from post content (#hashtags) for storing in `posts.tags`.
  ///
  /// - Strips leading '#'
  /// - Keeps Persian/Latin letters, digits, underscore
  /// - De-dupes case-insensitively
  List<String> _extractTagsFromContent(String text) {
    final reg = RegExp(r'#([\u0600-\u06FF\w_]+)', unicode: true);
    final seen = <String>{};
    final out = <String>[];

    for (final m in reg.allMatches(text)) {
      final raw = m.group(1);
      if (raw == null) continue;
      final t = raw.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (seen.add(key)) out.add(t);
    }
    return out;
  }

  /// Extract `@usernames` from the caption.
  ///
  /// - Only matches at a word boundary (start or after whitespace) so emails
  ///   like `a@b` don't become mentions.
  /// - De-dupes case-insensitively, keeps first-seen casing.
  List<String> _extractMentionsFromContent(String text) {
    final reg = RegExp(r'(?<![^\s\n])@([؀-ۿ\w_]+)', unicode: true);
    final seen = <String>{};
    final out = <String>[];
    for (final m in reg.allMatches(text)) {
      final raw = m.group(1);
      if (raw == null) continue;
      final t = raw.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (seen.add(key)) out.add(t);
    }
    return out;
  }

  /// Resolve mentioned `@usernames` to user ids (best-effort, parallel).
  /// Unknown / failed lookups are simply omitted.
  Future<List<String>> _resolveMentionIds(String content) async {
    final usernames = _extractMentionsFromContent(content);
    if (usernames.isEmpty) return const <String>[];

    final repo = ProfileRepository();
    final results = await Future.wait(
      usernames.map((username) async {
        try {
          final data =
              await repo.fetchProfileByUsername(username.toLowerCase());
          return (data['user_id'] ?? data['id'] ?? '').toString();
        } catch (_) {
          return '';
        }
      }),
    );

    final ids = <String>{};
    for (final id in results) {
      if (id.trim().isNotEmpty) ids.add(id.trim());
    }
    return ids.toList(growable: false);
  }

  /// Unified photo preview (file + web bytes) with a soft modern frame.
  /// When music is also selected it floats an [_musicOverlayBar] at the bottom
  /// — Instagram "music on photo" composer.
  Widget _buildImagePreview(bool isDarkMode) {
    ImageProvider? provider;
    if (kIsWeb && _selectedImageBytes != null) {
      provider = MemoryImage(_selectedImageBytes!);
    } else if (_selectedImage != null) {
      provider = FileImage(_selectedImage!);
    }
    if (provider == null) return const SizedBox.shrink();

    final hasMusic = _selectedMusic != null;

    return Hero(
      tag: 'post-image',
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image(
              image: provider,
              width: double.infinity,
              height: 320,
              fit: BoxFit.cover,
            ),
            // Top scrim so the controls stay legible on bright photos.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // remove image
            Positioned(
              top: 10,
              right: 10,
              child: _circleIconButton(
                icon: Icons.close,
                onTap: () => setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                  _selectedImageName = null;
                }),
              ),
            ),
            // change / camera
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  _circleIconButton(
                    icon: Icons.photo_library_outlined,
                    onTap: () => _pickImage(),
                  ),
                  const SizedBox(width: 8),
                  _circleIconButton(
                    icon: Icons.camera_alt_outlined,
                    onTap: () => _pickImage(source: ImageSource.camera),
                  ),
                ],
              ),
            ),
            // music-on-photo overlay
            if (hasMusic)
              Positioned(
                left: _musicBackgroundMode ? null : 10,
                right: 10,
                bottom: _musicBackgroundMode ? null : 10,
                top: _musicBackgroundMode ? 10 : null,
                child: _musicOverlayBar(),
              ),
          ],
        ),
      ).animate().scale(
            duration: const Duration(milliseconds: 260),
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            curve: Curves.easeOut,
          ),
    );
  }

  /// Small circular glass-less icon button used on top of media previews.
  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  /// Spinning album disc — soft brand gradient, repeats forever.
  Widget _spinningDisc({double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFF58529), AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.music_note, color: Colors.white, size: size * 0.5),
    ).animate(onPlay: (c) => c.repeat()).rotate(
          begin: 0,
          end: 1,
          duration: const Duration(seconds: 4),
        );
  }

  void _removeMusic() => setState(() {
        _selectedMusic = null;
        _musicFileName = null;
        _musicTrimStart = Duration.zero;
        _musicTrimEnd = Duration.zero;
        _musicBackgroundMode = false;
      });

  /// Clean display title from the picked audio filename.
  String _displayMusicTitle() {
    final name = _musicFileName;
    if (name == null || name.trim().isEmpty) return 'موزیک';
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final cleaned = base
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'موزیک' : cleaned;
  }

  /// Floating music overlay shown on a photo.
  /// Background mode → compact button in corner.
  /// Bubble mode → full bar at bottom.
  Widget _musicOverlayBar() {
    if (_musicBackgroundMode) {
      return _buildBackgroundModeCornerBadge();
    }
    return _buildBubbleModeBar();
  }

  Widget _buildBubbleModeBar() {
    return GestureDetector(
      onTap: _openMusicTrimSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _spinningDisc(size: 28),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                _displayMusicTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const AudioEqualizerBars(
              color: Colors.white,
              height: 14,
              barCount: 3,
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _removeMusic,
              customBorder: const CircleBorder(),
              child: Icon(Icons.close,
                  color: Colors.white.withValues(alpha: 0.55), size: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundModeCornerBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Edit trim button
        GestureDetector(
          onTap: _openMusicTrimSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _spinningDisc(size: 20),
                const SizedBox(width: 6),
                Text(
                  _displayMusicTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.volume_up_rounded,
                    color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _removeMusic,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white70, size: 16),
          ),
        ),
      ],
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Whole media region: video (exclusive) OR photo (+optional music) OR
  /// standalone music OR the empty picker. Plus an "add the missing one" row.
  Widget _buildMediaArea(bool isDarkMode, Color primaryColor, Color textColor) {
    if (_hasVideoSelected) {
      return (_videoPlayerController != null &&
              _videoPlayerController!.value.isInitialized)
          ? _buildVideoPreview()
          : _buildVideoLoading(isDarkMode);
    }

    final hasImage = _selectedImage != null || _selectedImageBytes != null;
    final hasMusic = _selectedMusic != null;

    if (!hasImage && !hasMusic) {
      return _buildMediaUploadSection(isDarkMode, primaryColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage)
          (_selectedImages.length > 1
              ? _buildImageCarouselPreview(isDarkMode, hasMusic)
              : _buildImagePreview(isDarkMode))
        else if (hasMusic)
          _buildMusicPreview(isDarkMode, primaryColor, textColor),
        _buildAddMoreRow(
          hasImage: hasImage,
          hasMusic: hasMusic,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  /// Multi-image carousel preview (PageView + dot indicator + counter), with
  /// the same soft frame as the single preview. Music bar floats on top.
  Widget _buildImageCarouselPreview(bool isDarkMode, bool hasMusic) {
    final count = _selectedImages.length;
    final page = _galleryPage.clamp(0, count - 1);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SizedBox(
            height: 320,
            width: double.infinity,
            child: PageView.builder(
              controller: _galleryController,
              itemCount: count,
              onPageChanged: (i) => setState(() => _galleryPage = i),
              itemBuilder: (context, i) => Image.file(
                _selectedImages[i],
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // top scrim for control legibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // counter pill (1/3)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${page + 1}/$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // replace all
          Positioned(
            top: 10,
            right: 10,
            child: _circleIconButton(
              icon: Icons.close,
              onTap: _removeAllImages,
            ),
          ),
          // change selection
          Positioned(
            top: 10,
            left: 10,
            child: _circleIconButton(
              icon: Icons.collections_outlined,
              onTap: _pickMultipleImages,
            ),
          ),
          // dot indicator
          Positioned(
            left: 0,
            right: 0,
            bottom: (hasMusic && !_musicBackgroundMode) ? 72 : 12,
            child: _buildDots(count, page),
          ),
          if (hasMusic)
            Positioned(
              left: _musicBackgroundMode ? null : 10,
              right: 10,
              bottom: _musicBackgroundMode ? null : 10,
              top: _musicBackgroundMode ? 10 : null,
              child: _musicOverlayBar(),
            ),
        ],
      ),
    ).animate().scale(
          duration: const Duration(milliseconds: 260),
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          curve: Curves.easeOut,
        );
  }

  Widget _buildDots(int count, int active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  /// Soft pill chips to add whichever media isn't selected yet.
  Widget _buildAddMoreRow({
    required bool hasImage,
    required bool hasMusic,
    required bool isDarkMode,
  }) {
    final chips = <Widget>[];
    if (!hasImage) {
      chips.add(_addMediaChip(
        icon: Icons.image_outlined,
        label: 'افزودن تصویر',
        color: const Color(0xFF3897F0),
        onTap: _pickMultipleImages,
        isDarkMode: isDarkMode,
      ));
    }
    if (!hasMusic) {
      chips.add(_addMediaChip(
        icon: Icons.music_note_outlined,
        label: 'افزودن موزیک',
        color: const Color(0xFF1DB954),
        onTap: _pickMusicFile,
        isDarkMode: isDarkMode,
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (int i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _addMediaChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaUploadSection(bool isDarkMode, Color primaryColor) {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        color: isDarkMode ? Colors.white38 : Colors.black38,
        strokeWidth: 1,
        dashPattern: const [6, 4],
      ),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'محتوای چندرسانه‌ای اضافه کنید',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // دکمه افزودن تصویر از گالری
                _buildMediaButton(
                  icon: Icons.image,
                  label: 'تصویر',
                  onTap: _pickMultipleImages,
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                  tileColor: const Color(0xFF3897F0),
                ),
                const SizedBox(width: 16),
                // دکمه افزودن تصویر از دوربین
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'دوربین',
                  onTap: () => _pickImage(source: ImageSource.camera),
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                  tileColor: AppColors.secondary,
                ),
                const SizedBox(width: 16),
                // دکمه افزودن ویدیو
                _buildMediaButton(
                  icon: Icons.videocam_outlined,
                  label: 'ویدیو',
                  onTap: _pickVideo,
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                  tileColor: const Color(0xFFE0457B),
                ),
                const SizedBox(width: 16),
                // دکمه افزودن موزیک
                _buildMediaButton(
                  icon: Icons.music_note,
                  label: 'موزیک',
                  onTap: _pickMusicFile,
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                  tileColor: const Color(0xFF1DB954),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400));
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color primaryColor,
    required bool isDarkMode,
    Color? tileColor,
  }) {
    final accent = tileColor ?? primaryColor;
    return Column(
      children: [
        Material(
          color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.12),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Icon(
                icon,
                color: accent,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  /// Compact music pill (no photo). Tap → open trim sheet.
  Widget _buildMusicPreview(
      bool isDarkMode, Color primaryColor, Color textColor) {
    const accent = AppColors.secondary;
    const accentEnd = AppColors.accent;
    final hasTrim = _musicTrimEnd > Duration.zero;

    return GestureDetector(
      onTap: _openMusicTrimSheet,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1033), Color(0xFF2D1B4E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _spinningDisc(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayMusicTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasTrim
                        ? '${_fmtDur(_musicTrimStart)} – ${_fmtDur(_musicTrimEnd)}'
                        : 'برای برش ضربه بزنید',
                    style: TextStyle(
                      color: hasTrim ? accent : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Mode dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _musicBackgroundMode ? accentEnd : accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            // Remove
            InkWell(
              onTap: _removeMusic,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close,
                    color: Colors.white.withValues(alpha: 0.40), size: 17),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 240)).slideY(
          begin: 0.06,
          end: 0,
          duration: const Duration(milliseconds: 240),
        );
  }

  Widget _buildBottomActionBar(
      bool isDarkMode, Color primaryColor, Color textColor) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // نمایشگر تعداد کاراکترها
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: contentController,
              builder: (context, value, _) {
                final maxLen = _maxCharLength;
                final count = value.text.length;
                final progress = (count / maxLen).clamp(0.0, 1.0);
                final remaining = maxLen - count;

                Color indicatorColor;
                if (count > maxLen) {
                  indicatorColor = Colors.redAccent;
                } else if (count > maxLen * 0.8) {
                  indicatorColor = Colors.orangeAccent;
                } else {
                  indicatorColor = isDarkMode ? Colors.white70 : Colors.black54;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor:
                            isDarkMode ? Colors.white12 : Colors.black12,
                        color: indicatorColor,
                      ),
                    ),
                    Text(
                      remaining.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: remaining.abs() >= 100 ? 10 : 13,
                        color: indicatorColor,
                      ),
                    ),
                  ],
                );
              },
            ),

            // دکمه‌های اکشن
            Row(
              children: [
                const SizedBox(width: 8),

                // دکمه ارسال پست
                ElevatedButton(
                  onPressed: isLoading ? null : _addPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    // تغییر رنگ متن بر اساس حالت تاریک/روشن
                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            // تنظیم رنگ لودینگ متناسب با رنگ متن
                            color: isDarkMode ? Colors.black : Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              'ارسال پست',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                // تنظیم رنگ متن متناسب با پس‌زمینه
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.send,
                              size: 18,
                              // تنظیم رنگ آیکون متناسب با پس‌زمینه
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
