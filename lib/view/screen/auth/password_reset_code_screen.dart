import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';

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
      print('📨 ایمیل دریافتی از صفحه قبلی: $_email');
      print('📨 Arguments کامل: $args');
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
    super.dispose();
  }

  Future<void> _resetPassword() async {
    print('🔍 شروع اعتبارسنجی');

    if (_email == null) {
      print('❌ ایمیل یافت نشد');
      _showErrorSnackBar('ایمیل یافت نشد. لطفاً دوباره تلاش کنید');
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      print('❌ کد خالی است');
      _showErrorSnackBar('لطفاً کد بازیابی را وارد کنید');
      return;
    }

    if (_newPasswordController.text.trim().isEmpty) {
      print('❌ رمز جدید خالی است');
      _showErrorSnackBar('لطفاً رمز جدید را وارد کنید');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      print('❌ رمز کوتاه است: ${_newPasswordController.text.length} کاراکتر');
      _showErrorSnackBar('رمز عبور باید حداقل ۶ کاراکتر باشد');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      print('❌ رمزها یکسان نیستند');
      print('رمز جدید: ${_newPasswordController.text}');
      print('رمز تایید: ${_confirmPasswordController.text}');
      _showErrorSnackBar('رمز عبور و تایید آن یکسان نیستند');
      return;
    }

    print('✅ تمام اعتبارسنجی‌ها پاس شد');

    setState(() => _isLoading = true);

    try {
      print('🔍 شروع تغییر رمزعبور');
      print('📧 ایمیل: $_email');
      print('🔑 کد وارد شده: ${_codeController.text.trim()}');
      print('🔒 رمز جدید: ${_newPasswordController.text.trim()}');
      print('✅ رمز تایید: ${_confirmPasswordController.text.trim()}');

      // در Supabase، برای بازیابی رمزعبور، باید از verifyOTP استفاده کنیم
      // این method کد بازیابی رو تایید می‌کنه و session موقت ایجاد می‌کنه
      print('🔐 تایید کد بازیابی با verifyOTP...');
      final verifyResponse = await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: _codeController.text.trim(),
        email: _email!,
      );
      print('🔄 پاسخ verifyOTP: ${verifyResponse.user?.email ?? 'null'}');
      print('👤 کاربر تایید شده: ${verifyResponse.user?.id ?? 'null'}');

      if (verifyResponse.user != null) {
        print('✅ کد بازیابی تایید شد، حالا رمز رو تغییر می‌دیم');
        // حالا که کد تایید شد، رمز رو تغییر می‌دیم
        final updateResponse = await supabase.auth.updateUser(
          UserAttributes(
            password: _newPasswordController.text.trim(),
          ),
        );
        print('🔄 پاسخ updateUser: ${updateResponse.user?.email ?? 'null'}');

        if (updateResponse.user != null) {
          print('✅ رمز عبور با موفقیت تغییر یافت');
          _showSuccessSnackBar('رمز عبور با موفقیت تغییر یافت');
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        } else {
          print('❌ خطا در تغییر رمز عبور - پاسخ خالی');
          throw Exception('خطا در تغییر رمز عبور');
        }
      } else {
        print('❌ کد بازیابی نامعتبر است');
        throw Exception('کد بازیابی نامعتبر است');
      }
    } catch (error) {
      print('🚨 خطای تغییر رمزعبور: $error');
      print('🚨 نوع خطا: ${error.runtimeType}');
      print('🚨 جزئیات خطا: ${error.toString()}');

      String errorMessage = 'خطا در تغییر رمز عبور';

      if (error.toString().contains('Invalid OTP') ||
          error.toString().contains('invalid_token')) {
        errorMessage = 'کد بازیابی نامعتبر است';
        print('🚨 تشخیص خطا: کد نامعتبر');
      } else if (error.toString().contains('expired')) {
        errorMessage = 'کد بازیابی منقضی شده است';
        print('🚨 تشخیص خطا: کد منقضی شده');
      } else if (error.toString().contains('Auth session missing')) {
        errorMessage = 'لطفاً دوباره از صفحه بازیابی رمزعبور شروع کنید';
        print('🚨 تشخیص خطا: session missing');
      } else if (error.toString().contains('password')) {
        errorMessage = 'رمز عبور معتبر نیست';
        print('🚨 تشخیص خطا: مشکل رمز عبور');
      }

      print('📝 پیام خطا برای کاربر: $errorMessage');
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
