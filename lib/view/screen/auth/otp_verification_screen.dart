import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String otpCode;
  final Function(String) onOTPChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;
  final bool isLoading;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.otpCode,
    required this.onOTPChanged,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    required this.isLoading,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _shakeController;
  late AnimationController _countdownController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _shakeAnimation;

  Timer? _countdownTimer;
  int _countdown = 60;
  bool _canResend = false;
  String _enteredOTP = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCountdown();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.1, 0.0),
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _animationController.forward();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _resendOTP() {
    if (_canResend) {
      setState(() {
        _canResend = false;
        _countdown = 60;
        _enteredOTP = '';
      });
      widget.onResend();
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeController.dispose();
    _countdownController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Back Button
          Row(
            children: [
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
            ],
          ),

          SizedBox(height: 40.h),

          // Animated Icon
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 100.w,
                  height: 100.w,
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A80F0).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sms_rounded,
                    size: 50.sp,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 40.h),

          // Title and Description
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'کد تأیید را وارد کنید',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'کد ۶ رقمی به شماره ${widget.phoneNumber} ارسال شد',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 60.h),

          // OTP Input
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildOTPInput(),
          ),

          SizedBox(height: 40.h),

          // Verify Button
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildVerifyButton(),
          ),

          SizedBox(height: 30.h),

          // Resend Section
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildResendSection(),
          ),

          const Spacer(),

          // Security Note
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildSecurityNote(),
          ),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildOTPInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      onChanged: (value) {
        setState(() {
          _enteredOTP = value;
        });
        widget.onOTPChanged(value);
        if (value.length == 6) {
          widget.onVerify();
        }
      },
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
        letterSpacing: 8.w,
      ),
      decoration: InputDecoration(
        hintText: '------',
        hintStyle: TextStyle(
          fontSize: 24.sp,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
          letterSpacing: 8.w,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(
            color: Color(0xFF4A80F0),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20.w,
          vertical: 20.h,
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOTPComplete = _enteredOTP.length == 6;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: isOTPComplete && !widget.isLoading
            ? const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isOTPComplete && !widget.isLoading
            ? null
            : isDark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
        boxShadow: isOTPComplete && !widget.isLoading
            ? [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: isOTPComplete && !widget.isLoading ? widget.onVerify : null,
          child: Center(
            child: widget.isLoading
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
                        'تأیید کد',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isOTPComplete
                              ? Colors.white
                              : isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.check_circle_rounded,
                        color: isOTPComplete
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
  }

  Widget _buildResendSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          'کد را دریافت نکردید؟',
          style: TextStyle(
            fontSize: 16.sp,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: _canResend ? _resendOTP : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: _canResend
                  ? const Color(0xFF4A80F0).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color:
                    _canResend ? const Color(0xFF4A80F0) : Colors.transparent,
              ),
            ),
            child: Text(
              _canResend ? 'ارسال مجدد کد' : 'ارسال مجدد در $_countdown ثانیه',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _canResend
                    ? const Color(0xFF4A80F0)
                    : isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withOpacity(0.2)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.orange.shade700.withOpacity(0.3)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.orange.shade600,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'کد تأیید فقط ۵ دقیقه معتبر است',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
