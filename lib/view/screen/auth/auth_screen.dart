import '../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../services/advanced_security_service.dart';
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
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
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

  Future<void> _validateUser() async {
    if (_emailOrUsername.isEmpty) {
      _showErrorSnackBar('لطفاً ایمیل یا نام کاربری را وارد کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // بررسی وجود کاربر در دیتابیس
      Map<String, dynamic>? userProfile;

      if (_emailOrUsername.contains('@')) {
        // اگر ایمیل است
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('email', _emailOrUsername)
            .maybeSingle();
      } else {
        // اگر نام کاربری است
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('username', _emailOrUsername)
            .maybeSingle();
      }

      setState(() {
        _userExists = userProfile != null;
      });

      if (_userExists) {
        _showSuccessSnackBar('کاربر یافت شد');
        _nextStep();
      } else {
        _showUserNotFoundDialog();
      }
    } catch (e) {
      _showErrorSnackBar('خطا در بررسی کاربر: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_emailOrUsername.isEmpty || _password.isEmpty) {
      _showErrorSnackBar('لطفاً تمامی فیلدها را پر کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String email;
      Map<String, dynamic> userProfile;

      // بررسی نوع ورود (ایمیل یا نام کاربری)
      if (_emailOrUsername.contains('@')) {
        email = _emailOrUsername;
        logInfo('🔍 Logging in with email: $email');
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('email', email)
            .single();
      } else {
        logInfo('🔍 Logging in with username: $_emailOrUsername');
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('username', _emailOrUsername)
            .single();
        email = userProfile['email'];
        logInfo('📧 Found email for username: $email');
      }

      logInfo('👤 User profile data from database:');
      logInfo('📧 Email: ${userProfile['email']}');
      logInfo('👤 Username: ${userProfile['username']}');
      logInfo('📝 Full Name: ${userProfile['full_name']}');
      logInfo('🖼️ Avatar URL: ${userProfile['avatar_url']}');

      // لاگین کردن کاربر
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: _password,
      );

      // آپدیت متادیتا بعد از لاگین موفق
      if (authResponse.user != null) {
        await _updateUserMetadata(authResponse.user!, userProfile);

        // Store secure session
        await AdvancedSecurityService.storeSecureSession(
            'secure_session_token');
        await AdvancedSecurityService.clearFailedAttempts();

        _showSuccessSnackBar('ورود موفقیت‌آمیز');

        // انتقال مستقیم به صفحه اصلی
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (e is PostgrestException) {
        _showErrorSnackBar('نام کاربری یا ایمیل یافت نشد');
      } else if (e is AuthException) {
        _showErrorSnackBar('نام کاربری یا رمز عبور اشتباه است');
      } else {
        _showErrorSnackBar('خطا در ورود: ${e.toString()}');
      }
      await AdvancedSecurityService.recordFailedAttempt();
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _updateUserMetadata(
      User user, Map<String, dynamic> profile) async {
    try {
      logInfo('🔍 Updating user metadata with profile data:');
      logInfo('📧 Email: ${profile['email']}');
      logInfo('👤 Username: ${profile['username']}');
      logInfo('📝 Full Name: ${profile['full_name']}');
      logInfo('🖼️ Avatar URL: ${profile['avatar_url']}');

      await supabase.auth.updateUser(
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('کاربر یافت نشد'),
          content: Text(
              'نام کاربری یا ایمیل "$_emailOrUsername" در سیستم وجود ندارد. آیا می‌خواهید ثبت نام کنید؟'),
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
                      initialUsername: _emailOrUsername.contains('@')
                          ? ''
                          : _emailOrUsername,
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
