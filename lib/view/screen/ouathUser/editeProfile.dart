import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../main.dart';
import '../../../provider/provider.dart';
import '../../../provider/ProfileImageUploadService.dart';

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
  bool _isLoading = false;

  // تاریخ تولد
  String? _birthDate;
  DateTime? _selectedDate;

  File? _imageFile;
  final picker = ImagePicker();

  // Add validation pattern constant
  final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{4,}$');
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
        emailController.text = supabase.auth.currentUser?.email ?? "";
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
            print('خطا در تبدیل تاریخ: $e');
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
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
      print('Error deleting image: $e');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آپلود تصویر: $e')),
        );
      }
      print('Error uploading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final username = _usernameController.text.trim();
    final email = emailController.text.trim();

    try {
      // بررسی صحت نام کاربری
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

      // بررسی صحت ایمیل
      if (!_emailPattern.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لطفاً یک ایمیل معتبر وارد کنید')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // بررسی نام کاربری تکراری
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .neq('id', supabase.auth.currentUser!.id);

      if (response.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('این نام کاربری قبلاً استفاده شده است')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // به‌روزرسانی ایمیل کاربر اگر تغییر کرده باشد
      final currentEmail = supabase.auth.currentUser!.email;
      bool emailChangeRequested = false;

      if (currentEmail != email) {
        try {
          // استفاده از طرح URI مستقیم اپلیکیشن برای ریدایرکت
          final redirectUrl = 'vista://auth/email-change';

          print(
              'Requesting email change from $currentEmail to $email with redirectUrl: $redirectUrl');

          // درخواست تغییر ایمیل با تنظیم آدرس ریدایرکت
          final result = await supabase.auth.updateUser(
            UserAttributes(
              email: email,
              data: {
                'redirectTo': redirectUrl
              }, // استفاده از data به جای emailRedirectTo
            ),
          );

          print('Update user response: ${result.user?.email}');

          emailChangeRequested = true;

          // نمایش پیام به کاربر
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'یک ایمیل تأیید به $email ارسال شد. لطفاً ایمیل خود را بررسی کرده و روی لینک کلیک کنید.'),
                duration: Duration(seconds: 8),
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در به‌روزرسانی ایمیل: $e')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // به‌روزرسانی پروفایل
      final updates = {
        'username': username,
        'full_name': fullNameController.text,
        'bio': bioController.text,
        'birth_date': _birthDate,
      };

      await supabase
          .from('profiles')
          .update(updates)
          .eq('id', supabase.auth.currentUser!.id);

      if (!mounted) return;
      ref.refresh(profileProvider);

      String successMessage = 'پروفایل با موفقیت به‌روزرسانی شد';
      if (emailChangeRequested) {
        successMessage +=
            '. برای تکمیل تغییر ایمیل، لینک ارسال شده به ایمیل جدید را تایید کنید';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
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

  Future<bool?> _showVerificationCodeDialog(String newEmail) async {
    final TextEditingController codeController = TextEditingController();
    bool isVerifying = false;

    return showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('تایید ایمیل جدید',
                      textAlign: TextAlign.center),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'کد تایید به $newEmail ارسال شد. لطفاً کد را وارد کنید:',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: '- - - - - -',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (isVerifying)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isVerifying
                          ? null
                          : () {
                              Navigator.of(context).pop(false);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2979FF),
                      ),
                      child: const Text('انصراف'),
                    ),
                    FilledButton(
                      onPressed: isVerifying
                          ? null
                          : () async {
                              if (codeController.text.isEmpty ||
                                  codeController.text.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('لطفاً کد ۶ رقمی را وارد کنید')),
                                );
                                return;
                              }

                              setState(() => isVerifying = true);

                              try {
                                // اصلاح تابع تایید ایمیل با کد تایید
                                final response = await supabase.auth.verifyOTP(
                                  type: OtpType.recovery, // تغییر به recovery
                                  token: codeController.text,
                                  email: newEmail,
                                );

                                if (response.session != null) {
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop(true);
                                } else {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('کد وارد شده نامعتبر است')),
                                  );
                                  setState(() => isVerifying = false);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('خطا در تایید ایمیل: $e')),
                                );
                                setState(() => isVerifying = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                      ),
                      child: const Text('تایید'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false; // اگر نتیجه null باشد، مقدار false برگردانده می‌شود
  }

  Future<void> _sendConfirmationEmail(String newEmail) async {
    try {
      // درخواست تغییر ایمیل
      await supabase.auth.updateUser(
        UserAttributes(
          email: newEmail,
          // غیرفعال کردن هدایت به مسیر خارجی
        ),
      );

      // به کاربر اطلاع دهید که یک ایمیل تایید ارسال شده است
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'یک ایمیل تایید به $newEmail ارسال شد. لطفا ایمیل خود را بررسی کنید و روی لینک تایید کلیک کنید.'),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      rethrow; // انتقال خطا به بالادست
    }
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
                                                    'lib/view/util/images/default-avatar.jpg'),
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
                            if (value.length < 5) {
                              return 'نام کاربری باید حداقل ۵ حرف داشته باشد';
                            }
                            if (!_usernamePattern.hasMatch(value)) {
                              return 'فقط حروف کوچک انگلیسی، اعداد و علامت‌های - . _ مجاز است';
                            }
                            return null;
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
                            if (value == null || value.isEmpty) {
                              return 'ایمیل نمی‌تواند خالی باشد';
                            }
                            if (!_emailPattern.hasMatch(value)) {
                              return 'لطفاً یک ایمیل معتبر وارد کنید';
                            }
                            return null;
                          },
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
                          maxLines: 3,
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
                  'خطا در بارگذاری اطلاعات: $error',
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
  String _formatBirthDate(String date) {
    try {
      final dateParts = date.split('/');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);

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

        return '$day ${monthNames[month - 1]} $year';
      }
    } catch (e) {
      print('خطا در نمایش تاریخ: $e');
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
