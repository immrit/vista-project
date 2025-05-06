import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../../../main.dart';
import '../../../services/PostImageUploadService.dart';
import '../../../provider/provider.dart';
import '../../widgets/CustomVideoTrimmer.dart';

class AddPublicPostScreen extends ConsumerStatefulWidget {
  const AddPublicPostScreen({super.key});

  @override
  _AddPublicPostScreenState createState() => _AddPublicPostScreenState();
}

class _AddPublicPostScreenState extends ConsumerState<AddPublicPostScreen> {
  final TextEditingController contentController = TextEditingController();
  bool isLoading = false;
  static const int maxCharLength = 300;
  int remainingChars = maxCharLength;
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // برای وب
  String? _selectedImageName; // برای وب
  File? _selectedMusic;
  String? _musicFileName;
  File? _selectedVideo;
  Uint8List? _selectedVideoBytes; // برای وب
  String? _selectedVideoName; // برای وب
  final FocusNode _focusNode = FocusNode();
  VideoPlayerController? _videoPlayerController; // کنترلر ویدیو

  @override
  void initState() {
    super.initState();
    contentController.addListener(() {
      setState(() {
        remainingChars = maxCharLength - contentController.text.length;
      });
    });

    // اضافه کردن انیمیشن ورود با تاخیر
    // Future.delayed(const Duration(milliseconds: 100), () {
    //   _focusNode.requestFocus();
    // });
  }

  Color _getCharCountColor() {
    final int count = contentController.text.length;
    if (count > maxCharLength) return Colors.redAccent;
    if (count > maxCharLength * 0.8) return Colors.orangeAccent;
    return ref.watch(themeProvider).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  double _calculateProgress() {
    return (contentController.text.length / maxCharLength).clamp(0.0, 1.0);
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
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
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageBytes = null;
          _selectedImageName = null;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        if (kIsWeb) {
          final videoBytes = result.files.single.bytes!;
          final videoName = result.files.single.name;

          // Create a blob URL for web
          final blobUrl = await _createVideoBlobUrl(videoBytes);

          if (mounted) {
            // استفاده مستقیم از نتیجه برگشتی با await
            final dynamic trimmedResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomVideoTrimmer(
                  videoFile: blobUrl,
                  onVideoSaved: (File file) {
                    // این callback دیگر استفاده نمی‌شود ولی برای سازگاری نگه می‌داریم
                  },
                  isWeb: true,
                ),
              ),
            );

            // بررسی نتیجه برگشتی
            if (trimmedResult != null) {
              setState(() {
                _selectedVideo = null;
                _selectedVideoBytes = videoBytes;
                _selectedVideoName = videoName;
                _selectedImage = null;
                _selectedImageBytes = null;
                _selectedImageName = null;
              });
              _initializeVideoPlayerWeb(
                  _selectedVideoBytes!, _selectedVideoName!);
            }
          }
        } else {
          final file = File(result.files.single.path!);
          debugPrint('Original video path: ${file.path}');

          if (mounted) {
            // صفحه برش ویدیو با await و دریافت مستقیم نتیجه
            final File? trimmedFile = await Navigator.push<File>(
              context,
              MaterialPageRoute(
                builder: (context) => CustomVideoTrimmer(
                  videoFile: file,
                  onVideoSaved: (File file) {
                    // این callback دیگر استفاده نمی‌شود ولی برای سازگاری نگه می‌داریم
                  },
                  isWeb: false,
                ),
              ),
            );

            if (trimmedFile != null && trimmedFile.existsSync()) {
              debugPrint('Received trimmed video: ${trimmedFile.path}');

              setState(() {
                _selectedVideo = trimmedFile;
                _selectedVideoBytes = null;
                _selectedVideoName = trimmedFile.path.split('/').last;
                _selectedImage = null;
                _selectedImageBytes = null;
                _selectedImageName = null;
                _videoPlayerController?.dispose();
                _videoPlayerController = null;
              });

              // راه‌اندازی مجدد پلیر با تاخیر
              await Future.delayed(const Duration(milliseconds: 300));
              await _initializeVideoPlayerMobile(trimmedFile);
            } else {
              debugPrint('No valid trimmed video received');
              _showError('خطا در دریافت ویدیوی برش خورده');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _pickVideo: $e');
      _showError('خطا در انتخاب ویدیو');
    }
  }

  Future<String> _createVideoBlobUrl(Uint8List bytes) async {
    if (kIsWeb) {
      final blob = await _createWebBlob(bytes);
      return _createWebObjectUrl(blob);
    }
    return '';
  }

  Future<void> _initializeVideoPlayerMobile(File file) async {
    try {
      debugPrint('Initializing video player with file: ${file.path}');
      await _videoPlayerController?.dispose();

      if (!file.existsSync()) {
        throw Exception('فایل ویدیو یافت نشد');
      }

      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setLooping(true);
      await _videoPlayerController!.play(); // پخش ویدیو
      setState(() {}); // اعمال تغییرات در UI
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      _showError('خطا در بارگذاری ویدیو');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _initializeVideoPlayerWeb(Uint8List bytes, String name) async {
    try {
      await _videoPlayerController?.dispose();
      if (kIsWeb) {
        // فقط در وب: ساخت blob و url
        final blob = await _createWebBlob(bytes);
        final url = _createWebObjectUrl(blob);
        _videoPlayerController = VideoPlayerController.network(url);
        await _videoPlayerController!.initialize();
        await _videoPlayerController!.setLooping(true);
        await _videoPlayerController!.play(); // پخش ویدیو
        setState(() {}); // اعمال تغییرات در UI
      }
    } catch (e) {
      debugPrint('Error initializing web video player: $e');
      _showError('خطا در بارگذاری ویدیو');
    }
  }

  Future<void> _pickMusicFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedMusic = File(result.files.single.path!);
        _musicFileName = result.files.single.name;
      });
    }
  }

  Widget _buildVideoPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // نمایش ویدیو
          AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController!),
          ),

          // دکمه پخش/توقف
          Positioned.fill(
            child: GestureDetector(
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
                    opacity:
                        _videoPlayerController!.value.isPlaying ? 0.0 : 0.7,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
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
          ),

          // دکمه حذف
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoPlayerController?.pause();
                  _videoPlayerController?.dispose();
                  _videoPlayerController = null;
                  _selectedVideo = null;
                  _selectedVideoBytes = null;
                  _selectedVideoName = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
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

          // دکمه قطع/وصل صدا - این قسمت را اضافه کردیم
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
                  color: Colors.black.withOpacity(0.6),
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

          // نشانگر برش خورده
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cut, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'برش خورده',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPost() async {
    final content = contentController.text.trim();

    // بررسی محدودیت‌های متن
    if (content.length > maxCharLength) {
      _showSnackBar('متن پست نمی‌تواند بیشتر از ۳۰۰ کاراکتر باشد');
      return;
    }

    if (content.isEmpty &&
        _selectedImage == null &&
        _selectedMusic == null &&
        _selectedVideo == null) {
      _showSnackBar(
          'لطفاً متن، تصویر، ویدیو یا موزیکی برای ارسال پست انتخاب کنید');
      return;
    }

    if (content.isNotEmpty && content.length < 3) {
      _showSnackBar('متن پست باید حداقل ۳ حرف داشته باشد');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageUrl;
      String? musicUrl;
      String? videoUrl;

      // آپلود تصویر در صورت انتخاب
      if (kIsWeb && _selectedImageBytes != null && _selectedImageName != null) {
        imageUrl = await PostImageUploadService.uploadPostImageWeb(
            _selectedImageBytes!, _selectedImageName!);
      } else if (_selectedImage != null) {
        imageUrl =
            await PostImageUploadService.uploadPostImage(_selectedImage!);
      }

      // آپلود ویدیو در صورت انتخاب
      if (kIsWeb && _selectedVideoBytes != null && _selectedVideoName != null) {
        videoUrl = await PostImageUploadService.uploadVideoFileWeb(
            _selectedVideoBytes!, _selectedVideoName!);
      } else if (_selectedVideo != null) {
        videoUrl =
            await PostImageUploadService.uploadVideoFile(_selectedVideo!);
      }

      // آپلود موزیک در صورت انتخاب
      if (_selectedMusic != null) {
        musicUrl =
            await PostImageUploadService.uploadMusicFile(_selectedMusic!);
      }

      // ایجاد پست
      final postData = {
        'user_id': supabase.auth.currentUser!.id,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        if (musicUrl != null) 'music_url': musicUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('posts').insert(postData).then((value) {
        ref.refresh(postsProvider);
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar('پست با موفقیت منتشر شد', isError: false);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'خطا در ارسال پست';
        if (e.toString().contains('storage')) {
          errorMessage = 'خطا در آپلود فایل. لطفاً دوباره تلاش کنید';
        }
        _showSnackBar(errorMessage);
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

  @override
  void dispose() {
    contentController.dispose();
    _focusNode.dispose();
    _videoPlayerController?.dispose(); // آزادسازی کنترلر ویدیو
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isDarkMode = theme.brightness == Brightness.dark;

    // رنگ‌های اصلی برنامه - بروزرسانی شده
    final primaryColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final cardColor =
        isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;

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
          backgroundColor: backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
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

// اضافه کردن ویجت پیش‌نمایش ویدیو
                        if (_videoPlayerController != null &&
                            _videoPlayerController!.value.isInitialized)
                          _buildVideoPreview(),

                        // افزودن دکمه انتخاب ویدیو
                        if (_selectedVideo == null &&
                            _selectedVideoBytes == null &&
                            _selectedImage == null &&
                            _selectedImageBytes == null)

                          // نمایش پیش‌نمایش ویدیو انتخاب شده
                          if (_selectedVideo != null ||
                              _selectedVideoBytes != null)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    child: Container(
                                      height: 200,
                                      color: Colors.black87,
                                      child: _videoPlayerController != null &&
                                              _videoPlayerController!
                                                  .value.isInitialized
                                          ? Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                AspectRatio(
                                                  aspectRatio:
                                                      _videoPlayerController!
                                                          .value.aspectRatio,
                                                  child: VideoPlayer(
                                                      _videoPlayerController!),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      if (_videoPlayerController!
                                                          .value.isPlaying) {
                                                        _videoPlayerController!
                                                            .pause();
                                                      } else {
                                                        _videoPlayerController!
                                                            .play();
                                                      }
                                                    });
                                                  },
                                                  child: Icon(
                                                    _videoPlayerController!
                                                            .value.isPlaying
                                                        ? Icons.pause_circle
                                                        : Icons
                                                            .play_circle_fill,
                                                    size: 64,
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.play_circle_fill,
                                                size: 64,
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'ویدیو انتخاب شده: ${_selectedVideoName ?? _selectedVideo?.path.split('/').last ?? 'ویدیو'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.close, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _selectedVideo = null;
                                              _selectedVideoBytes = null;
                                              _selectedVideoName = null;
                                              _videoPlayerController?.dispose();
                                              _videoPlayerController = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                        // پیش‌نمایش تصویر
                        if (_selectedImage != null ||
                            _selectedImageBytes != null)
                          _buildImagePreview(isDarkMode)
                        else
                          _buildMediaUploadSection(isDarkMode, primaryColor),

                        // پیش‌نمایش موزیک
                        if (_selectedMusic != null)
                          _buildMusicPreview(
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
        ),
        bottomNavigationBar:
            _buildBottomActionBar(isDarkMode, primaryColor, textColor),
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }

  Widget _buildAuthorCard(
      Color textColor, Color secondaryTextColor, Color cardColor) {
    final userData = ref.watch(currentUserProvider);

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
                data: (data) => data['avatar_url'] != null
                    ? NetworkImage(data['avatar_url'])
                    : const AssetImage(
                            'lib/view/util/images/default-avatar.jpg')
                        as ImageProvider,
                loading: () =>
                    const AssetImage('lib/view/util/images/default-avatar.jpg')
                        as ImageProvider,
                error: (_, __) =>
                    const AssetImage('lib/view/util/images/default-avatar.jpg')
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
                          data['username'] ?? 'بدون نام',
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
    // بررسی وضعیت تأیید حساب کاربری
    final bool isVerified = userData?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    // بررسی نوع نشان تأیید
    final String verificationType = userData?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

    // تعیین نوع و رنگ آیکون بر اساس نوع نشان
    switch (verificationType) {
      case 'blueTick':
        iconData = Icons.verified;
        iconColor = Colors.blue;
        break;
      case 'goldTick':
        iconData = Icons.verified;
        iconColor = Colors.amber;
        break;
      case 'blackTick':
        iconData = Icons.verified;
        iconColor = Colors.black;
        break;
      default:
        // حالت پیش‌فرض برای پروفایل‌های تأیید شده بدون نوع مشخص
        iconData = Icons.verified;
        iconColor = Colors.blue;
    }

    // ایجاد ویجت نشان بر اساس نوع
    if (verificationType == 'blackTick') {
      // اضافه کردن پس‌زمینه باریک برای تیک مشکی
      return Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Container(
          padding: const EdgeInsets.all(.3), // فاصله باریک برای پس‌زمینه
          decoration: BoxDecoration(
            color: Colors.white, // پس‌زمینه سفید
            shape: BoxShape.circle, // پس‌زمینه دایره‌ای
          ),
          child: Icon(iconData, color: iconColor, size: 16),
        ),
      );
    } else {
      // بازگشت آیکون ساده برای تیک‌های آبی و طلایی
      return Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Icon(iconData, color: iconColor, size: 16),
      );
    }
  }

// نمایش اطلاعات کاربر در بالای صفحه افزودن پست
  Widget _buildUserInfo(BuildContext context, Map<String, dynamic> userData) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: userData['avatar_url'] != null
              ? NetworkImage(userData['avatar_url'])
              : const AssetImage('lib/view/util/images/default-avatar.jpg')
                  as ImageProvider,
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Text(
              userData['username'] ?? 'کاربر',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // نمایش نشان تأیید در کنار نام کاربر
            _buildVerificationBadge(userData),
          ],
        ),
      ],
    );
  }

  Widget _buildContentTextField(
      Color textColor, Color secondaryTextColor, Color cardColor) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: contentController,
          // focusNode: _focusNode,
          maxLines: 7,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'چیزی بنویسید...',
            hintStyle: TextStyle(color: secondaryTextColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool isDarkMode) {
    if (kIsWeb && _selectedImageBytes != null) {
      // نمایش تصویر انتخاب شده در وب
      return Hero(
        tag: 'post-image',
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              Image.memory(
                _selectedImageBytes!,
                width: double.infinity,
                fit: BoxFit.cover,
                height: 250,
              ),
              // دکمه حذف
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() => _selectedImageBytes = null),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              // دکمه‌های ویرایش
              Positioned(
                bottom: 8,
                left: 8,
                child: Row(
                  children: [
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _pickImage(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child:
                              Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _pickImage(source: ImageSource.camera),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().scale(duration: const Duration(milliseconds: 300)),
      );
    } else if (_selectedImage != null) {
      return Hero(
        tag: 'post-image',
        child: Card(
          // ...existing code...
          child: Stack(
            children: [
              Image.file(
                _selectedImage!,
                width: double.infinity,
                fit: BoxFit.cover,
                height: 250,
              ),
              // دکمه حذف
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() => _selectedImage = null),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              // دکمه‌های ویرایش
              Positioned(
                bottom: 8,
                left: 8,
                child: Row(
                  children: [
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _pickImage(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child:
                              Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _pickImage(source: ImageSource.camera),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().scale(duration: const Duration(milliseconds: 300)),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildMediaUploadSection(bool isDarkMode, Color primaryColor) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      color: isDarkMode ? Colors.white38 : Colors.black38,
      strokeWidth: 1,
      dashPattern: const [6, 4],
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.02),
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
                  onTap: () => _pickImage(),
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 16),
                // دکمه افزودن تصویر از دوربین
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'دوربین',
                  onTap: () => _pickImage(source: ImageSource.camera),
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 16),
                // دکمه افزودن ویدیو
                _buildMediaButton(
                  icon: Icons.videocam_outlined,
                  label: 'ویدیو',
                  onTap: _pickVideo,
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 16),
                // دکمه افزودن موزیک
                _buildMediaButton(
                  icon: Icons.music_note,
                  label: 'موزیک',
                  onTap: _pickMusicFile,
                  primaryColor: primaryColor,
                  isDarkMode: isDarkMode,
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
  }) {
    return Column(
      children: [
        Material(
          color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                icon,
                color: primaryColor,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildMusicPreview(
      bool isDarkMode, Color primaryColor, Color textColor) {
    return Card(
      elevation: 0,
      color: isDarkMode
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.music_note,
            color: primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          _musicFileName ?? 'فایل موزیک',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'آماده ارسال',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          onPressed: () {
            setState(() {
              _selectedMusic = null;
              _musicFileName = null;
            });
          },
        ),
      ),
    ).animate().slide(duration: const Duration(milliseconds: 300));
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
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    value: _calculateProgress(),
                    strokeWidth: 3,
                    backgroundColor:
                        isDarkMode ? Colors.white12 : Colors.black12,
                    color: _getCharCountColor(),
                  ),
                ),
                Text(
                  remainingChars.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _getCharCountColor(),
                  ),
                ),
              ],
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

Future<dynamic> _createWebBlob(Uint8List bytes) async {
  if (kIsWeb) {
    // ignore: avoid_web_libraries_in_flutter
    return Future.value(
      // ignore: undefined_prefixed_name
      (await importJsLibrary('dart:html')).callMethod('Blob', [
        [bytes]
      ]),
    );
  }
  return null;
}

String _createWebObjectUrl(dynamic blob) {
  if (kIsWeb && blob != null) {
    // ignore: avoid_web_libraries_in_flutter
    // ignore: undefined_prefixed_name
    return (importJsLibrary('dart:html'))
        .callMethod('Url')
        .callMethod('createObjectUrlFromBlob', [blob]);
  }
  return '';
}

// این تابع فقط برای جلوگیری از خطا است و در وب مقدار واقعی را برمی‌گرداند.
dynamic importJsLibrary(String name) => throw UnsupportedError('Web only');
