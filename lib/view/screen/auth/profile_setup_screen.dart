import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../../../provider/ProfileImageUploadService.dart';
import '../../../provider/profile_providers.dart';

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

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const ProfileSetupScreen({
    super.key,
    required this.phoneNumber,
    required this.onComplete,
    required this.onBack,
  });

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  File? _imageFile;
  final bool _isLoading = false;
  bool _isSaving = false;
  Jalali? _selectedDate;
  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _slideController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 512,
        maxWidth: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        _showSnackBar('تصویر انتخاب شد');
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
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text =
            '${picked.year}/${picked.month}/${picked.day}';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('لطفاً تمام فیلدهای اجباری را پر کنید', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showSnackBar('خطا در دسترسی به اطلاعات کاربر', isError: true);
        return;
      }

      String? avatarUrl;
      if (_imageFile != null) {
        avatarUrl = await ProfileImageUploadService.uploadImage(_imageFile!);
      }

      final profileData = {
        'id': user.id,
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'birth_date': _birthDateController.text.trim(),
        'phone': widget.phoneNumber,
        'avatar_url': avatarUrl,
        'email': user.email,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ref.read(profileProvider.notifier).saveProfile(profileData);

      _showSnackBar('پروفایل با موفقیت ایجاد شد!');
      widget.onComplete();
    } catch (e) {
      logger.e('خطا در ذخیره پروفایل $e');
      _showSnackBar('خطا در ذخیره پروفایل: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicInfoStep(),
                      _buildProfileImageStep(),
                      _buildAdditionalInfoStep(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20.sp,
              ),
            ),
          ),

          SizedBox(width: 16.w),

          // Progress Indicator
          Expanded(
            child: Row(
              children: List.generate(3, (index) {
                final isActive = index <= _currentStep;
                final isCompleted = index < _currentStep;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? 8.w : 0),
                    height: 4.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.r),
                      color: isActive
                          ? const Color(0xFF4A80F0)
                          : Colors.grey.shade300,
                    ),
                    child: isCompleted
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2.r),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40.h),

            // Title
            Text(
              'اطلاعات پایه',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'نام کاربری و نام کامل خود را وارد کنید',
              style: TextStyle(
                fontSize: 16.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),

            SizedBox(height: 40.h),

            // Username Field
            _buildTextField(
              controller: _usernameController,
              label: 'نام کاربری',
              hint: 'نام کاربری شما',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'لطفاً نام کاربری وارد کنید';
                }
                if (value.length < 3) {
                  return 'نام کاربری باید حداقل ۳ حرف داشته باشد';
                }
                if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
                  return 'نام کاربری فقط می‌تواند شامل حروف، اعداد، نقطه و زیرخط باشد';
                }
                return null;
              },
            ),

            SizedBox(height: 24.h),

            // Full Name Field
            _buildTextField(
              controller: _fullNameController,
              label: 'نام و نام خانوادگی',
              hint: 'نام کامل شما',
              icon: Icons.badge_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'لطفاً نام و نام خانوادگی وارد کنید';
                }
                if (value.length < 3) {
                  return 'نام باید حداقل ۳ حرف داشته باشد';
                }
                return null;
              },
            ),

            const Spacer(),

            // Continue Button
            _buildContinueButton(),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Title
          Text(
            'تصویر پروفایل',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'تصویر پروفایل خود را انتخاب کنید (اختیاری)',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 60.h),

          // Profile Image
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 150.w,
              height: 150.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4A80F0),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A80F0).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(75.w),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF4A80F0),
                            const Color(0xFF6B9EFF),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 50.sp,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          SizedBox(height: 24.h),

          Text(
            'برای انتخاب تصویر ضربه بزنید',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),

          const Spacer(),

          // Continue Button
          _buildContinueButton(),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40.h),

          // Title
          Text(
            'اطلاعات تکمیلی',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'بیوگرافی و تاریخ تولد خود را وارد کنید',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),

          SizedBox(height: 40.h),

          // Bio Field
          _buildTextField(
            controller: _bioController,
            label: 'بیوگرافی',
            hint: 'درباره خودتان بنویسید...',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),

          SizedBox(height: 24.h),

          // Birth Date Field
          _buildTextField(
            controller: _birthDateController,
            label: 'تاریخ تولد (شمسی)',
            hint: 'سال/ماه/روز',
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: _selectBirthDate,
          ),

          const Spacer(),

          // Complete Button
          _buildCompleteButton(),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 16.sp,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF4A80F0),
              size: 22.sp,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFF4A80F0),
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A80F0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _nextStep,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ادامه',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A80F0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _isSaving ? null : _saveProfile,
          child: Center(
            child: _isSaving
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'تکمیل پروفایل',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
