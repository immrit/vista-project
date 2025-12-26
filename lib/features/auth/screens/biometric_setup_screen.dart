import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/advanced_security_service.dart';

class BiometricSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const BiometricSetupScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  List<String> _availableBiometrics = [];
  String _biometricTypeName = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricAvailability();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    setState(() => _isLoading = true);

    try {
      final isAvailable = await AdvancedSecurityService.isBiometricAvailable();
      if (isAvailable) {
        final biometrics =
            await AdvancedSecurityService.getAvailableBiometrics();
        setState(() {
          _isBiometricAvailable = true;
          _availableBiometrics = biometrics;
          _biometricTypeName = _getBiometricTypeName(biometrics);
        });
      } else {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getBiometricTypeName(List<String> biometrics) {
    if (biometrics.contains('face')) {
      return 'Face ID';
    } else if (biometrics.contains('fingerprint')) {
      return 'Touch ID';
    } else if (biometrics.contains('iris')) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  Future<void> _enableBiometric() async {
    setState(() => _isLoading = true);

    try {
      final success = await AdvancedSecurityService.enableBiometric();
      if (success) {
        _showSuccessSnackBar('احراز هویت بیومتریک فعال شد');
        widget.onComplete();
      } else {
        _showErrorSnackBar('فعال‌سازی احراز هویت بیومتریک ناموفق بود');
      }
    } catch (e) {
      _showErrorSnackBar('خطا در فعال‌سازی: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),

              // Header
              Row(
                children: [
                  Text(
                    'امنیت پیشرفته',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 60.h),

              // Animated Icon
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF4A80F0),
                            const Color(0xFF6B9EFF),
                            const Color(0xFF8BB5FF),
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
                        _getBiometricIcon(),
                        size: 60.sp,
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
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Text(
                        'احراز هویت بیومتریک',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        _isBiometricAvailable
                            ? 'برای امنیت بیشتر، احراز هویت $_biometricTypeName را فعال کنید'
                            : 'احراز هویت بیومتریک در این دستگاه پشتیبانی نمی‌شود',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 60.h),

              // Features List
              if (_isBiometricAvailable) ...[
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFeaturesList(),
                ),
                SizedBox(height: 60.h),
              ],

              // Action Buttons
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildActionButtons(),
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
        ),
      ),
    );
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains('face')) {
      return Icons.face_rounded;
    } else if (_availableBiometrics.contains('fingerprint')) {
      return Icons.fingerprint_rounded;
    } else if (_availableBiometrics.contains('iris')) {
      return Icons.visibility_rounded;
    } else {
      return Icons.security_rounded;
    }
  }

  Widget _buildFeaturesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final features = [
      'ورود سریع و آسان',
      'امنیت بالای اطلاعات',
      'محافظت از حریم خصوصی',
      'دسترسی آسان به برنامه',
    ];

    return Column(
      children: features
          .map((feature) => Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4A80F0),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFF4A80F0),
                      size: 20.sp,
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isBiometricAvailable) {
      return Column(
        children: [
          // Skip Button
          Container(
            width: double.infinity,
            height: 56.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: widget.onSkip,
                child: Center(
                  child: Text(
                    'ادامه',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Enable Biometric Button
        Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A80F0), Color(0xFF6B9EFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A80F0).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.r),
              onTap: _isLoading ? null : _enableBiometric,
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getBiometricIcon(),
                            color: Colors.white,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'فعال‌سازی $_biometricTypeName',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Skip Button
        Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.r),
              onTap: widget.onSkip,
              child: Center(
                child: Text(
                  'رد کردن',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                ),
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
            ? Colors.blue.shade900.withOpacity(0.2)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.blue.shade700.withOpacity(0.3)
              : Colors.blue.shade200,
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
              'احراز هویت بیومتریک اختیاری است و می‌توانید بعداً آن را فعال یا غیرفعال کنید',
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
