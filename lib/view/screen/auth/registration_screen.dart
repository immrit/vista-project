import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../main.dart';

class RegistrationScreen extends StatefulWidget {
  final String initialEmail;

  const RegistrationScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // متغیرهای اعتبارسنجی نام کاربری
  bool _isCheckingUsername = false;
  String? _usernameValidationMessage;
  bool _isUsernameAvailable = false;

  // Form data
  String _selectedBirthDate = '';
  String? _selectedAvatarUrl;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _emailController.text = widget.initialEmail;
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
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

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Info
        return _emailController.text.trim().isNotEmpty &&
            _usernameController.text.trim().isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _confirmPasswordController.text.isNotEmpty &&
            _passwordController.text == _confirmPasswordController.text &&
            _passwordController.text.length >= 6 &&
            _isUsernameAvailable; // نام کاربری باید آزاد باشه
      case 1: // Profile Info
        return _fullNameController.text.trim().isNotEmpty;
      case 2: // Additional Info
        return true; // Optional fields
      case 3: // Review
        return true;
      default:
        return false;
    }
  }

  Future<void> _handleRegistration() async {
    if (!_validateCurrentStep()) {
      _showErrorSnackBar('لطفاً تمامی فیلدهای اجباری را پر کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // بررسی وجود کاربر قبل از ثبت نام
      final existingUser = await supabase
          .from('profiles')
          .select('email, username')
          .or('email.eq.${_emailController.text.trim()},username.eq.${_usernameController.text.trim()}')
          .maybeSingle();

      if (existingUser != null) {
        if (existingUser['email'] == _emailController.text.trim()) {
          _showErrorSnackBar('این ایمیل قبلاً ثبت شده است');
          return;
        } else if (existingUser['username'] ==
            _usernameController.text.trim()) {
          _showErrorSnackBar('این نام کاربری قبلاً استفاده شده است');
          return;
        }
      }

      // بررسی وجود کاربر در Auth (برای اطمینان بیشتر)
      try {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // اگر لاگین موفق بود، یعنی کاربر قبلاً وجود داره
        _showErrorSnackBar('این ایمیل قبلاً ثبت شده است. لطفاً وارد شوید.');
        return;
      } catch (e) {
        // اگر لاگین ناموفق بود، یعنی کاربر وجود نداره و می‌تونیم ثبت نام کنیم
        print('User does not exist in Auth, proceeding with registration');
      }

      // ثبت نام کاربر در Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResponse.user != null) {
        // بررسی دوباره وجود پروفایل (برای اطمینان)
        final existingProfile = await supabase
            .from('profiles')
            .select('id')
            .eq('id', authResponse.user!.id)
            .maybeSingle();

        if (existingProfile == null) {
          // ایجاد پروفایل کاربر در جدول profiles
          final profileData = {
            'id': authResponse.user!.id,
            'email': _emailController.text.trim(),
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim(),
            'bio': _bioController.text.trim(),
            'birth_date':
                _selectedBirthDate.isNotEmpty ? _selectedBirthDate : null,
            'avatar_url': _selectedAvatarUrl,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await supabase.from('profiles').insert(profileData);
        } else {
          print('Profile already exists, skipping insert');
        }

        // آپدیت متادیتای کاربر
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'id': authResponse.user!.id,
              'username': _usernameController.text.trim(),
              'full_name': _fullNameController.text.trim(),
              'avatar_url': _selectedAvatarUrl,
            },
          ),
        );

        _showSuccessSnackBar(
            'ثبت نام موفقیت‌آمیز! لطفاً ایمیل خود را تأیید کنید.');

        // نمایش صفحه تأیید ایمیل
        if (mounted) {
          _showEmailConfirmationDialog();
        }
      }
    } catch (e) {
      print('Registration Error: $e'); // لاگ برای دیباگ

      if (e is AuthException) {
        if (e.message.contains('email') || e.message.contains('already')) {
          _showErrorSnackBar('این ایمیل قبلاً ثبت شده است');
        } else if (e.message.contains('password')) {
          _showErrorSnackBar('رمز عبور باید حداقل ۶ کاراکتر باشد');
        } else {
          _showErrorSnackBar('خطا در ثبت نام: ${e.message}');
        }
      } else if (e is PostgrestException) {
        if (e.code == '23505') {
          // Duplicate key error
          if (e.message.contains('profiles_pkey')) {
            _showErrorSnackBar('این کاربر قبلاً ثبت نام کرده است');
          } else if (e.message.contains('profiles_username_key')) {
            _showErrorSnackBar('این نام کاربری قبلاً استفاده شده است');
          } else if (e.message.contains('profiles_email_key')) {
            _showErrorSnackBar('این ایمیل قبلاً ثبت شده است');
          } else {
            _showErrorSnackBar('اطلاعات تکراری: ${e.message}');
          }
        } else if (e.message.contains('username') ||
            e.message.contains('duplicate')) {
          _showErrorSnackBar('این نام کاربری قبلاً استفاده شده است');
        } else if (e.message.contains('email') ||
            e.message.contains('duplicate')) {
          _showErrorSnackBar('این ایمیل قبلاً ثبت شده است');
        } else {
          _showErrorSnackBar('خطا در ایجاد پروفایل: ${e.message}');
        }
      } else {
        _showErrorSnackBar('خطا در ثبت نام: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _emailController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _fullNameController.clear();
    _bioController.clear();
    _selectedBirthDate = '';
    _selectedAvatarUrl = null;
    setState(() {
      _currentStep = 0;
      _isCheckingUsername = false;
      _usernameValidationMessage = null;
      _isUsernameAvailable = false;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _validateUsername(String username) async {
    if (username.isEmpty || username.length < 3) {
      setState(() {
        _usernameValidationMessage = null;
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameValidationMessage = null;
    });

    try {
      // بررسی وجود نام کاربری در سرور
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      if (response != null) {
        // نام کاربری موجود است
        setState(() {
          _usernameValidationMessage = 'این نام کاربری قبلاً استفاده شده است';
          _isUsernameAvailable = false;
          _isCheckingUsername = false;
        });
      } else {
        // نام کاربری آزاد است
        setState(() {
          _usernameValidationMessage = 'این نام کاربری آزاد است';
          _isUsernameAvailable = true;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      setState(() {
        _usernameValidationMessage = 'خطا در بررسی نام کاربری';
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'پاک کردن فرم',
          textColor: Colors.white,
          onPressed: _clearForm,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showEmailConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          contentPadding: EdgeInsets.all(24.w),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // آیکون تأیید ایمیل
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.email_outlined,
                  color: Colors.white,
                  size: 40.sp,
                ),
              ),

              SizedBox(height: 24.h),

              // عنوان
              Text(
                'تأیید ایمیل',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16.h),

              // پیام
              Text(
                'لینک تأیید به ایمیل ${_emailController.text.trim()} ارسال شد.',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 8.h),

              Text(
                'لطفاً ایمیل خود را بررسی کنید و روی لینک تأیید کلیک کنید.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // دکمه‌ها
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // بازگشت به صفحه لاگین
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Text(
                        'بعداً',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // بازگشت به صفحه لاگین
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80F0),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'متوجه شدم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ثبت نام',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(),
                  _buildProfileInfoStep(),
                  _buildAdditionalInfoStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _currentStep < 3
          ? Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: _buildContinueButton(),
              ),
            )
          : null,
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8.w : 0),
              height: 4.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2.r),
                color:
                    isActive ? const Color(0xFF4A80F0) : Colors.grey.shade300,
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
    );
  }

  Widget _buildBasicInfoStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Title
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  children: [
                    Text(
                      'اطلاعات پایه',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'ایمیل، نام کاربری و رمز عبور خود را وارد کنید',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: 40.h),

          // Email Input
          _buildInputField(
            controller: _emailController,
            label: 'ایمیل',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          SizedBox(height: 16.h),

          // Username Input
          _buildUsernameField(),

          SizedBox(height: 16.h),

          // Password Input
          _buildPasswordField(
            controller: _passwordController,
            label: 'رمز عبور',
            isVisible: _isPasswordVisible,
            onToggleVisibility: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),

          SizedBox(height: 16.h),

          // Confirm Password Input
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'تأیید رمز عبور',
            isVisible: _isConfirmPasswordVisible,
            onToggleVisibility: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
          ),

          SizedBox(height: 100.h), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildProfileInfoStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Title
          Text(
            'اطلاعات پروفایل',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 12.h),

          Text(
            'نام کامل خود را وارد کنید',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 40.h),

          // Full Name Input
          _buildInputField(
            controller: _fullNameController,
            label: 'نام کامل',
            icon: Icons.badge_outlined,
          ),

          SizedBox(height: 100.h), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
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
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 12.h),

          Text(
            'اطلاعات اختیاری (می‌توانید بعداً تغییر دهید)',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 40.h),

          // Bio Input
          _buildInputField(
            controller: _bioController,
            label: 'بیوگرافی (اختیاری)',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),

          SizedBox(height: 16.h),

          // Birth Date
          _buildDatePicker(),

          SizedBox(height: 100.h), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Title
          Text(
            'بررسی نهایی',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 12.h),

          Text(
            'اطلاعات خود را بررسی کنید',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 40.h),

          // Review Info
          Column(
            children: [
              _buildReviewItem('ایمیل', _emailController.text),
              _buildReviewItem('نام کاربری', _usernameController.text),
              _buildReviewItem('نام کامل', _fullNameController.text),
              if (_bioController.text.isNotEmpty)
                _buildReviewItem('بیوگرافی', _bioController.text),
              if (_selectedBirthDate.isNotEmpty)
                _buildReviewItem('تاریخ تولد', _selectedBirthDate),
            ],
          ),

          SizedBox(height: 40.h),

          // Register Button
          _buildRegisterButton(),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged ?? (value) => setState(() {}),
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            fontSize: 16.sp,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF4A80F0),
            size: 22.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 20.h,
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تعیین رنگ border بر اساس وضعیت اعتبارسنجی
    Color borderColor;
    if (_isCheckingUsername) {
      borderColor = Colors.orange;
    } else if (_usernameValidationMessage != null) {
      borderColor = _isUsernameAvailable ? Colors.green : Colors.red;
    } else {
      borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: _usernameValidationMessage != null
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          TextField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            onChanged: _validateUsername,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'نام کاربری',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 16.sp,
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: const Color(0xFF4A80F0),
                size: 22.sp,
              ),
              suffixIcon: _isCheckingUsername
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    )
                  : _usernameValidationMessage != null
                      ? Icon(
                          _isUsernameAvailable
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _isUsernameAvailable ? Colors.green : Colors.red,
                          size: 20.sp,
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 20.h,
              ),
            ),
          ),

          // نمایش پیام اعتبارسنجی
          if (_usernameValidationMessage != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: (_isUsernameAvailable ? Colors.green : Colors.red)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16.r),
                  bottomRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUsernameAvailable ? Icons.check_circle : Icons.error,
                    color: _isUsernameAvailable ? Colors.green : Colors.red,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _usernameValidationMessage!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: _isUsernameAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        onChanged: onChanged ?? (value) => setState(() {}),
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            fontSize: 16.sp,
          ),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: const Color(0xFF4A80F0),
            size: 22.sp,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggleVisibility,
            child: Icon(
              isVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              size: 22.sp,
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 20.h,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        final selectedDate = await showPersianDatePicker(
          context: context,
          initialDate: Jalali.now(),
          firstDate: Jalali(1300),
          lastDate: Jalali.now(),
        );

        if (selectedDate != null) {
          setState(() {
            _selectedBirthDate = selectedDate.formatCompactDate();
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: const Color(0xFF4A80F0),
              size: 22.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              _selectedBirthDate.isEmpty
                  ? 'تاریخ تولد (اختیاری)'
                  : _selectedBirthDate,
              style: TextStyle(
                fontSize: 16.sp,
                color: _selectedBirthDate.isEmpty
                    ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setState) {
        final isValid = _validateCurrentStep();

        return Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: isValid && !_isLoading
                ? const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isValid && !_isLoading
                ? null
                : isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.r),
              onTap: isValid && !_isLoading ? _nextStep : null,
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 3 ? 'ثبت نام' : 'ادامه',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: isValid
                                  ? Colors.white
                                  : isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            _currentStep == 3
                                ? Icons.person_add_rounded
                                : Icons.arrow_forward_rounded,
                            color: isValid
                                ? Colors.white
                                : isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                            size: 20.sp,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: !_isLoading
            ? const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _isLoading
            ? isDark
                ? Colors.grey.shade700
                : Colors.grey.shade300
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _isLoading ? null : _handleRegistration,
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ثبت نام',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.person_add_rounded,
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
