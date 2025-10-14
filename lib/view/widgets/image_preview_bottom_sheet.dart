import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ImagePreviewBottomSheet extends StatefulWidget {
  final List<File> files;
  final Function(List<File>, String?)? onConfirm;

  const ImagePreviewBottomSheet({
    super.key,
    required this.files,
    this.onConfirm,
  });

  @override
  State<ImagePreviewBottomSheet> createState() =>
      _ImagePreviewBottomSheetState();
}

class _ImagePreviewBottomSheetState extends State<ImagePreviewBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late PageController _pageController;
  late TextEditingController _captionController;
  int _currentIndex = 0;

  // برای مجبور کردن بازسازی PhotoView وقتی تصویر تغییر می‌کند
  late Map<int, UniqueKey> _imageKeys;

  // نگه داشتن بایت‌های ویرایش شده برای هر تصویر
  late Map<int, Uint8List?> _editedBytes;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pageController = PageController();
    _captionController = TextEditingController();

    // مقداردهی اولیه کلیدها برای هر تصویر
    _imageKeys = {};
    _editedBytes = {};
    for (int i = 0; i < widget.files.length; i++) {
      _imageKeys[i] = UniqueKey();
      _editedBytes[i] = null; // هیچ ویرایشی انجام نشده
    }

    _animationController.forward();

    // اعتبارسنجی فایل‌ها بعد از مقداردهی اولیه
    _validateFiles();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// اعتبارسنجی فایل‌ها و تلاش مجدد در صورت عدم دسترسی
  Future<void> _validateFiles() async {
    for (int i = 0; i < widget.files.length; i++) {
      final file = widget.files[i];
      if (!await file.exists()) {
        debugPrint('⚠️ فایل ${file.path} وجود ندارد، تلاش برای بازسازی...');
        // تلاش مجدد بعد از یک تأخیر کوتاه
        await Future.delayed(const Duration(milliseconds: 500));
        if (await file.exists()) {
          debugPrint('✅ فایل ${file.path} بعد از تأخیر در دسترس قرار گرفت');
          if (mounted) {
            setState(() {
              _imageKeys[i] = UniqueKey(); // مجبور کردن بازسازی PhotoView
            });
          }
        } else {
          debugPrint('❌ فایل ${file.path} همچنان در دسترس نیست');
        }
      }
    }
  }

  /// بررسی وجود فایل و بازگرداندن imageProvider مناسب
  ImageProvider _buildImageProvider(int index) {
    final file = widget.files[index];

    // اگر بایت‌های ویرایش شده وجود دارد، از آن استفاده کن
    if (_editedBytes[index] != null) {
      return MemoryImage(_editedBytes[index]!);
    }

    // استفاده مستقیم از FileImage - PhotoView خودش error handling را انجام می‌دهد
    return FileImage(file);
  }

  Future<void> _openCropper() async {
    try {
      final originalFile = widget.files[_currentIndex];
      if (!mounted) return;

      // Read file bytes and use memory editor
      final bytes = await originalFile.readAsBytes();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.memory(
            bytes,
            configs: ProImageEditorConfigs(
              i18n: const I18n(
                // دکمه‌های اصلی
                done: 'تایید',
                cancel: 'لغو',
              ),
            ),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (editedBytes) async {
                try {
                  debugPrint(
                      'تصویر ویرایش شده دریافت شد، اندازه: ${editedBytes.length} بایت');

                  if (mounted) {
                    setState(() {
                      _editedBytes[_currentIndex] = editedBytes;
                      _imageKeys[_currentIndex] = UniqueKey();
                    });

                    debugPrint('تصویر ویرایش شده در پیش‌نمایش به‌روزرسانی شد');

                    // نمایش پیام موفقیت
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تصویر ویرایش شد'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // بستن ویرایشگر و بازگشت به پیش‌نمایش
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  debugPrint('خطا در ذخیره تصویر ویرایش شده: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطا در ذخیره تصویر: $e')),
                    );
                    // حتی در صورت خطا، ویرایشگر را ببند
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('خطا در ویرایش تصویر: $e');
    }
  }

  void _sendImages() async {
    final caption = _captionController.text.trim();

    try {
      // اگر بایت‌های ویرایش شده وجود دارد، فایل جدید بساز
      if (_editedBytes.isNotEmpty) {
        final updatedFiles = <File>[];

        for (int i = 0; i < widget.files.length; i++) {
          if (_editedBytes[i] != null) {
            // فایل جدید از بایت‌های ویرایش شده بساز
            final directory = await getApplicationDocumentsDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final originalName = widget.files[i].path.split('/').last;
            final editedFileName = 'edited_${timestamp}_$originalName';
            final editedFile = File('${directory.path}/$editedFileName');

            await editedFile.writeAsBytes(_editedBytes[i]!);
            updatedFiles.add(editedFile);
          } else {
            // فایل اصلی را نگه دار
            updatedFiles.add(widget.files[i]);
          }
        }

        if (widget.onConfirm != null) {
          widget.onConfirm!(updatedFiles, caption.isEmpty ? null : caption);
        }
      } else {
        // اگر ویرایشی انجام نشده، فایل‌های اصلی را ارسال کن
        if (widget.onConfirm != null) {
          widget.onConfirm!(widget.files, caption.isEmpty ? null : caption);
        }
      }
    } catch (e) {
      debugPrint('خطا در ارسال تصاویر ویرایش شده: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال تصاویر: $e')),
        );
      }
    }

    _closeSheet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Custom accent colors (avoid using theme.primaryColor)
    final Color accent = const Color(0xFF2196F3);
    final Color accentBorder = accent.withValues(alpha: 0.3);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.92,
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
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
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

                      // Header (X on the left, counter (if any), and check on the right)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            // Close button (placed where the title was)
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
                            const Spacer(),
                            if (widget.files.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${_currentIndex + 1} / ${widget.files.length}',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            // Edit button (pencil icon)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _openCropper,
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Image viewer
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemCount: widget.files.length,
                              itemBuilder: (context, index) {
                                return PhotoView(
                                  key: _imageKeys[index],
                                  imageProvider: _buildImageProvider(index),
                                  minScale: PhotoViewComputedScale.contained,
                                  maxScale: PhotoViewComputedScale.covered * 2,
                                  backgroundDecoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[100],
                                  ),
                                  loadingBuilder: (context, event) => Center(
                                    child: CircularProgressIndicator(
                                      color: accent,
                                      value: event == null
                                          ? null
                                          : event.cumulativeBytesLoaded /
                                              event.expectedTotalBytes!,
                                    ),
                                  ),
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        '❌ PhotoView error for index $index: $error');
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 64,
                                            color: isDark
                                                ? Colors.grey[600]
                                                : Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'خطا در بارگذاری تصویر',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () {
                                              // تلاش مجدد برای بارگذاری تصویر
                                              setState(() {
                                                _imageKeys[index] = UniqueKey();
                                              });
                                              _validateFiles();
                                            },
                                            child: const Text('تلاش مجدد'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Thumbnail strip (if multiple images)
                      if (widget.files.length > 1)
                        Container(
                          height: 80,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: widget.files.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _currentIndex;
                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: accent,
                                            width: 2,
                                          )
                                        : Border.all(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey[300]!,
                                            width: 1,
                                          ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: FutureBuilder<bool>(
                                      future: widget.files[index].exists(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Container(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              ),
                                            ),
                                          );
                                        }

                                        if (snapshot.hasData &&
                                            snapshot.data == true) {
                                          return Image.file(
                                            widget.files[index],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              debugPrint(
                                                  '❌ Thumbnail error for index $index: $error');
                                              return Container(
                                                color: isDark
                                                    ? Colors.grey[800]
                                                    : Colors.grey[200],
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: isDark
                                                      ? Colors.grey[600]
                                                      : Colors.grey[400],
                                                  size: 20,
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          return Container(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: Icon(
                                              Icons.broken_image,
                                              color: isDark
                                                  ? Colors.grey[600]
                                                  : Colors.grey[400],
                                              size: 20,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Telegram-style caption input with send button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Caption text field (like chat input)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextField(
                                  controller: _captionController,
                                  minLines: 1,
                                  maxLines: 4,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'پیام...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Send button (like chat send button)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _sendImages,
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Removed large bottom send button in favor of header check action
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
