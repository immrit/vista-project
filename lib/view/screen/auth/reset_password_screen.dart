import '../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../main.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailSent = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

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
    _emailController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('لطفاً ایمیل خود را وارد کنید');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_emailController.text.trim())) {
      _showErrorSnackBar('لطفاً یک ایمیل معتبر وارد کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      logInfo('📧 ارسال کد بازیابی به ایمیل: ${_emailController.text.trim()}');
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'vista://auth/reset-password',
      );
      logInfo('✅ کد بازیابی با موفقیت ارسال شد');

      setState(() => _isEmailSent = true);
      _showSuccessSnackBar('کد بازیابی به ایمیل شما ارسال شد');

      // هدایت به صفحه وارد کردن کد بعد از ۲ ثانیه
      logInfo('⏰ هدایت به صفحه کد بعد از ۲ ثانیه...');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          logInfo('🚀 هدایت به صفحه وارد کردن کد');
          Navigator.pushNamed(
            context,
            '/reset-password-code',
            arguments: {'email': _emailController.text.trim()},
          );
        }
      });
    } catch (error) {
      logInfo('🚨 خطای ارسال ایمیل: $error');
      logInfo('🚨 نوع خطا: ${error.runtimeType}');
      logInfo('🚨 جزئیات خطا: ${error.toString()}');
      _showErrorSnackBar('خطا در ارسال ایمیل. لطفاً دوباره تلاش کنید');
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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 40.h),

                          // Header
                          Container(
                            width: 120.w,
                            height: 120.w,
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
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              size: 60.sp,
                              color: Colors.white,
                            ),
                          ),

                          SizedBox(height: 40.h),

                          // Title
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF4A80F0), Color(0xFF00A8E8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'بازیابی رمزعبور',
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
                            _isEmailSent
                                ? 'کد بازیابی به ایمیل شما ارسال شد'
                                : 'ایمیل خود را وارد کنید تا کد بازیابی برای شما ارسال شود',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 40.h),

                          // Email Input
                          if (!_isEmailSent) ...[
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
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: 'ایمیل خود را وارد کنید',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 16.sp,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email,
                                    color: const Color(0xFF4A80F0),
                                    size: 24.sp,
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
                          ],

                          // Success State
                          if (_isEmailSent) ...[
                            SizedBox(height: 40.h),

                            Container(
                              padding: EdgeInsets.all(24.w),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 48.sp,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'کد بازیابی ارسال شد!',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'لطفاً ایمیل خود را چک کنید و کد بازیابی را وارد کنید',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 32.h),

                            // Auto redirect message
                            Text(
                              'در حال هدایت به صفحه وارد کردن کد...',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          // Back Button
                          if (!_isEmailSent) ...[
                            SizedBox(height: 32.h),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, '/auth');
                              },
                              child: Text(
                                'بازگشت به صفحه ورود',
                                style: TextStyle(
                                  color: const Color(0xFF4A80F0),
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: 40.h),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar - دکمه ارسال
                  if (!_isEmailSent)
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'ارسال کد بازیابی',
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
