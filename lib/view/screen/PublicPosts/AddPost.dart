import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../main.dart';
import '../../../provider/PostImageUploadService.dart';
import '../../../provider/provider.dart';

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
  File? _selectedMusic;
  String? _musicFileName;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    contentController.addListener(() {
      setState(() {
        remainingChars = maxCharLength - contentController.text.length;
      });
    });

    // اضافه کردن انیمیشن ورود با تاخیر
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
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
      setState(() {
        _selectedImage = File(image.path);
      });
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

  Future<void> _addPost() async {
    final content = contentController.text.trim();

    // بررسی محدودیت‌های متن
    if (content.length > maxCharLength) {
      _showSnackBar('متن پست نمی‌تواند بیشتر از ۳۰۰ کاراکتر باشد');
      return;
    }

    if (content.isEmpty && _selectedImage == null && _selectedMusic == null) {
      _showSnackBar('لطفاً متن، تصویر یا موزیکی برای ارسال پست انتخاب کنید');
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

      // آپلود تصویر در صورت انتخاب
      if (_selectedImage != null) {
        imageUrl =
            await PostImageUploadService.uploadPostImage(_selectedImage!);
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

                        // پیش‌نمایش تصویر
                        if (_selectedImage != null)
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
                    : const AssetImage('lib/util/images/default-avatar.jpg')
                        as ImageProvider,
                loading: () =>
                    const AssetImage('lib/util/images/default-avatar.jpg')
                        as ImageProvider,
                error: (_, __) =>
                    const AssetImage('lib/util/images/default-avatar.jpg')
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
                    data: (data) => Text(
                      data['username'] ?? 'بدون نام',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
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
          focusNode: _focusNode,
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
    return Hero(
      tag: 'post-image',
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            // تصویر
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
                        child: Icon(Icons.edit, color: Colors.white, size: 18),
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
