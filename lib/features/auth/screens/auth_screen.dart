import '../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/advanced_security_service.dart';
import '../../../services/session_manager_service.dart';
import 'email_username_auth_screen.dart';
import 'password_auth_screen.dart';
import 'registration_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Auth data
  String _emailOrUsername = '';
  String _password = '';
  bool _isLoading = false;
  bool _userExists = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startIntroAnimation();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _startIntroAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      if (!mounted) return;
      setState(() {
        _currentStep++;
      });
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      if (!mounted) return;
      setState(() {
        _currentStep--;
      });
      if (_pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  Future<void> _validateUser() async {
    if (_emailOrUsername.isEmpty) {
      _showErrorSnackBar(
          'لطفاً ایمیل، نام کاربری یا شماره موبایل را وارد کنید');
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // بررسی وجود کاربر در دیتابیس
      Map<String, dynamic>? userProfile;

      if (_emailOrUsername.contains('@')) {
        // اگر ایمیل است
        userProfile = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('email', _emailOrUsername)
            .maybeSingle();
      } else if (RegExp(r'^\+?[0-9]{10,13}$').hasMatch(_emailOrUsername)) {
        // اگر شماره موبایل است
        userProfile = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('phone', _emailOrUsername) // Assuming column name is 'phone'
            .maybeSingle();
      } else {
        // اگر نام کاربری است
        userProfile = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('username', _emailOrUsername)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          _userExists = userProfile != null;
        });
      }

      if (_userExists) {
        // ✅ بررسی محدودیت حساب کاربری قبل از ادامه
        final userId = userProfile!['id'] as String?;
        if (userId != null) {
          final isLocked =
              await AdvancedSecurityService.isAccountLocked(userId: userId);
          if (isLocked) {
            // دریافت اطلاعات قفل
            final lockInfo =
                await AdvancedSecurityService.getLockInfo(userId: userId);
            final lockReason = lockInfo != null
                ? await AdvancedSecurityService.getLockReasonPersian(
                    userId: userId)
                : null;
            final remainingTime =
                await AdvancedSecurityService.getRemainingLockoutTime(
                    userId: userId);
            final lockType = lockInfo?['lock_type'] as String?;

            // نمایش دیالوگ محدودیت
            if (mounted) {
              _showAccountLockedDialog(
                remainingTime: remainingTime,
                lockReason: lockReason,
                lockType: lockType,
              );
            }
            return; // جلوگیری از ادامه به مرحله بعد
          }
        }

        if (mounted) {
          _showSuccessSnackBar('کاربر یافت شد');
          _nextStep();
        }
      } else {
        if (mounted) _showUserNotFoundDialog();
      }
    } catch (e) {
      _showErrorSnackBar('خطا در بررسی کاربر: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_emailOrUsername.isEmpty || _password.isEmpty) {
      _showErrorSnackBar('لطفاً تمامی فیلدها را پر کنید');
      return;
    }

    // ابتدا userProfile را بگیریم تا userId را داشته باشیم
    String? userId;
    try {
      dynamic tempProfile;
      if (_emailOrUsername.contains('@')) {
        tempProfile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('email', _emailOrUsername)
            .maybeSingle();
      } else if (RegExp(r'^\+?[0-9]{10,13}$').hasMatch(_emailOrUsername)) {
        tempProfile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('phone', _emailOrUsername)
            .maybeSingle();
      } else {
        tempProfile = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', _emailOrUsername)
            .maybeSingle();
      }
      if (tempProfile != null) {
        userId = (tempProfile as Map<String, dynamic>)['id'] as String?;
      }
    } catch (e) {
      // اگر کاربر پیدا نشد، ادامه می‌دهیم (خطا بعداً نمایش داده می‌شود)
    }

    // بررسی قفل بودن حساب قبل از تلاش برای ورود
    if (userId != null) {
      final isLocked =
          await AdvancedSecurityService.isAccountLocked(userId: userId);
      if (isLocked) {
        // دریافت اطلاعات قفل
        final lockInfo =
            await AdvancedSecurityService.getLockInfo(userId: userId);
        final lockReason = lockInfo != null
            ? await AdvancedSecurityService.getLockReasonPersian(userId: userId)
            : null;
        final remainingTime =
            await AdvancedSecurityService.getRemainingLockoutTime(
                userId: userId);
        final lockType = lockInfo?['lock_type'] as String?;

        // نمایش دیالوگ محدودیت
        _showAccountLockedDialog(
          remainingTime: remainingTime,
          lockReason: lockReason,
          lockType: lockType,
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    // تعریف متغیرها در scope خارجی برای استفاده در catch block
    String? email;
    Map<String, dynamic>? userProfile;

    try {
      // بررسی نوع ورود (ایمیل، موبایل یا نام کاربری)
      if (_emailOrUsername.contains('@')) {
        email = _emailOrUsername;
        logInfo('🔍 Logging in with email: $email');
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('email', email)
            .single();
        userProfile = Map<String, dynamic>.from(response);
      } else if (RegExp(r'^\+?[0-9]{10,13}$').hasMatch(_emailOrUsername)) {
        logInfo('🔍 Logging in with phone: $_emailOrUsername');
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('phone', _emailOrUsername)
            .single();
        userProfile = Map<String, dynamic>.from(response);
        email = userProfile['email'] as String;
        logInfo('📧 Found email for phone: $email');
      } else {
        logInfo('🔍 Logging in with username: $_emailOrUsername');
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('username', _emailOrUsername)
            .single();
        userProfile = Map<String, dynamic>.from(response);
        email = userProfile['email'] as String;
        logInfo('📧 Found email for username: $email');
      }

      // به‌روزرسانی userId از userProfile
      userId = userProfile['id'] as String?;

      logInfo('👤 User profile data from database:');
      logInfo('📧 Email: ${userProfile['email']}');
      logInfo('👤 Username: ${userProfile['username']}');
      logInfo('📝 Full Name: ${userProfile['full_name']}');
      logInfo('🖼️ Avatar URL: ${userProfile['avatar_url']}');

      // لاگین کردن کاربر
      logInfo('🔐 Attempting to sign in with email: $email');

      // استفاده از Supabase.instance.client به جای supabase global برای جلوگیری از مشکل hot reload
      final supabaseClient = Supabase.instance.client;
      final authResponse = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: _password,
      );
      logInfo('✅ Sign in successful!');

      // آپدیت متادیتا بعد از لاگین موفق
      if (authResponse.user != null) {
        await _updateUserMetadata(authResponse.user!, userProfile);

        // Store secure session
        await AdvancedSecurityService.storeSecureSession(
            'secure_session_token');

        // پاک کردن تلاش‌های ناموفق (با userId برای پاک کردن از دیتابیس)
        if (userId != null) {
          await AdvancedSecurityService.clearFailedAttempts(userId: userId);
        }

        // ثبت نشست جدید - فقط یک بار
        try {
          final sessionManager = SessionManagerService();
          final sessionId = await sessionManager.registerSession();
          if (sessionId != null) {
            logInfo('✅ Session registered successfully: $sessionId');
            // آپدیت موقعیت و IP در پس‌زمینه (غیرمسدودکننده)
            sessionManager.updateLocationAndIP();
          } else {
            logInfo('⚠️ Failed to register session');
          }
        } catch (e) {
          logInfo('⚠️ Failed to register session: $e');
        }

        _showSuccessSnackBar('ورود موفقیت‌آمیز');

        // انتقال مستقیم به صفحه اصلی
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e, stackTrace) {
      // لاگ کردن خطای دقیق
      logInfo('❌ Login error occurred:');
      logInfo('   Error type: ${e.runtimeType}');
      logInfo('   Error message: ${e.toString()}');
      if (e is AuthException) {
        logInfo('   Auth error statusCode: ${e.statusCode}');
        logInfo('   Auth error message: ${e.message}');
      }
      logInfo('   Stack trace: $stackTrace');

      // اگر خطای StateError مربوط به closed stream بود، یک بار دیگر با instance جدید تلاش کنیم
      if (e is StateError &&
          e.toString().contains('Cannot add new events after calling close')) {
        logInfo(
            '🔄 Detected closed stream error, retrying with fresh Supabase instance...');
        // فقط اگر email و userProfile موجود باشند، retry کنیم
        if (email != null && userProfile != null) {
          try {
            // استفاده از instance جدید
            final freshClient = Supabase.instance.client;
            final retryAuthResponse = await freshClient.auth.signInWithPassword(
              email: email,
              password: _password,
            );
            logInfo('✅ Retry sign in successful!');

            // ادامه با موفقیت
            if (retryAuthResponse.user != null) {
              await _updateUserMetadata(retryAuthResponse.user!, userProfile);
              await AdvancedSecurityService.storeSecureSession(
                  'secure_session_token');
              if (userId != null) {
                await AdvancedSecurityService.clearFailedAttempts(
                    userId: userId);
              }
              _showSuccessSnackBar('ورود موفقیت‌آمیز');
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
              return;
            }
          } catch (retryError) {
            logInfo('❌ Retry also failed: $retryError');
            // ادامه با خطای اصلی
          }
        } else {
          logInfo('⚠️ Cannot retry: email or userProfile not available');
        }
      }

      // ثبت تلاش ناموفق (با userId برای ذخیره در دیتابیس)
      await AdvancedSecurityService.recordFailedAttempt(userId: userId);

      // بررسی مجدد قفل بودن حساب بعد از ثبت تلاش ناموفق
      final isLockedAfterAttempt =
          await AdvancedSecurityService.isAccountLocked(userId: userId);
      if (isLockedAfterAttempt) {
        final remainingTime =
            await AdvancedSecurityService.getRemainingLockoutTime(
                userId: userId);
        if (remainingTime != null) {
          _showLockoutDialog(remainingTime);
          return;
        }
      }

      if (e is PostgrestException) {
        _showErrorSnackBar('اطلاعات کاربری اشتباه است');
      } else if (e is AuthException) {
        // نمایش پیام خطای دقیق‌تر
        final errorMessage = e.message;
        logInfo('🔴 Auth error details: $errorMessage');
        _showErrorSnackBar(errorMessage.contains('Invalid login credentials')
            ? 'نام کاربری یا رمز عبور اشتباه است'
            : (errorMessage.isNotEmpty
                ? errorMessage
                : 'نام کاربری یا رمز عبور اشتباه است'));
      } else {
        _showErrorSnackBar('خطا در ورود: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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

  Future<void> _updateUserMetadata(
      User user, Map<String, dynamic> profile) async {
    try {
      logInfo('🔍 Updating user metadata with profile data:');
      logInfo('📧 Email: ${profile['email']}');
      logInfo('👤 Username: ${profile['username']}');
      logInfo('📝 Full Name: ${profile['full_name']}');
      logInfo('🖼️ Avatar URL: ${profile['avatar_url']}');

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'id': profile['id'],
            'username': profile['username'],
            'full_name': profile['full_name'],
            'avatar_url': profile['avatar_url'],
            'email': profile['email'],
            'updated_at': profile['updated_at'],
          },
        ),
      );

      logInfo('✅ User metadata updated successfully');
    } catch (e) {
      logInfo('❌ Error updating user metadata: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در بروزرسانی اطلاعات: $e');
      }
    }
  }

  void _showUserNotFoundDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          alignment: Alignment.center,
          title: const Text('کاربر یافت نشد', textAlign: TextAlign.center),
          content: Text(
              'اطلاعات "$_emailOrUsername" در سیستم وجود ندارد. آیا می‌خواهید ثبت نام کنید؟',
              textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RegistrationScreen(
                      initialEmail: _emailOrUsername.contains('@')
                          ? _emailOrUsername
                          : '',
                      initialUsername: !_emailOrUsername.contains('@') &&
                              !RegExp(r'^\+?[0-9]{10,13}$')
                                  .hasMatch(_emailOrUsername)
                          ? _emailOrUsername
                          : '',
                    ),
                  ),
                );
              },
              child: const Text('ثبت نام'),
            ),
          ],
        );
      },
    );
  }

  void _showLockoutDialog(Duration remainingTime) {
    final minutes = remainingTime.inMinutes;
    final seconds = remainingTime.inSeconds % 60;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('حساب کاربری قفل شده'),
        content: Text(
          'به دلیل تلاش‌های ناموفق متعدد، حساب کاربری شما قفل شده است.\n\n'
          'لطفاً $minutes دقیقه و $seconds ثانیه صبر کنید و سپس دوباره تلاش کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  void _showAccountLockedDialog({
    Duration? remainingTime,
    String? lockReason,
    String? lockType,
  }) {
    String message = 'حساب کاربری شما محدود شده است.\n\n';

    if (lockReason != null) {
      message += 'علت: $lockReason\n\n';
    }

    if (lockType == 'permanent') {
      message += 'این محدودیت دائمی است. لطفاً با پشتیبانی تماس بگیرید.';
    } else if (remainingTime != null) {
      final minutes = remainingTime.inMinutes;
      final seconds = remainingTime.inSeconds % 60;
      message += 'زمان باقی‌مانده: $minutes دقیقه و $seconds ثانیه\n\n'
          'لطفاً بعد از اتمام زمان، دوباره تلاش کنید.';
    } else {
      message += 'لطفاً با پشتیبانی تماس بگیرید.';
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ دسترسی محدود شده'),
        content: Text(message),
        actions: [
          if (lockType != 'permanent' && remainingTime != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // بازگشت به مرحله اول
                _previousStep();
              },
              child: const Text('تلاش مجدد'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('متوجه شدم'),
          ),
        ],
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
            _buildProgressIndicator(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildEmailUsernameStep(),
                        _buildPasswordStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        children: List.generate(2, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 1 ? 8.w : 0),
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

  Widget _buildEmailUsernameStep() {
    return EmailUsernameAuthScreen(
      emailOrUsername: _emailOrUsername,
      onEmailOrUsernameChanged: (emailOrUsername) =>
          setState(() => _emailOrUsername = emailOrUsername),
      onContinue: _validateUser,
      isLoading: _isLoading,
    );
  }

  Widget _buildPasswordStep() {
    return PasswordAuthScreen(
      emailOrUsername: _emailOrUsername,
      password: _password,
      onPasswordChanged: (password) => setState(() => _password = password),
      onLogin: _handleLogin,
      onBack: _previousStep,
      onForgotPassword: () {
        // Navigate to forgot password screen
        Navigator.pushNamed(context, '/reset-password');
      },
      isLoading: _isLoading,
    );
  }
}
