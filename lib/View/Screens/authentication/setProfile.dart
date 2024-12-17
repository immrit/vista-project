import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../../../Provider/appwriteProvider.dart';
import '../HomeScreen.dart';
import '../../utility/widgets.dart';

// وضعیت بارگذاری
final loadingProvider = StateProvider<bool>((ref) => true);

class SetProfileData extends ConsumerStatefulWidget {
  const SetProfileData({super.key});

  @override
  _SetProfileDataState createState() => _SetProfileDataState();
}

class _SetProfileDataState extends ConsumerState<SetProfileData> {
  final _usernameController = TextEditingController();
  TextEditingController fullNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  File? _imageFile;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  Future<void> _getProfile() async {
    ref.read(loadingProvider.notifier).state = true;
    try {
      final account = ref.read(accountProvider);
      final user = await account.get();

      final database = ref.read(databasesProvider);
      final profile = await database.getDocument(
        databaseId: 'vista_db',
        collectionId: '6759a45a0035156253ce',
        documentId: user.$id,
      );

      if (!mounted) return;

      _usernameController.text = profile.data['username'] ?? '';
      fullNameController.text = profile.data['full_name'] ?? '';
      bioController.text = profile.data['bio'] ?? '';
      final avatarUrl = profile.data['avatar_url'] as String?;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        _imageFile = File(avatarUrl);
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('خطا در بازیابی پروفایل، لطفاً دوباره تلاش کنید.',
            isError: true);
      }
    } finally {
      if (mounted) {
        ref.read(loadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _imageFile = File(pickedFile.path);
      await _uploadImage(_imageFile!);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      // دریافت اطلاعات حساب کاربری
      final account = ref.read(accountProvider);
      final user = await account.get();

      // آپلود تصویر به Appwrite Storage
      final storage = ref.read(storageProvider);
      final result = await storage.createFile(
        bucketId: 'avatars', // آیدی باکت ذخیره‌سازی
        fileId: 'unique()', // شناسه منحصربه‌فرد فایل
        file: InputFile.fromPath(
          path: imageFile.path, // مسیر فایل
          filename: imageFile.path.split('/').last, // نام فایل
        ),
      );

      // ساخت آدرس عمومی برای دسترسی به تصویر
      final publicUrl =
          'http://api.coffevista.ir/storage/buckets/avatars/files/${result.$id}/view';

      // به‌روزرسانی آدرس تصویر در پروفایل کاربر
      final database = ref.read(databasesProvider);
      await database.updateDocument(
        databaseId: 'vista_db', // آیدی دیتابیس
        collectionId: '6759a45a0035156253ce', // آیدی کالکشن
        documentId: user.$id, // شناسه کاربر جاری
        data: {'avatar_url': publicUrl}, // به‌روزرسانی فیلد آواتار
      );

      // نمایش پیام موفقیت‌آمیز
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر با موفقیت آپلود شد')),
        );
      }
    } catch (e) {
      // مدیریت خطا و نمایش پیام
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آپلود تصویر، دوباره تلاش کنید: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    ref.read(loadingProvider.notifier).state = true;
    final userName = _usernameController.text.trim();
    final account = ref.read(accountProvider);
    final user = await account.get();

    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(userName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً فقط از حروف انگلیسی استفاده کنید')),
      );
      ref.read(loadingProvider.notifier).state = false;
      return;
    }

    final updates = {
      'username': userName,
      'full_name': fullNameController.text,
      'bio': bioController.text,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final database = ref.read(databasesProvider);
      await database.updateDocument(
        databaseId: 'vista_db',
        collectionId: '6759a45a0035156253ce',
        documentId: user.$id,
        data: updates,
      );
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
        print(error);
        String errorMessage = 'خطا در بروزرسانی پروفایل: $error';
        if (error.toString().contains('Document already exists')) {
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
          customTextField('نام کاربری', _usernameController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا مقادیر را وارد نمایید';
            }
            if (!RegExp(r'^[a-z._-]{5,}$').hasMatch(value)) {
              return 'نام کاربری باید حداقل ۵ حرف داشته باشد و فقط از حروف کوچک، _، - و . استفاده کنید';
            }
            return null;
          }, false, TextInputType.text, maxLines: 1),
          SizedBox(height: 20.h),
          customTextField('نام', fullNameController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا مقادیر را وارد نمایید';
            }
            return null;
          }, false, TextInputType.text, maxLines: 1),
          SizedBox(height: 20.h),
          customTextField('درباره شما', bioController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا مقادیر را وارد نمایید';
            }
            return null;
          }, false, TextInputType.text, maxLines: 3)
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
