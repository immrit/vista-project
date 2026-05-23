import '../../../security/logging_utility.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../provider/ProfileImageUploadService.dart';
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
  bool _isLoading = false;

  // تاریخ تولد
  String? _birthDate;
  DateTime? _selectedDate;

  File? _imageFile;
  final picker = ImagePicker();

  // Add validation pattern constant
  final _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

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
        if (data['birth_date'] != null) {
          _birthDate = data['birth_date'];
          try {
            final dateParts = _birthDate!.split('/');
            if (dateParts.length == 3) {
              final year = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final day = int.parse(dateParts[2]);
              final jalali = Jalali(year, month, day);
              _selectedDate = jalali.toDateTime();
            }
          } catch (e) {
            logInfo('خطا در تبدیل تاریخ: $e');
          }
        }
      });
    }
  }

  // نمایش انتخابگر تاریخ شمسی
  void _showDatePicker() async {
    final now = Jalali.now();

    showDialog(
      context: context,
      builder: (context) {
        int selectedYear = _selectedDate != null
            ? Jalali.fromDateTime(_selectedDate!).year
            : now.year - 20;
        int selectedMonth = _selectedDate != null
            ? Jalali.fromDateTime(_selectedDate!).month
            : now.month;
        int selectedDay = _selectedDate != null
            ? Jalali.fromDateTime(_selectedDate!).day
            : now.day;

        return AlertDialog(
          title: const Text('تاریخ تولد خود را انتخاب کنید',
              textAlign: TextAlign.right),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 250,
                child: Column(
                  children: [
                    // سال
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('سال:'),
                              DropdownButton<int>(
                                isExpanded: true,
                                value: selectedYear,
                                items: List.generate(100, (index) {
                                  final year = now.year - index;
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year.toString()),
                                  );
                                }),
                                onChanged: (int? value) {
                                  setState(() => selectedYear = value!);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ماه و روز
                    Row(
                      children: [
                        // روز
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('روز:'),
                              DropdownButton<int>(
                                isExpanded: true,
                                value: selectedDay,
                                items: List.generate(
                                  Jalali(selectedYear, selectedMonth, 1)
                                      .monthLength,
                                  (index) => DropdownMenuItem(
                                    value: index + 1,
                                    child: Text((index + 1).toString()),
                                  ),
                                ),
                                onChanged: (int? value) {
                                  setState(() => selectedDay = value!);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ماه
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('ماه:'),
                              DropdownButton<int>(
                                isExpanded: true,
                                value: selectedMonth,
                                items: List.generate(12, (index) {
                                  final monthNames = [
                                    'فروردین',
                                    'اردیبهشت',
                                    'خرداد',
                                    'تیر',
                                    'مرداد',
                                    'شهریور',
                                    'مهر',
                                    'آبان',
                                    'آذر',
                                    'دی',
                                    'بهمن',
                                    'اسفند'
                                  ];
                                  return DropdownMenuItem(
                                    value: index + 1,
                                    child: Text(monthNames[index]),
                                  );
                                }),
                                onChanged: (int? value) {
                                  setState(() {
                                    selectedMonth = value!;
                                    // تنظیم مجدد روز اگر روز فعلی از طول ماه جدید بیشتر باشد
                                    final monthLength =
                                        Jalali(selectedYear, selectedMonth, 1)
                                            .monthLength;
                                    if (selectedDay > monthLength) {
                                      selectedDay = monthLength;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 25, 25, 25),
              ),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () {
                final selectedJalali =
                    Jalali(selectedYear, selectedMonth, selectedDay);
                setState(() {
                  _selectedDate = selectedJalali.toDateTime();
                  _birthDate =
                      '${selectedJalali.year}/${selectedJalali.month}/${selectedJalali.day}';
                });
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 25, 25, 25),
              ),
              child: const Text('تایید'),
            ),
          ],
        );
      },
    );
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
        'phone_number': normalizedPhone,
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
                  if (debugCode != null && debugCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('کد تست: $debugCode'),
                  ],
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
            if (_birthDate == null && data['birth_date'] != null) {
              _birthDate = data['birth_date'];
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
                              ? _formatBirthDate(_birthDate!)
                              : 'انتخاب کنید',
                          icon: Icons.cake_outlined,
                          onTap: _showDatePicker,
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

  // تبدیل فرمت تاریخ به نمایش دوستانه
  // تاریخ تولد را با فرمت خواناتر نمایش می‌دهد
  String _formatBirthDate(String date) {
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        final monthNames = [
          'فروردین',
          'اردیبهشت',
          'خرداد',
          'تیر',
          'مرداد',
          'شهریور',
          'مهر',
          'آبان',
          'آذر',
          'دی',
          'بهمن',
          'اسفند'
        ];
        return '${parts[2]} ${monthNames[int.parse(parts[1]) - 1]} ${parts[0]}';
      }
    } catch (e) {
      logInfo('خطا در فرمت تاریخ: $e');
    }
    return date;
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
