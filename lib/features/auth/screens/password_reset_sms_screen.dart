import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:Vista/core/security/input_policy.dart';

import '../../../utils/directional_navigation.dart';
import '../data/auth_repository.dart';
import 'package:Vista/core/theme/app_theme.dart';

class PasswordResetSmsScreen extends StatefulWidget {
  const PasswordResetSmsScreen({super.key});

  @override
  State<PasswordResetSmsScreen> createState() => _PasswordResetSmsScreenState();
}

class _PasswordResetSmsScreenState extends State<PasswordResetSmsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _phone;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  int _resendCountdown = 0;
  Timer? _resendTimer;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final phoneArg = args?['phone'] as String?;
      _phone = phoneArg == null ? null : normalizePhone09(phoneArg);
      if (_phone != null && _phone!.isNotEmpty) {
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
    final phone = _phone == null ? null : normalizePhone09(_phone!);
    if (phone == null) {
      _showErrorSnackBar('شماره موبایل یافت نشد. لطفاً دوباره تلاش کنید');
      return;
    }
    if (_resendCountdown > 0) return;

    try {
      _startResendCountdown(60);
      await AuthRepository().sendOtp(phone);
      _showSuccessSnackBar(
          'اگر حسابی با این شماره وجود داشته باشد، کد بازنشانی ارسال می‌شود');
    } catch (_) {
      _startResendCountdown(0);
      _showErrorSnackBar('خطا در ارسال مجدد پیامک. لطفاً دوباره تلاش کنید');
    }
  }

  Future<void> _resetPasswordViaSms() async {
    final phone = _phone == null ? null : normalizePhone09(_phone!);
    if (phone == null) {
      _showErrorSnackBar('شماره موبایل یافت نشد. لطفاً دوباره تلاش کنید');
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 4) {
      _showErrorSnackBar('لطفاً کد را وارد کنید');
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (newPassword.isEmpty) {
      _showErrorSnackBar('لطفاً رمز جدید را وارد کنید');
      return;
    }
    final passwordValidation =
        validatePasswordBalanced(newPassword, phone: phone);
    if (!passwordValidation.isValid) {
      _showErrorSnackBar(passwordValidation.message);
      return;
    }
    if (newPassword != confirmPassword) {
      _showErrorSnackBar('رمز عبور و تایید آن یکسان نیستند');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthRepository().resetPasswordSms(
        phoneNumber: phone,
        code: code,
        newPassword: newPassword,
      );

      if (!mounted) return;
      _showSuccessSnackBar('رمز عبور با موفقیت تغییر یافت');
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) {
      _showErrorSnackBar(
          e is String ? e : 'کد نامعتبر است یا خطایی رخ داده است');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, AppColors.lightBorder],
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
                            directionalBackIcon(context, ios: true),
                            color: isDark ? Colors.white : Colors.black87,
                            size: 20.sp,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          'بازنشانی با پیامک',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(width: 48.w),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 16.h),
                          Text(
                            _phone == null || _phone!.isEmpty
                                ? 'کد را وارد کنید'
                                : 'کد ارسال شده به شماره ${_phone!} را وارد کنید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 24.h),

                          // Code
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'کد پیامک',
                              prefixIcon: Icon(Icons.verified_outlined),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          if (_resendCountdown > 0)
                            Text(
                              'ارسال مجدد کد در $_resendCountdown ثانیه',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _isLoading ? null : _resendCode,
                              child: const Text('ارسال مجدد کد'),
                            ),

                          SizedBox(height: 24.h),

                          // New password
                          TextField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              hintText: 'رمز عبور جدید',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(() =>
                                    _obscureNewPassword = !_obscureNewPassword),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Confirm
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _resetPasswordViaSms(),
                            decoration: InputDecoration(
                              hintText: 'تایید رمز عبور جدید',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(() =>
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword),
                              ),
                            ),
                          ),

                          SizedBox(height: 32.h),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _resetPasswordViaSms,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تغییر رمز عبور'),
                          ),

                          SizedBox(height: 24.h),
                        ],
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
