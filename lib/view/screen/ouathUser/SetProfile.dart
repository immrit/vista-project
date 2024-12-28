import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../provider/ProfileImageUploadService.dart'; // سرویس مربوط به آپلود تصویر در ArvanCloud
import '/util/widgets.dart';
import '/view/screen/homeScreen.dart';
import '../../../main.dart';

final loadingProvider = StateProvider<bool>((ref) => false);

class SetProfileData extends ConsumerStatefulWidget {
  const SetProfileData({super.key});

  @override
  _SetProfileDataState createState() => _SetProfileDataState();
}

class _SetProfileDataState extends ConsumerState<SetProfileData> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  File? _imageFile;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // _getProfile();
  }

  // Future<void> _getProfile() async {
  //   ref.read(loadingProvider.notifier).state = true;
  //   try {
  //     final userId = supabase.auth.currentSession?.user.id;
  //     if (userId == null) return;

  //     final data =
  //         await supabase.from('profiles').select().eq('id', userId).single();

  //     if (!mounted) return;

  //     _usernameController.text = (data['username'] ?? '') as String;
  //     fullNameController.text = (data['full_name'] ?? '') as String;
  //     bioController.text = (data['bio'] ?? '') as String;
  //   } catch (error) {
  //     if (mounted) {
  //       context.showSnackBar('خطا در بازیابی پروفایل، لطفاً دوباره تلاش کنید.',
  //           isError: true);
  //     }
  //   } finally {
  //     if (mounted) {
  //       ref.read(loadingProvider.notifier).state = false;
  //     }
  //   }
  // }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);

        setState(() {
          _imageFile = imageFile;
        });

        await _uploadImage(imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب تصویر: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('فایل تصویر وجود ندارد');
      }

      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('حجم فایل بیشتر از حد مجاز است');
      }

      // استفاده از سرویس آپلود برای ArvanCloud
      final imageUrl = await ProfileImageUploadService.uploadImage(imageFile);

      if (imageUrl == null) {
        throw Exception('آپلود تصویر به ArvanCloud شکست خورد');
      }

      final userId = supabase.auth.currentSession?.user.id;
      if (userId == null) return;

      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر با موفقیت آپلود شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آپلود تصویر: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    ref.read(loadingProvider.notifier).state = true;

    final userName = _usernameController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null || userName.isEmpty) return;

    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(userName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً فقط از حروف انگلیسی استفاده کنید')),
      );
      ref.read(loadingProvider.notifier).state = false;
      return;
    }

    final updates = {
      'id': user.id,
      'username': userName,
      'full_name': fullNameController.text,
      'bio': bioController.text,
      'updated_at': DateTime.now().toIso8601String(),
      'email': user.email,
    };

    try {
      await supabase.from('profiles').upsert(updates);
      if (mounted) {
        context.showSnackBar('پروفایل با موفقیت به‌روزرسانی شد!',
            isError: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        String errorMessage = 'خطا در بروزرسانی پروفایل: $error';
        if (error
            .toString()
            .contains('duplicate key value violates unique constraint')) {
          errorMessage = 'نام کاربری تکراری است، لطفاً نام دیگری انتخاب کنید.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        ref.read(loadingProvider.notifier).state = false;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    fullNameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(loadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نام کاربری خود را مشخص کنید'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey.shade900,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: .16.sh,
              height: .16.sh,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: _imageFile != null
                      ? FileImage(_imageFile!)
                      : const AssetImage('lib/util/images/default-avatar.jpg')
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          customTextField(
            'نام کاربری',
            _usernameController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا مقادیر را وارد نمایید';
              }
              if (!RegExp(r'^[a-z._-]{5,}$').hasMatch(value)) {
                return 'نام کاربری باید حداقل ۵ حرف داشته باشد و فقط از حروف کوچک، _، - و . استفاده کنید';
              }
              return null;
            },
            false,
            TextInputType.text,
          ),
          SizedBox(height: 20.h),
          customTextField(
            'نام',
            fullNameController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا مقادیر را وارد نمایید';
              }
              return null;
            },
            false,
            TextInputType.text,
          ),
          SizedBox(height: 20.h),
          customTextField(
            'درباره شما',
            bioController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا مقادیر را وارد نمایید';
              }
              return null;
            },
            false,
            TextInputType.text,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          right: 10,
          left: 10,
        ),
        child: customButton(
          loading ? null : _updateProfile,
          loading ? 'در حال ذخیره‌سازی...' : 'ذخیره',
          ref,
        ),
      ),
    );
  }
}
