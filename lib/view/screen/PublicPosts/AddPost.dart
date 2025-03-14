import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../main.dart';
import '../../../provider/PostImageUploadService.dart';
import '../../../provider/provider.dart';
import '../../../util/widgets.dart';

class AddPublicPostScreen extends ConsumerStatefulWidget {
  const AddPublicPostScreen({super.key});

  @override
  _AddPublicPostScreenState createState() => _AddPublicPostScreenState();
}

class _AddPublicPostScreenState extends ConsumerState<AddPublicPostScreen> {
  final TextEditingController contentController = TextEditingController();
  bool isLoading = false;
  final int maxLength = 300; // حداکثر تعداد کاراکتر
  int remainingChars = 300;
  static const int maxCharLength = 300;
  File? _selectedImage;
  File? _selectedMusic;
  String? _musicFileName;

  @override
  void initState() {
    super.initState();
    // اضافه کردن لیسنر برای کنترل تعداد کاراکترها
    contentController.addListener(() {
      setState(() {
        remainingChars = maxCharLength - contentController.text.length;
      });
    });
  }

  // تابع جدید برای تعیین رنگ بر اساس تعداد کاراکترها
  Color _getProgressColor() {
    if (contentController.text.length > maxCharLength) {
      return Colors.red;
    }
    return ref.watch(themeProvider).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  // تابع جدید برای محاسبه پیشرفت
  double _calculateProgress() {
    return (contentController.text.length / maxCharLength).clamp(0.0, 1.0);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
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

  // Add new method for picking music file
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('متن پست نمی‌تواند بیشتر از ۳۰۰ کاراکتر باشد')),
      );
      return;
    }

    if (content.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً محتوا جهت ارسال پست را وارد کنید')),
      );
      return;
    }

    if (content.isNotEmpty && content.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('متن پست باید حداقل ۳ حرف داشته باشد')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageUrl;
      String? musicUrl;

      // اگر تصویری انتخاب شده باشد، ابتدا آن را آپلود می‌کنیم
      if (_selectedImage != null) {
        imageUrl =
            await PostImageUploadService.uploadPostImage(_selectedImage!);
      }

      // Upload music if selected
      if (_selectedMusic != null) {
        musicUrl =
            await PostImageUploadService.uploadMusicFile(_selectedMusic!);
      }

      // ایجاد پست با تصویر (در صورت وجود)
      final postData = {
        'user_id': supabase.auth.currentUser!.id,
        'content': contentController.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
        if (musicUrl != null) 'music_url': musicUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('posts').insert(postData).then((value) {
        ref.refresh(postsProvider);
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پست با موفقیت منتشر شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'خطا در ارسال پست';
        if (e.toString().contains('storage')) {
          errorMessage = 'خطا در آپلود فایل موزیک. لطفاً دوباره تلاش کنید';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(themeProvider);

    return SafeArea(
      top: false,
      child: Scaffold(
          appBar: AppBar(
            title: const Text('پست جدید'),
            centerTitle: true,
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    addNotesTextFiels(
                      'هرچه میخواهی بگو...',
                      1,
                      contentController,
                      18,
                      FontWeight.normal,
                      1000,
                      // maxLength: maxLength,
                    ),
                    const SizedBox(height: 16),
                    // پیش‌نمایش عکس
                    if (_selectedImage != null)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentColor.brightness == Brightness.dark
                                ? Colors.white24
                                : Colors.black12,
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                            // دکمه حذف عکس روی پیش‌نمایش
                            Material(
                              color: Colors.black.withOpacity(0.5),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Add music picker button
                    if (_selectedMusic == null)
                      ElevatedButton.icon(
                        onPressed: _pickMusicFile,
                        icon: const Icon(Icons.music_note),
                        label: const Text('افزودن موزیک'),
                      )
                    else
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(_musicFileName ?? 'فایل موزیک'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedMusic = null;
                                _musicFileName = null;
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 10,
              right: 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // نمایش تعداد کاراکترهای باقیمانده
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              value: _calculateProgress(),
                              color: currentColor.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              backgroundColor:
                                  currentColor.brightness == Brightness.dark
                                      ? Colors.black12
                                      : Colors.black26,
                              strokeWidth: 5.0,
                            ),
                          ),
                          Text(
                            '$remainingChars',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: currentColor.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // دکمه افزودن عکس
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentColor.brightness == Brightness.dark
                            ? Colors.white12
                            : Colors.black12,
                      ),
                      child: IconButton(
                        onPressed: _pickImage,
                        icon: Icon(
                          Icons.add_photo_alternate,
                          size: 24,
                          color: currentColor.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                // دکمه افزودن پست
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _addPost,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(10, 50),
                      backgroundColor:
                          currentColor.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: currentColor.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          )
                        : Text(
                            'افزودن پست',
                            style: TextStyle(
                              color: currentColor.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Vazir',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
