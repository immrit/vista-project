import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PasswordAuthScreen extends StatefulWidget {
  final String emailOrUsername;
  final String password;
  final Function(String) onPasswordChanged;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  final VoidCallback onForgotPassword;
  final bool isLoading;

  const PasswordAuthScreen({
    super.key,
    required this.emailOrUsername,
    required this.password,
    required this.onPasswordChanged,
    required this.onLogin,
    required this.onBack,
    required this.onForgotPassword,
    required this.isLoading,
  });

  @override
  State<PasswordAuthScreen> createState() => _PasswordAuthScreenState();
}

class _PasswordAuthScreenState extends State<PasswordAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isPasswordValid = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _passwordController.text = widget.password;
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
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _validatePassword(String password) {
    setState(() {
      _isPasswordValid = password.length >= 6;
    });
    widget.onPasswordChanged(password);
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
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
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
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
                        Icons.lock_rounded,
                        size: 50.sp,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 40.h),
              
              // Title and Description
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Column(
                      children: [
                        Text(
                          'رمز عبور خود را وارد کنید',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'برای ${widget.emailOrUsername}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              SizedBox(height: 60.h),
              
              // Password Input
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.5),
                    child: _buildPasswordInput(),
                  );
                },
              ),
              
              SizedBox(height: 20.h),
              
              // Forgot Password
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.4),
                    child: _buildForgotPasswordButton(),
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
                child: _buildLoginButton(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _isPasswordValid 
              ? const Color(0xFF4A80F0)
              : isDark 
                  ? Colors.grey.shade700 
                  : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: _isPasswordValid ? [
          BoxShadow(
            color: const Color(0xFF4A80F0).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: TextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        obscureText: !_isPasswordVisible,
        onChanged: _validatePassword,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'رمز عبور',
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
            onTap: _togglePasswordVisibility,
            child: Icon(
              _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onForgotPassword,
        child: Text(
          'فراموشی رمز عبور؟',
          style: TextStyle(
            fontSize: 16.sp,
            color: const Color(0xFF4A80F0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: _isPasswordValid && !widget.isLoading
            ? const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _isPasswordValid && !widget.isLoading
            ? null
            : isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        boxShadow: _isPasswordValid && !widget.isLoading ? [
          BoxShadow(
            color: const Color(0xFF4A80F0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _isPasswordValid && !widget.isLoading ? widget.onLogin : null,
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
                        'ورود',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: _isPasswordValid
                              ? Colors.white
                              : isDark 
                                  ? Colors.grey.shade500 
                                  : Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.login_rounded,
                        color: _isPasswordValid
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

  Widget _buildSecurityNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.green.shade900.withOpacity(0.2)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark 
              ? Colors.green.shade700.withOpacity(0.3)
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security_rounded,
            color: Colors.green.shade600,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'رمز عبور شما با رمزنگاری پیشرفته محافظت می‌شود',
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
