import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  void initState() {
    super.initState();
    contentController.addListener(() {
      setState(() {
        remainingChars = maxLength - contentController.text.length;
      });
    });
  }

  double _calculateProgress() {
    return contentController.text.length / maxLength;
  }

  File? _selectedImage;

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

// تابع _addPost رو هم باید آپدیت کنیم
  Future<void> _addPost() async {
    if (contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً متن یا تصویری را وارد کنید')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageUrl;

      // اگر تصویری انتخاب شده باشد، ابتدا آن را آپلود می‌کنیم
      if (_selectedImage != null) {
        imageUrl =
            await PostImageUploadService.uploadPostImage(_selectedImage!);
      }

      // ایجاد پست با تصویر (در صورت وجود)
      final postData = {
        'user_id': supabase.auth.currentUser!.id,
        'content': contentController.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('posts').insert(postData);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پست با موفقیت منتشر شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پست: $e')),
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

    return Scaffold(
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
                    backgroundColor: currentColor.brightness == Brightness.dark
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
        ));
  }
}
