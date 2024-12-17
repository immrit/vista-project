import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../../../Provider/appwriteProvider.dart';
import '../../../Provider/publicPostProvider.dart';
import '../HomeScreen.dart';
import '../../utility/widgets.dart';

final loadingProvider = StateProvider<bool>((ref) => false);

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _imageFile;
  String? _currentAvatarUrl;
  bool _isImageDeleted = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      ref.read(loadingProvider.notifier).state = true;
      final account = ref.read(accountProvider);
      final user = await account.get();

      final database = ref.read(databasesProvider);
      final profile = await database.getDocument(
        databaseId: 'vista_db',
        collectionId: '6759a45a0035156253ce',
        documentId: user.$id,
      );

      if (!mounted) return;

      setState(() {
        _usernameController.text = profile.data['username'] ?? '';
        _fullNameController.text = profile.data['full_name'] ?? '';
        _bioController.text = profile.data['bio'] ?? '';
        _currentAvatarUrl = profile.data['avatar_url'];
      });
    } catch (error) {
      if (mounted) {
        _showErrorMessage('خطا در بازیابی اطلاعات پروفایل');
      }
    } finally {
      if (mounted) {
        ref.read(loadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('انتخاب تصویر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('دوربین'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('گالری'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isImageDeleted = false;
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _isImageDeleted = true;
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      ref.read(loadingProvider.notifier).state = true;

      final account = ref.read(accountProvider);
      final user = await account.get();

      String? avatarUrl = _currentAvatarUrl;

      if (_isImageDeleted && _currentAvatarUrl != null) {
        final deleted =
            await ImageUploadService.deleteImage(_currentAvatarUrl!);
        if (!deleted) {
          throw Exception('خطا در حذف تصویر قبلی');
        }
        avatarUrl = '';
      } else if (_imageFile != null) {
        avatarUrl = await ImageUploadService.uploadImage(_imageFile!);

        if (avatarUrl == null) {
          throw Exception('خطا در آپلود تصویر');
        }

        if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
          await ImageUploadService.deleteImage(_currentAvatarUrl!);
        }
      }

      final updates = {
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final database = ref.read(databasesProvider);
      await database.updateDocument(
        databaseId: 'vista_db',
        collectionId: '6759a45a0035156253ce',
        documentId: user.$id,
        data: updates,
      );

      if (mounted) {
        _showSuccessMessage('پروفایل با موفقیت به‌روزرسانی شد');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      _handleUpdateError(error);
    } finally {
      if (mounted) {
        ref.read(loadingProvider.notifier).state = false;
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleUpdateError(dynamic error) {
    String message = 'خطا در به‌روزرسانی پروفایل';
    if (error.toString().contains('Document already exists')) {
      message = 'این نام کاربری قبلاً انتخاب شده است';
    }
    _showErrorMessage(message);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(loadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش پروفایل'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey.shade900,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    width: .2.sh,
                    height: .2.sh,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: _getProfileImage(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade900,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                  if (_imageFile != null || _currentAvatarUrl != null)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _removeImage,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            customTextField('نام کاربری', _usernameController, (value) {
              if (value == null || value.isEmpty) {
                return 'نام کاربری الزامی است';
              }
              if (!RegExp(r'^[a-z][a-z0-9._-]{4,}$').hasMatch(value)) {
                return 'نام کاربری باید با حرف شروع شود و حداقل ۵ کاراکتر باشد';
              }
              return null;
            }, false, TextInputType.text, maxLines: 1),
            SizedBox(height: 16.h),
            customTextField('نام کامل', _fullNameController, (value) {
              if (value == null || value.isEmpty) {
                return 'نام کامل الزامی است';
              }
              return null;
            }, false, TextInputType.text, maxLines: 1),
            SizedBox(height: 16.h),
            customTextField(
              'درباره من',
              _bioController,
              null,
              false,
              TextInputType.multiline,
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          right: 16,
          left: 16,
        ),
        child: customButton(
          loading ? null : _updateProfile,
          loading ? 'در حال به‌روزرسانی...' : 'ذخیره تغییرات',
          ref,
        ),
      ),
    );
  }

  ImageProvider _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }
    if (_currentAvatarUrl != null && !_isImageDeleted) {
      return NetworkImage(_currentAvatarUrl!);
    }
    return const AssetImage('lib/util/images/default-avatar.jpg');
  }
}
