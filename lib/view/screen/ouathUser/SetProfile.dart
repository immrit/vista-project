import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:logger/logger.dart';

import '../../../provider/ProfileImageUploadService.dart';
import '../../../provider/profile_providers.dart';
import '../homeScreen.dart';

// سیستم لاگ گذاری دقیق
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class SetProfileData extends ConsumerStatefulWidget {
  const SetProfileData({super.key});

  @override
  ConsumerState<SetProfileData> createState() => _SetProfileDataState();
}

class _SetProfileDataState extends ConsumerState<SetProfileData> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();

  File? _imageFile;
  bool _firstFetch = true;
  bool _isInitialized = false;
  bool _isLoading = true;
  Timer? _saveTimeoutTimer;
  Jalali? _selectedDate;

  // برای انیمیشن‌های صفحه
  final _animationDuration = const Duration(milliseconds: 300);

  // تنظیمات رنگ
  final Color _accentColor = const Color(0xFF4A80F0); // آبی با رنگ باکلاس
  final Color _secondaryColor = const Color(0xFFF5B461); // نارنجی طلایی

  @override
  void dispose() {
    _saveTimeoutTimer?.cancel();
    usernameController.dispose();
    fullNameController.dispose();
    bioController.dispose();
    birthDateController.dispose();
    logger.d('تمام کنترلرها و تایمرها حذف شدند');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // تاخیر در اجرای کد برای جلوگیری از خطای Riverpod
    Future.microtask(() {
      if (mounted) {
        _initializeUserData();
      }
    });
  }

  Future<void> _initializeUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      logger.d('دریافت اطلاعات برای کاربر با آیدی: ${user.id}');

      try {
        // دریافت اطلاعات پروفایل
        await ref.read(profileProvider.notifier).fetchProfile(user.id);

        if (!mounted) return;

        final state = ref.read(profileProvider);
        logger.i('اطلاعات کاربر با موفقیت دریافت شد $state');

        setState(() {
          usernameController.text = state.username ?? '';
          fullNameController.text = state.fullName ?? '';
          bioController.text = state.bio ?? '';

          // مقداردهی فیلد تاریخ تولد
          if (state.birthDate != null && state.birthDate!.isNotEmpty) {
            birthDateController.text = state.birthDate!;
            try {
              // تبدیل رشته تاریخ به آبجکت Jalali
              List<String> dateParts = state.birthDate!.split('/');
              if (dateParts.length == 3) {
                _selectedDate = Jalali(int.parse(dateParts[0]),
                    int.parse(dateParts[1]), int.parse(dateParts[2]));
              }
            } catch (e) {
              logger.e('خطا در تبدیل تاریخ تولد $e');
            }
          }

          _isInitialized = true;
          _firstFetch = false;
          _isLoading = false;
        });

        // اگر کاربر از قبل مقدار داشت، به صفحه بعد منتقل شود
        if (_isProfileComplete(state) && mounted) {
          logger.i('پروفایل کامل است، انتقال به صفحه اصلی');
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } catch (e) {
        logger.e('خطا در دریافت اطلاعات پروفایل $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _firstFetch = false;
          });
          _showSnackBar('خطا در دریافت اطلاعات پروفایل: ${e.toString()}',
              isError: true);
        }
      }
    } else {
      logger.w('کاربر لاگین نشده است');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _firstFetch = false;
        });
        _showSnackBar('خطا در دسترسی به اطلاعات کاربر', isError: true);
      }
    }
  }

  bool _isProfileComplete(ProfileState state) {
    // علاوه بر بررسی username و fullName، فیلدهای دیگر را هم بررسی کنید
    // مثلاً بررسی کنید که bio یا birthDate هم پر شده باشد
    return (state.username?.isNotEmpty ?? false) &&
        (state.fullName?.isNotEmpty ?? false) &&
        (state.bio?.isNotEmpty ?? false) && // اضافه کردن شرط bio
        (state.birthDate?.isNotEmpty ?? false); // اضافه کردن شرط birthDate
  }

  void _showSnackBar(String message,
      {bool isError = false, Duration? duration, VoidCallback? action}) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: isError
            ? Colors.redAccent.withOpacity(0.9)
            : _accentColor.withOpacity(0.9),
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        action: action != null
            ? SnackBarAction(
                label: 'تلاش مجدد',
                textColor: Colors.white,
                onPressed: action,
              )
            : null,
      ));
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxHeight: 512,
          maxWidth: 512,
          imageQuality: 85);

      if (pickedFile != null) {
        logger.d('تصویر انتخاب شد: ${pickedFile.path}');
        setState(() => _imageFile = File(pickedFile.path));

        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          _showSnackBar('در حال بارگذاری تصویر...',
              duration: const Duration(seconds: 60));

          try {
            logger.i('شروع آپلود تصویر برای کاربر ${user.id}');
            final url =
                await ProfileImageUploadService.uploadImage(_imageFile!);
            logger.i('تصویر با موفقیت آپلود شد، آدرس: $url');

            await ref
                .read(profileProvider.notifier)
                .updateAvatar(user.id, url ?? '');

            if (mounted) {
              _showSnackBar('تصویر با موفقیت بارگذاری شد');
            }
          } catch (e) {
            logger.e('خطا در آپلود تصویر $e');
            if (mounted) {
              _showSnackBar('خطا در آپلود تصویر: ${e.toString()}',
                  isError: true, action: _pickImage);
            }
          }
        }
      }
    } catch (e) {
      logger.e('خطا در انتخاب تصویر $e');
      _showSnackBar('خطا در انتخاب تصویر', isError: true);
    }
  }

  Future<void> _selectBirthDate() async {
    final now = Jalali.now();
    final Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.copy(year: now.year - 20),
      firstDate: Jalali(1300, 1, 1),
      lastDate: now,
      initialEntryMode: PDatePickerEntryMode.calendar,
      initialDatePickerMode: PDatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _accentColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accentColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      logger.d('تاریخ انتخاب شد: ${picked.toString()}');
      setState(() {
        _selectedDate = picked;
        birthDateController.text =
            '${picked.year}/${picked.month}/${picked.day}';
      });
    }
  }

  Future<void> _tryAgainSave() async {
    await _onSaveProfile();
  }

  Future<void> _onSaveProfile() async {
    if (!_formKey.currentState!.validate()) {
      logger.w('فرم معتبر نیست، نمی‌توان اطلاعات را ذخیره کرد');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      logger.e('کاربر لاگین نشده است');
      _showSnackBar('خطا در دسترسی به اطلاعات کاربر', isError: true);
      return;
    }

    final updates = {
      'id': user.id,
      'username': usernameController.text.trim(),
      'full_name': fullNameController.text.trim(),
      'bio': bioController.text.trim(),
      'birth_date': birthDateController.text.trim(),
      'email': user.email,
      'updated_at': DateTime.now().toIso8601String(),
    };

    logger.i('در حال ذخیره‌سازی پروفایل با داده‌های: $updates');

    // اضافه کردن تایمر برای تایم‌اوت
    _saveTimeoutTimer?.cancel();
    _saveTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (ref.read(profileProvider).loading && mounted) {
        logger.w('تایم اوت در ذخیره‌سازی پروفایل');
        ref.read(profileProvider.notifier).setTimeoutError();
        _showSnackBar('زمان ذخیره‌سازی بیش از حد طول کشید',
            isError: true, action: _tryAgainSave);
      }
    });

    try {
      await ref.read(profileProvider.notifier).saveProfile(updates);
      _saveTimeoutTimer?.cancel();

      final state = ref.read(profileProvider);
      if (state.error == null && mounted) {
        logger.i('پروفایل با موفقیت ذخیره شد');
        _showSnackBar('پروفایل با موفقیت ذخیره شد!');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (state.error != null) {
        logger.e('خطا در ذخیره‌سازی پروفایل  ${state.error} ');
        _showSnackBar('خطا در ذخیره‌سازی: ${state.error}', isError: true);
      }
    } catch (e) {
      logger.e('استثنا در ذخیره‌سازی پروفایل $e');
      _showSnackBar('خطا در ذخیره‌سازی: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final backgroundColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final cardColor = isDark ? const Color(0xFF252A37) : Colors.grey.shade50;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _accentColor),
                    const SizedBox(height: 16),
                    Text(
                      'در حال دریافت اطلاعات...',
                      style: TextStyle(color: textColor),
                    )
                  ],
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(textColor),
                      const SizedBox(height: 20),
                      _buildProfileForm(cardColor, textColor, state, isDark),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تکمیل پروفایل',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'برای شروع کار با برنامه، اطلاعات پروفایل خود را تکمیل کنید',
            style: TextStyle(
              fontSize: 16,
              color: textColor.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(
      Color cardColor, Color textColor, ProfileState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfileImage(state, textColor),
            const SizedBox(height: 32),
            _buildInputFields(isDark, textColor),
            const SizedBox(height: 32),
            if (state.error != null) _buildErrorMessage(state.error!),
            const SizedBox(height: 16),
            _buildSaveButton(state, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(ProfileState state, Color textColor) {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentColor.withOpacity(0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : state.avatarUrl != null && state.avatarUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: Image.network(
                            state.avatarUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: _accentColor,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              logger.w('خطا در بارگذاری تصویر $error');
                              return Icon(
                                Icons.person_rounded,
                                size: 60,
                                color: textColor.withOpacity(0.3),
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 60,
                          color: textColor.withOpacity(0.3),
                        ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _secondaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFields(bool isDark, Color textColor) {
    final BorderRadius radius = BorderRadius.circular(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: usernameController,
          label: 'نام کاربری',
          hint: 'نام کاربری شما',
          icon: Icons.person_outline,
          isDark: isDark,
          textColor: textColor,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'لطفاً نام کاربری خود را وارد کنید';
            }
            if (value.length < 3) {
              return 'نام کاربری باید حداقل 3 حرف داشته باشد';
            }
            if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
              return 'نام کاربری فقط می‌تواند شامل حروف، اعداد، نقطه و زیرخط باشد';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: fullNameController,
          label: 'نام و نام خانوادگی',
          hint: 'نام کامل شما',
          icon: Icons.badge_outlined,
          isDark: isDark,
          textColor: textColor,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'لطفاً نام و نام خانوادگی خود را وارد کنید';
            }
            if (value.length < 3) {
              return 'نام و نام خانوادگی باید حداقل 3 حرف داشته باشد';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: bioController,
          label: 'بیوگرافی',
          hint: 'درباره خودتان بنویسید... (اختیاری)',
          icon: Icons.description_outlined,
          isDark: isDark,
          textColor: textColor,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: birthDateController,
          label: 'تاریخ تولد (شمسی)',
          hint: 'سال/ماه/روز',
          icon: Icons.cake_outlined,
          isDark: isDark,
          textColor: textColor,
          readOnly: true,
          onTap: _selectBirthDate,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    Function()? onTap,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final borderRadius = BorderRadius.circular(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
          ),
          cursorColor: _accentColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textColor.withOpacity(0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: _accentColor.withOpacity(0.7),
              size: 22,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: _accentColor,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ProfileState state, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: _animationDuration,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: state.loading ? null : _onSaveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _accentColor.withOpacity(0.7),
                elevation: isDark ? 8 : 2,
                shadowColor: _accentColor.withOpacity(0.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.9)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'در حال ذخیره‌سازی...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ذخیره اطلاعات و ادامه',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

// تابع نمایش تاریخ شمسی
Future<Jalali?> showPersianDatePicker({
  required BuildContext context,
  required Jalali initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
  PDatePickerEntryMode initialEntryMode = PDatePickerEntryMode.calendar,
  PDatePickerMode initialDatePickerMode = PDatePickerMode.day,
  Widget Function(BuildContext, Widget?)? builder,
}) async {
  final now = Jalali.now();
  initialDate = initialDate;

  return showDialog<Jalali>(
    context: context,
    builder: (BuildContext context) {
      return Theme(
        data: Theme.of(context),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: CalendarWidget(
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateSelected: (date) {
                    Navigator.of(context).pop(date);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ویجت ساده تقویم شمسی
class CalendarWidget extends StatefulWidget {
  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;
  final Function(Jalali) onDateSelected;

  const CalendarWidget({
    Key? key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late Jalali _currentMonth;
  late Jalali _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialDate;
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = const Color(0xFF4A80F0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // هدر ماه و سال
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        _currentMonth.copy(month: _currentMonth.month - 1);
                  });
                },
              ),
              Text(
                '${_currentMonth.formatter.mN} ${_currentMonth.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        _currentMonth.copy(month: _currentMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // سرستون‌های روزهای هفته
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
                .map((day) => SizedBox(
                      width: 32,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // روزهای ماه
          ...List.generate(
              (jalaaliMonthLength(_currentMonth.year, _currentMonth.month) +
                          _currentMonth.copy(day: 1).weekDay) ~/
                      7 +
                  1, (weekIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (dayIndex) {
                final day = weekIndex * 7 +
                    dayIndex -
                    _currentMonth.copy(day: 1).weekDay +
                    1;
                final isCurrentMonth = day > 0 &&
                    day <=
                        jalaaliMonthLength(
                            _currentMonth.year, _currentMonth.month);

                if (!isCurrentMonth) {
                  return const SizedBox(width: 32, height: 32);
                }

                final date = _currentMonth.copy(day: day);
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final isInRange = date.isAfter(widget.firstDate) ||
                    date.isSameDay(widget.firstDate);
                final isValid = isInRange &&
                    (date.isBefore(widget.lastDate) ||
                        date.isSameDay(widget.lastDate));

                return InkWell(
                  onTap: isValid
                      ? () {
                          setState(() => _selectedDate = date);
                          widget.onDateSelected(date);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isValid
                                ? textColor
                                : textColor.withOpacity(0.3),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),

          const SizedBox(height: 8),

          // دکمه‌های انتخاب
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'انصراف',
                  style: TextStyle(color: accentColor.withOpacity(0.7)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.onDateSelected(_selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('تأیید'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// تعیین تعداد روزهای ماه در تقویم شمسی
int jalaaliMonthLength(int year, int month) {
  final months = [31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30, 29];
  if (month == 12 && Jalali(year).isLeapYear()) {
    return 30;
  }
  return months[month - 1];
}

// افزودن متد isSameDay به کلاس Jalali
extension JalaliCompare on Jalali {
  bool isSameDay(Jalali other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

// تکمیل enum های مورد نیاز برای date picker
enum PDatePickerEntryMode {
  calendar,
  input,
}

enum PDatePickerMode {
  day,
  year,
}
