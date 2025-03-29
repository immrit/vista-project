import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../util/widgets.dart';
import '../../../provider/provider.dart';
import '../../../provider/ProfileImageUploadService.dart';

class EditProfile extends ConsumerStatefulWidget {
  const EditProfile({super.key});

  @override
  ConsumerState<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfile> {
  final TextEditingController _usernameController = TextEditingController();
  TextEditingController fullNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  bool _isLoading = false;

  File? _imageFile;
  final picker = ImagePicker();

  // Add validation pattern constant
  final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{4,}$');

  // متد برای نمایش دیالوگ
  void _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_a_photo),
                title: const Text('افزودن تصویر جدید'),
                onTap: () async {
                  Navigator.of(context).pop(); // بستن باتم شیت
                  await _pickImage(); // انتخاب تصویر جدید
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('حذف عکس پروفایل'),
                onTap: () async {
                  Navigator.of(context).pop(); // بستن باتم شیت
                  await _deleteImage(); // حذف تصویر پروفایل
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteImage() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // دریافت URL عکس پروفایل فعلی از پروفایل کاربر
      final profileResponse = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .single();

      final previousAvatarUrl = profileResponse['avatar_url'];

      // حذف عکس از آروان کلود اگر وجود داشته باشد
      if (previousAvatarUrl != null && previousAvatarUrl.isNotEmpty) {
        final success =
            await ProfileImageUploadService.deleteImage(previousAvatarUrl);
        if (!success) {
          throw Exception('خطا در حذف فایل از آروان کلود');
        }

        // به‌روزرسانی URL تصویر پروفایل به null
        await supabase
            .from('profiles')
            .update({'avatar_url': null}).eq('id', userId);

        // نمایش پیام موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عکس پروفایل حذف شد')),
        );

        // به‌روزرسانی UI
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف تصویر: $e')),
      );
      print('Error deleting image: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // محدود کردن سایز تصویر
        maxHeight: 1024,
        imageQuality: 85, // کاهش کیفیت برای کاهش حجم
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // بررسی وجود فایل
        if (await imageFile.exists()) {
          setState(() {
            _imageFile = imageFile;
          });
          await _uploadImage(imageFile);
        } else {
          throw Exception('فایل انتخاب شده در مسیر مورد نظر یافت نشد');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب تصویر: $e')),
        );
      }
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('فایل تصویر وجود ندارد');
      }

      // بررسی سایز فایل (محدودیت 5 مگابایت)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('حجم فایل بیشتر از حد مجاز است');
      }

      // آپلود تصویر به ArvanCloud
      final imageUrl = await ProfileImageUploadService.uploadImage(imageFile);

      if (imageUrl == null) {
        throw Exception('آپلود تصویر به ArvanCloud شکست خورد');
      }

      // به‌روزرسانی URL تصویر در پروفایل کاربر در Supabase
      final supabase = ref.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('کاربر وارد نشده است');
      }

      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر با موفقیت آپلود شد')),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آپلود تصویر: $e')),
        );
      }
      print('Error uploading image: $e');
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final username = _usernameController.text.trim();

    // تغییر پیغام خطا برای شامل شدن اعداد
    if (!_usernamePattern.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'نام کاربری باید با حرف کوچک شروع شود و می‌تواند شامل حروف کوچک، اعداد و علامت‌های - . _ باشد'),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // بررسی نام کاربری تکراری
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .neq('id', supabase.auth.currentUser!.id);

      if (response.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('این نام کاربری قبلاً استفاده شده است'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // اگر نام کاربری تکراری نباشد، ادامه عملیات
      final updates = {
        'username': username,
        'full_name': fullNameController.text,
        'bio': bioController.text,
      };

      await supabase
          .from('profiles')
          .upsert(updates)
          .eq('id', supabase.auth.currentUser!.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پروفایل با موفقیت به‌روزرسانی شد')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بروزرسانی پروفایل: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final getProfileData = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش پروفایل'),
      ),
      body: ListView(
        children: [
          getProfileData.when(
            data: (data) {
              final avatarUrl = data!['avatar_url']; // دریافت URL تصویر پروفایل
              if (_usernameController.text.isEmpty) {
                _usernameController.text =
                    data['username'] ?? ""; // دریافت نام کاربری فعلی
              }
              if (fullNameController.text.isEmpty) {
                fullNameController.text = data['full_name'] ?? ""; // دریافت نام
              }
              if (bioController.text.isEmpty) {
                bioController.text = data['bio'] ?? ""; // دریافت بیو
              }

              return Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageOptions, // نمایش دیالوگ با گزینه‌ها
                        child: Container(
                          width: .16.sh,
                          height: .16.sh,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? NetworkImage(avatarUrl)
                                      : const AssetImage(
                                          'lib/view/util/images/default-avatar.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 50.h),
                      customTextField('نام کاربری', _usernameController,
                          (value) {
                        if (value == null || value.isEmpty) {
                          return 'نام کاربری نمی‌تواند خالی باشد';
                        }
                        if (value.length < 5) {
                          return 'نام کاربری باید حداقل ۵ حرف داشته باشد';
                        }
                        if (!_usernamePattern.hasMatch(value)) {
                          return 'فقط حروف کوچک انگلیسی و علامت‌های - . _ مجاز است';
                        }
                        return null;
                      }, false, TextInputType.text),
                      SizedBox(height: 20.h),
                      customTextField('نام', fullNameController, (value) {
                        if (value == null || value.isEmpty) {
                          return 'لطفا مقادیر را وارد نمایید';
                        }
                        return null;
                      }, false, TextInputType.text),
                      SizedBox(height: 20.h),
                      customTextField('درباره شما', bioController, (value) {
                        if (value == null || value.isEmpty) {
                          return 'لطفا مقادیر را وارد نمایید';
                        }
                        return null;
                      }, false, TextInputType.text)
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          right: 10,
          left: 10,
        ),
        child: customButton(() {
          final userName = _usernameController.text.trim();
          if (!RegExp(r'^[a-zA-Z]+$').hasMatch(userName)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'لطفاً فقط از حروف انگلیسی در نام کاربری استفاده کنید')),
            );
            return;
          }

          final updatedData = {
            'username': userName,
            'full_name': fullNameController.text,
            'bio': bioController.text
          };
          ref.refresh(profileProvider);
          Navigator.pushReplacementNamed(context, '/home');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اطلاعات بروزرسانی شد')),
          );
          ref.read(profileUpdateProvider(updatedData)).when(
                data: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تصویر پروفایل بروزرسانی شد')),
                  );
                  Navigator.pushReplacementNamed(context, '/home');
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) =>
                    ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('خطا در بروزرسانی تصویر پروفایل: $error')),
                ),
              );
        }, 'ذخیره', ref),
      ),
    );
  }
}
