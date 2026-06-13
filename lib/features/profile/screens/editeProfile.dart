import '../../../security/logging_utility.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../provider/locale_provider.dart';
import '../../../provider/ProfileImageUploadService.dart';
import '../../../utils/birth_date_picker.dart';
import '../../../services/user_friendly_error_handler.dart';
import '../../../core/security/input_policy.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/profile_repository.dart';
import '../providers/profile_controller.dart';

class EditProfile extends ConsumerStatefulWidget {
  const EditProfile({super.key});

  @override
  ConsumerState<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfile> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  bool _isLoading = false;

  // تاریخ تولد
  String? _birthDate;
  DateTime? _selectedDate;
  String? _gender;
  String? _maritalStatus;
  bool _showEmail = false;
  bool _showBirthDate = false;
  bool _showGender = false;
  bool _showMaritalStatus = false;
  bool _profileOptionsLoaded = false;

  File? _imageFile;
  final picker = ImagePicker();

  // Add validation pattern constant
  final _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  bool _boolValue(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  String? _allowedValue(dynamic value, Set<String> allowed) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || !allowed.contains(text)) {
      return null;
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() async {
    final data = await ref.read(profileProvider.future);
    if (data != null) {
      setState(() {
        emailController.text = data['email'] ?? "";
        _phoneController.text = data['phone_number'] ?? "";
        websiteController.text = data['website_url'] ?? "";
        if (data['birth_date'] != null) {
          _birthDate = data['birth_date']?.toString();
          _selectedDate = parseBirthDate(_birthDate);
        }
        _gender = _allowedValue(
          data['gender'],
          {'male', 'female', 'prefer_not_to_say'},
        );
        _maritalStatus = _allowedValue(
          data['marital_status'],
          {'single', 'married', 'prefer_not_to_say'},
        );
        _showEmail = _boolValue(data['show_email']);
        _showBirthDate = _boolValue(data['show_birth_date']);
        _showGender = _boolValue(data['show_gender']);
        _showMaritalStatus = _boolValue(data['show_marital_status']);
        _profileOptionsLoaded = true;
      });
    }
  }

  Future<void> _showDatePicker() async {
    final locale = resolveBirthDateLocale(context, ref.read(localeProvider));
    final picked = await pickBirthDate(
      context,
      locale: locale,
      initialDate: _selectedDate,
      helpText: isPersianLocale(locale)
          ? 'تاریخ تولد خود را انتخاب کنید'
          : 'Select your date of birth',
      confirmText: isPersianLocale(locale) ? 'تایید' : 'OK',
      cancelText: isPersianLocale(locale) ? 'لغو' : 'Cancel',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _birthDate = formatBirthDateForStorage(picked);
    });
  }

  // متد برای نمایش دیالوگ
  void _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.add_a_photo,
                    color: const Color.fromARGB(255, 25, 25, 25),
                  ),
                  title: const Text('افزودن تصویر جدید'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: const Color(0xFFE53935),
                  ),
                  title: const Text('حذف عکس پروفایل'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _deleteImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteImage() async {
    try {
      setState(() => _isLoading = true);
      final data = await ref.read(profileProvider.future);
      final userId = (data?['id'] ?? data?['user_id'] ?? '').toString();
      if (userId.isEmpty) {
        throw Exception('شناسه کاربر پیدا نشد');
      }

      // دریافت URL عکس پروفایل فعلی از پروفایل کاربر
      final profileResponse = data ?? <String, dynamic>{};

      final previousAvatarUrl = profileResponse['avatar_url'];

      // حذف عکس از آروان کلود اگر وجود داشته باشد
      if (previousAvatarUrl != null && previousAvatarUrl.isNotEmpty) {
        final success =
            await ProfileImageUploadService.deleteImage(previousAvatarUrl);
        if (!success) {
          throw Exception('خطا در حذف فایل از آروان کلود');
        }

        // به‌روزرسانی URL تصویر پروفایل به null
        await ProfileRepository().updateProfile(userId, {'avatar_url': ''});
        ref.invalidate(profileProvider);

        // نمایش پیام موفقیت
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('عکس پروفایل حذف شد')),
          );
        }

        // به‌روزرسانی UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف تصویر: $e')),
        );
      }
      logInfo('Error deleting image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // نسخه وب: فقط با bytes کار می‌کنیم و File استفاده نمی‌شود
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageFile =
                null; // برای نمایش تصویر باید راهکار جداگانه‌ای برای وب پیاده شود
          });
          await _uploadImageWeb(bytes, pickedFile.name);
        } else {
          // نسخه موبایل
          final File imageFile = File(pickedFile.path);
          if (await imageFile.exists()) {
            setState(() {
              _imageFile = imageFile;
            });
            await _uploadImage(imageFile);
          } else {
            throw Exception('فایل انتخاب شده در مسیر مورد نظر یافت نشد');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب تصویر: $e')),
        );
      }
      logInfo('Error picking image: $e');
    }
  }

  // متد مخصوص آپلود تصویر در وب
  Future<void> _uploadImageWeb(Uint8List bytes, String fileName) async {
    try {
      setState(() => _isLoading = true);

      // بررسی سایز فایل (محدودیت 5 مگابایت)
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('حجم فایل بیشتر از حد مجاز است');
      }

      // آپلود تصویر به ArvanCloud
      final imageUrl =
          await ProfileImageUploadService.uploadImageWeb(bytes, fileName);

      if (imageUrl == null) {
        throw Exception('آپلود تصویر به ArvanCloud شکست خورد');
      }

      // به‌روزرسانی URL تصویر در پروفایل کاربر در بک‌اند Go
      final data = await ref.read(profileProvider.future);
      final user = _profileEditUserFromData(data);

      if (user == null) {
        throw Exception('کاربر وارد نشده است');
      }

      await ProfileRepository()
          .updateProfile(user.id, {'avatar_url': imageUrl});
      ref.invalidate(profileProvider);

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
      logInfo('Error uploading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      setState(() => _isLoading = true);
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

      // به‌روزرسانی URL تصویر در پروفایل کاربر در بک‌اند Go
      final data = await ref.read(profileProvider.future);
      final user = _profileEditUserFromData(data);

      if (user == null) {
        throw Exception('کاربر وارد نشده است');
      }

      await ProfileRepository()
          .updateProfile(user.id, {'avatar_url': imageUrl});
      ref.invalidate(profileProvider);

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
      logInfo('Error uploading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final username =
        normalizeDigits(_usernameController.text).trim().toLowerCase();
    final email = normalizeDigits(emailController.text).trim().toLowerCase();
    final rawPhone = _phoneController.text.trim();
    final normalizedPhone = normalizePhone09(rawPhone);

    try {
      final usernameValidation = validateUsername(username);
      if (!usernameValidation.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(usernameValidation.message)),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لطفاً یک ایمیل معتبر وارد کنید')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (fullNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('نام و نام خانوادگی نمی‌تواند خالی باشد')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_birthDate == null || _birthDate!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تاریخ تولد را وارد کنید')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_gender == null || _gender!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جنسیت را انتخاب کنید')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (rawPhone.isEmpty || normalizedPhone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('شماره موبایل باید با فرمت 09 و 11 رقم باشد')),
        );
        setState(() => _isLoading = false);
        return;
      }

      _usernameController.text = username;
      emailController.text = email;
      _phoneController.text = normalizedPhone;

      final data = await ref.read(profileProvider.future);
      final String currentPhone =
          normalizePhone09((data?['phone_number'] ?? '').toString()) ?? '';
      final bool phoneChanged = normalizedPhone != currentPhone;

      if (phoneChanged) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('برای تغییر شماره موبایل، فعلاً با همان شماره وارد شوید'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // به‌روزرسانی پروفایل
      final updates = sanitizeProfilePayload({
        'username': username,
        'full_name': fullNameController.text.trim(),
        if (email.isNotEmpty) 'email': email,
        'bio': bioController.text.trim(),
        'birth_date': _birthDate,
        'gender': _gender,
        if (_maritalStatus != null) 'marital_status': _maritalStatus,
        'show_email': _showEmail,
        'show_birth_date': _showBirthDate,
        'show_gender': _showGender,
        'show_marital_status': _showMaritalStatus,
        'phone_number': normalizedPhone,
        'website_url': websiteController.text.trim(),
      });

      final userId = (data?['id'] ?? data?['user_id'] ?? '').toString();
      final updated = await ProfileRepository().updateProfile(userId, updates);

      if (!mounted) return;
      ref.invalidate(profileProvider);

      final emailVerificationMessage =
          await _sendEmailVerificationIfNeeded(email, updated);
      if (!mounted) return;

      String successMessage = 'پروفایل با موفقیت به‌روزرسانی شد';
      if (emailVerificationMessage != null) {
        successMessage += '. $emailVerificationMessage';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      if (updated['profile_completed'] == true) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        Navigator.of(context).pop();
      }
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

  Future<String?> _sendEmailVerificationIfNeeded(
    String email,
    Map<String, dynamic> updated,
  ) async {
    if (email.isEmpty || updated['email_verified_at'] != null) {
      return null;
    }

    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      final response = await AuthRepository().sendEmailVerification(
        accessToken: accessToken,
        email: email,
      );
      if (!response.success || response.sessionId.isEmpty) {
        return 'ایمیل ذخیره شد';
      }

      final verified = await _showEmailVerificationDialog(
        accessToken: accessToken,
        sessionId: response.sessionId,
        debugCode: response.debugCode,
      );
      if (verified == true) {
        ref.invalidate(profileProvider);
        return 'ایمیل تأیید شد';
      }
      return 'کد تأیید ایمیل ارسال شد';
    } catch (e) {
      final message = e.toString();
      if (message.contains('پیکربندی') ||
          message.contains('EMAIL_NOT_CONFIGURED') ||
          message.contains('در دسترس نیست')) {
        return 'ایمیل ذخیره شد؛ ارسال کد بعد از تنظیم SMTP فعال می‌شود';
      }
      return 'ایمیل ذخیره شد؛ ارسال کد تأیید ناموفق بود';
    }
  }

  Future<bool?> _showEmailVerificationDialog({
    required String accessToken,
    required String sessionId,
    String? debugCode,
  }) {
    final codeController = TextEditingController(text: '');
    bool isLoading = false;
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تأیید ایمیل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('کد ارسال شده به ایمیل را وارد کنید.'),
                  // debugCode display is completely hidden per user request.
                  // if (debugCode != null && debugCode.isNotEmpty) ...[
                  //   const SizedBox(height: 8),
                  //   Text('کد تست: $debugCode'),
                  // ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'کد تأیید',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('بعداً'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final code =
                              normalizeDigits(codeController.text).trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              errorText = 'کد را وارد کنید';
                            });
                            return;
                          }
                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });
                          try {
                            await AuthRepository().verifyEmail(
                              accessToken: accessToken,
                              sessionId: sessionId,
                              code: code,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorText = e.toString();
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final getProfileData = ref.watch(profileProvider);
    // Watch locale so that a language change triggers a rebuild
    // and the birth date display format updates in real-time.
    final currentLocale = ref.watch(localeProvider);
    final locale = resolveBirthDateLocale(context, currentLocale);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ویرایش پروفایل'),
          centerTitle: true,
        ),
        body: getProfileData.when(
          data: (data) {
            final avatarUrl = data!['avatar_url'];
            if (_usernameController.text.isEmpty) {
              _usernameController.text = data['username'] ?? "";
            }
            if (fullNameController.text.isEmpty) {
              fullNameController.text = data['full_name'] ?? "";
            }
            if (bioController.text.isEmpty) {
              bioController.text = data['bio'] ?? "";
            }
            if (emailController.text.isEmpty) {
              emailController.text = data['email'] ?? "";
            }
            if (_phoneController.text.isEmpty) {
              _phoneController.text = data['phone_number'] ?? "";
            }
            if (_birthDate == null && data['birth_date'] != null) {
              _birthDate = data['birth_date']?.toString();
              _selectedDate = parseBirthDate(_birthDate);
            }
            if (!_profileOptionsLoaded) {
              _gender = _allowedValue(
                data['gender'],
                {'male', 'female', 'prefer_not_to_say'},
              );
              _maritalStatus = _allowedValue(
                data['marital_status'],
                {'single', 'married', 'prefer_not_to_say'},
              );
              _showEmail = _boolValue(data['show_email']);
              _showBirthDate = _boolValue(data['show_birth_date']);
              _showGender = _boolValue(data['show_gender']);
              _showMaritalStatus = _boolValue(data['show_marital_status']);
              _profileOptionsLoaded = true;
            }

            return _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color.fromARGB(
                                            255, 25, 25, 25),
                                        width: 2,
                                      ),
                                      image: DecorationImage(
                                        image: _imageFile != null
                                            ? FileImage(_imageFile!)
                                            : (avatarUrl != null &&
                                                    avatarUrl.isNotEmpty)
                                                ? NetworkImage(avatarUrl)
                                                : const AssetImage(
                                                    'lib/utils/images/default-avatar.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 25, 25, 25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.camera_alt),
                                        color: Colors.white,
                                        onPressed: _showImageOptions,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'تصویر پروفایل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // فیلدهای ورودی با طراحی جدید
                        _buildProfileField(
                          title: 'نام کاربری',
                          icon: Icons.person_outline,
                          controller: _usernameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'نام کاربری نمی‌تواند خالی باشد';
                            }
                            final result = validateUsername(
                                normalizeDigits(value).trim().toLowerCase());
                            return result.isValid ? null : result.message;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildProfileField(
                          title: 'نام و نام خانوادگی',
                          icon: Icons.badge_outlined,
                          controller: fullNameController,
                        ),
                        const SizedBox(height: 16),
                        _buildProfileField(
                          title: 'ایمیل',
                          icon: Icons.email_outlined,
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final normalizedEmail = value?.trim() ?? '';
                            if (normalizedEmail.isEmpty) {
                              return null;
                            }
                            if (value == null || value.isEmpty) {
                              return 'ایمیل نمی‌تواند خالی باشد';
                            }
                            if (!_emailPattern.hasMatch(normalizedEmail)) {
                              return 'لطفاً یک ایمیل معتبر وارد کنید';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildProfileField(
                          title: 'شماره تلفن',
                          icon: Icons.phone_android_outlined,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(
                          title: 'تاریخ تولد',
                          value: _birthDate != null
                              ? _formatBirthDate(_birthDate!, locale)
                              : 'انتخاب کنید',
                          icon: Icons.cake_outlined,
                          onTap: _showDatePicker,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          title: 'جنسیت',
                          icon: Icons.person_outline,
                          value: _gender,
                          items: const [
                            DropdownMenuItem(
                              value: 'male',
                              child: Text('مرد'),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text('زن'),
                            ),
                            DropdownMenuItem(
                              value: 'prefer_not_to_say',
                              child: Text('ترجیح می‌دهم نگویم'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _gender = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          title: 'وضعیت تاهل',
                          icon: Icons.favorite_outline,
                          value: _maritalStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'single',
                              child: Text('مجرد'),
                            ),
                            DropdownMenuItem(
                              value: 'married',
                              child: Text('متاهل'),
                            ),
                            DropdownMenuItem(
                              value: 'prefer_not_to_say',
                              child: Text('ترجیح می‌دهم نگویم'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _maritalStatus = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildVisibilitySection(),
                        const SizedBox(height: 16),
                        _buildProfileField(
                          title: 'لینک وب‌سایت',
                          icon: Icons.link,
                          controller: websiteController,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        _buildProfileField(
                          title: 'درباره من',
                          icon: Icons.info_outline,
                          controller: bioController,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? const Color.fromARGB(255, 241, 241, 241)
                                  : const Color.fromARGB(255, 60, 60, 60),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(
                                    color: isDarkMode
                                        ? Colors.black
                                        : Colors.white)
                                : Text('ذخیره تغییرات',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  UserFriendlyErrorHandler.getFriendlyMessage(error,
                      context: 'profile_loading'),
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(profileProvider),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatBirthDate(String date, Locale locale) {
    final parsed = parseBirthDate(date);
    if (parsed == null) return date;
    return formatBirthDateForDisplay(parsed, locale);
  }

  // ساخت فیلد ورودی پروفایل با استایل یکسان
  Widget _buildProfileField({
    required String title,
    required IconData icon,
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: title,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          prefixIcon:
              Icon(icon, color: isDarkMode ? Colors.white : Colors.black),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String title,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: title,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          prefixIcon:
              Icon(icon, color: isDarkMode ? Colors.white : Colors.black),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
        iconEnabledColor: isDarkMode ? Colors.white70 : Colors.black54,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVisibilitySection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subColor = isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'نمایش در جزییات اکانت',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildVisibilitySwitch(
            title: 'ایمیل',
            subtitle: 'نمایش ایمیل در صفحه جزییات اکانت',
            value: _showEmail,
            onChanged: (value) => setState(() => _showEmail = value),
            textColor: textColor,
            subColor: subColor,
          ),
          Divider(height: 1, indent: 56, color: dividerColor),
          _buildVisibilitySwitch(
            title: 'تاریخ تولد',
            subtitle: 'نمایش تاریخ تولد در صفحه جزییات اکانت',
            value: _showBirthDate,
            onChanged: (value) => setState(() => _showBirthDate = value),
            textColor: textColor,
            subColor: subColor,
          ),
          Divider(height: 1, indent: 56, color: dividerColor),
          _buildVisibilitySwitch(
            title: 'جنسیت',
            subtitle: 'نمایش جنسیت در صفحه جزییات اکانت',
            value: _showGender,
            onChanged: (value) => setState(() => _showGender = value),
            textColor: textColor,
            subColor: subColor,
          ),
          Divider(height: 1, indent: 56, color: dividerColor),
          _buildVisibilitySwitch(
            title: 'وضعیت تاهل',
            subtitle: 'نمایش وضعیت تاهل در صفحه جزییات اکانت',
            value: _showMaritalStatus,
            onChanged: (value) => setState(() => _showMaritalStatus = value),
            textColor: textColor,
            subColor: subColor,
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color subColor,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsetsDirectional.only(start: 56, end: 12),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subColor, fontSize: 12),
      ),
    );
  }

  // ساخت فیلد تاریخ با استایل یکسان
  Widget _buildDateField({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDarkMode ? Colors.white : Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

_ProfileEditUser? _profileEditUserFromData(Map<String, dynamic>? data) {
  final userId = (data?['id'] ?? data?['user_id'] ?? '').toString();
  if (userId.isEmpty) return null;
  return _ProfileEditUser(userId);
}

class _ProfileEditUser {
  final String id;
  const _ProfileEditUser(this.id);
}
