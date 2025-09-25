import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class EmailUsernameAuthScreen extends StatefulWidget {
  final String emailOrUsername;
  final Function(String) onEmailOrUsernameChanged;
  final VoidCallback onContinue;
  final bool isLoading;

  const EmailUsernameAuthScreen({
    super.key,
    required this.emailOrUsername,
    required this.onEmailOrUsernameChanged,
    required this.onContinue,
    required this.isLoading,
  });

  @override
  State<EmailUsernameAuthScreen> createState() =>
      _EmailUsernameAuthScreenState();
}

class _EmailUsernameAuthScreenState extends State<EmailUsernameAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final TextEditingController _emailOrUsernameController =
      TextEditingController();
  final FocusNode _emailOrUsernameFocus = FocusNode();

  bool _isEmailOrUsernameValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _emailOrUsernameController.text = widget.emailOrUsername;
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
      end: 1.1,
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
    _emailOrUsernameController.dispose();
    _emailOrUsernameFocus.dispose();
    super.dispose();
  }

  void _validateEmailOrUsername(String emailOrUsername) {
    setState(() {
      _isEmailOrUsernameValid = emailOrUsername.isNotEmpty &&
          (emailOrUsername.contains('@') || emailOrUsername.length >= 3);
    });
    widget.onEmailOrUsernameChanged(emailOrUsername);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 60.h),

              // Logo with animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80F0).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'lib/view/util/images/component/login.png',
                          width: 120.w,
                          height: 120.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),

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
                          'ایمیل یا نام کاربری خود را وارد کنید',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'برای ورود به حساب کاربری خود',
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

              SizedBox(height: 60.h),

              // Email/Username Input
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.5),
                    child: _buildEmailUsernameInput(),
                  );
                },
              ),

              SizedBox(height: 40.h),

              // Security Note
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.2),
                    child: _buildSecurityNote(),
                  );
                },
              ),

              SizedBox(height: 100.h), // Space for bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 0.3),
                child: _buildContinueButton(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmailUsernameInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _isEmailOrUsernameValid
              ? const Color(0xFF4A80F0)
              : isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: _isEmailOrUsernameValid
            ? [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _emailOrUsernameController,
        focusNode: _emailOrUsernameFocus,
        keyboardType: TextInputType.emailAddress,
        onChanged: _validateEmailOrUsername,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'ایمیل یا نام کاربری',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            fontSize: 16.sp,
          ),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
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

  Widget _buildContinueButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: _isEmailOrUsernameValid && !widget.isLoading
            ? const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _isEmailOrUsernameValid && !widget.isLoading
            ? null
            : isDark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
        boxShadow: _isEmailOrUsernameValid && !widget.isLoading
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
          onTap: _isEmailOrUsernameValid && !widget.isLoading
              ? widget.onContinue
              : null,
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
                        'ادامه',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: _isEmailOrUsernameValid && !widget.isLoading
                              ? Colors.white
                              : isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16.sp,
                        color: _isEmailOrUsernameValid && !widget.isLoading
                            ? Colors.white
                            : isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security_rounded,
            color: const Color(0xFF4A80F0),
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'اطلاعات شما با بالاترین استانداردهای امنیتی محافظت می‌شود',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
