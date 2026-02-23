import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Vista/core/security/input_policy.dart';
import '../../../utils/const.dart';

class PasswordResetCodeScreen extends StatefulWidget {
  const PasswordResetCodeScreen({super.key});

  @override
  State<PasswordResetCodeScreen> createState() =>
      _PasswordResetCodeScreenState();
}

class _PasswordResetCodeScreenState extends State<PasswordResetCodeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _email;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // دریافت ایمیل از arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _email = args?['email'] as String?;
      // Avoid logging user inputs (email/token) in auth flows.
      if (_email != null && _email!.isNotEmpty) {
        _startResendCountdown(30);
      }
    });

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

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

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown -= 1);
      }
    });
  }

  Future<void> _resendCode() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      _showErrorSnackBar('ایمیل یافت نشد. لطفاً دوباره تلاش کنید');
      return;
    }
    if (_resendCountdown > 0) return;

    try {
      _startResendCountdown(60);
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'vista://auth/reset-password',
      );
      _showSuccessSnackBar(
          'اگر حسابی با این ایمیل وجود داشته باشد، کد بازنشانی ارسال می‌شود');
    } catch (_) {
      _showErrorSnackBar('خطا در ارسال مجدد کد. لطفاً دوباره تلاش کنید');
      // Allow retry sooner if the request failed immediately.
      _startResendCountdown(0);
    }
  }

  Future<void> _resetPassword() async {
    if (_email == null) {
      _showErrorSnackBar('ایمیل یافت نشد. لطفاً دوباره تلاش کنید');
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackBar('لطفاً کد بازیابی را وارد کنید');
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty) {
      _showErrorSnackBar('لطفاً رمز جدید را وارد کنید');
      return;
    }

    final passwordValidation = validatePasswordBalanced(newPassword);
    if (!passwordValidation.isValid) {
      _showErrorSnackBar(passwordValidation.message);
      return;
    }

    if (newPassword != _confirmPasswordController.text) {
      _showErrorSnackBar('رمز عبور و تایید آن یکسان نیستند');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifyResponse = await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: code,
        email: _email!,
      );

      if (verifyResponse.user != null) {
        final updateResponse = await supabase.auth.updateUser(
          UserAttributes(
            password: newPassword,
          ),
        );

        if (updateResponse.user != null) {
          _showSuccessSnackBar('رمز عبور با موفقیت تغییر یافت');
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        } else {
          throw Exception('خطا در تغییر رمز عبور');
        }
      } else {
        throw Exception('کد بازیابی نامعتبر است');
      }
    } catch (error) {
      String errorMessage = 'خطا در تغییر رمز عبور';

      if (error.toString().contains('Invalid OTP') ||
          error.toString().contains('invalid_token')) {
        errorMessage = 'کد بازیابی نامعتبر است';
      } else if (error.toString().contains('expired')) {
        errorMessage = 'کد بازیابی منقضی شده است';
      } else if (error.toString().contains('Auth session missing')) {
        errorMessage = 'لطفاً دوباره از صفحه بازیابی رمزعبور شروع کنید';
      } else if (error.toString().contains('password')) {
        errorMessage = 'رمز عبور معتبر نیست';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 20.sp,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          'تغییر رمز عبور',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(width: 48.w),
                      ],
                    ),
                  ),

                  if (_email != null) ...[
                    Container(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: Text(
                        'ایمیل: $_email',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF4A80F0),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Main content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 20.h),

                          // Header Icon
                          Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A80F0), Color(0xFF00A8E8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF4A80F0).withOpacity(0.4),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.password,
                              size: 50.sp,
                              color: Colors.white,
                            ),
                          ),

                          SizedBox(height: 30.h),

                          // Title
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF4A80F0), Color(0xFF00A8E8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'تغییر رمز عبور',
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Subtitle
                          Text(
                            'کد بازیابی را از ایمیل خود وارد کنید',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 40.h),

                          // Code Input
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              decoration: InputDecoration(
                                hintText: 'کد ۶ رقمی را وارد کنید',
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 16.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.pin,
                                  color: const Color(0xFF4A80F0),
                                  size: 24.sp,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 20.h,
                                ),
                                counterText: '',
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18.sp,
                                letterSpacing: 8.w,
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          // New Password Input
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'رمز عبور جدید',
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 16.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock,
                                  color: const Color(0xFF4A80F0),
                                  size: 24.sp,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF4A80F0),
                                    size: 20.sp,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 20.h,
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          // Confirm Password Input
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _resetPassword(),
                              decoration: InputDecoration(
                                hintText: 'تایید رمز عبور جدید',
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 16.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: const Color(0xFF4A80F0),
                                  size: 24.sp,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF4A80F0),
                                    size: 20.sp,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 20.h,
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),

                          SizedBox(height: 32.h),

                          if (_resendCountdown > 0)
                            Text(
                              'ارسال مجدد کد در $_resendCountdown ثانیه',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _isLoading ? null : _resendCode,
                              child: Text(
                                'ارسال مجدد کد',
                                style: TextStyle(
                                  color: const Color(0xFF4A80F0),
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Back Button
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/auth',
                                (route) => false,
                              );
                            },
                            child: Text(
                              'بازگشت به صفحه ورود',
                              style: TextStyle(
                                color: const Color(0xFF4A80F0),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar - Change Password Button
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.8)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24.r),
                        topRight: Radius.circular(24.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF00A8E8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80F0).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _resetPassword,
                          borderRadius: BorderRadius.circular(16.r),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'تغییر رمز عبور',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
