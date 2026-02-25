import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/advanced_security_service.dart';

class BiometricLoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFallback;

  const BiometricLoginScreen({
    super.key,
    required this.onSuccess,
    required this.onFallback,
  });

  @override
  ConsumerState<BiometricLoginScreen> createState() =>
      _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends ConsumerState<BiometricLoginScreen>
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
    try {
      final isAvailable = await AdvancedSecurityService.isBiometricAvailable();
      final isEnabled = await AdvancedSecurityService.isBiometricEnabled();

      if (isAvailable && isEnabled) {
        final biometrics =
            await AdvancedSecurityService.getAvailableBiometrics();
        setState(() {
          _isBiometricAvailable = true;
          _availableBiometrics = biometrics;
          _biometricTypeName = _getBiometricTypeName(biometrics);
        });

        // Auto-trigger biometric authentication
        Future.delayed(const Duration(milliseconds: 1500), () {
          _authenticateWithBiometric();
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

  Future<void> _authenticateWithBiometric() async {
    if (!_isBiometricAvailable) return;

    setState(() => _isLoading = true);

    try {
      final success = await AdvancedSecurityService.authenticateWithBiometric();
      if (success) {
        _showSuccessSnackBar('احراز هویت موفق');
        widget.onSuccess();
      } else {
        _showErrorSnackBar('احراز هویت ناموفق');
      }
    } catch (e) {
      _showErrorSnackBar('خطا در احراز هویت: ${e.toString()}');
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
              SizedBox(height: 60.h),

              // App Logo/Title
              Text(
                'Vista',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A80F0),
                ),
              ),

              SizedBox(height: 80.h),

              // Animated Biometric Icon
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
                        _isBiometricAvailable
                            ? 'احراز هویت $_biometricTypeName'
                            : 'احراز هویت بیومتریک غیرفعال',
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
                            ? 'برای ورود به برنامه، $_biometricTypeName خود را تأیید کنید'
                            : 'احراز هویت بیومتریک در این دستگاه فعال نیست',
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

              // Loading Indicator or Action Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: _isLoading
                    ? Column(
                        children: [
                          SizedBox(
                            width: 40.w,
                            height: 40.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF4A80F0),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'در حال احراز هویت...',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      )
                    : _isBiometricAvailable
                        ? _buildBiometricButton()
                        : _buildFallbackButton(),
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

  Widget _buildBiometricButton() {
    return Container(
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
          onTap: _authenticateWithBiometric,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getBiometricIcon(),
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'احراز هویت $_biometricTypeName',
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
    );
  }

  Widget _buildFallbackButton() {
    return Column(
      children: [
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
              onTap: widget.onFallback,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'ورود با رمز عبور',
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
        GestureDetector(
          onTap: () async {
            // Try to enable biometric
            final success = await AdvancedSecurityService.enableBiometric();
            if (success) {
              _checkBiometricAvailability();
            }
          },
          child: Text(
            'فعال‌سازی احراز هویت بیومتریک',
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF4A80F0),
              fontWeight: FontWeight.w600,
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
              'اطلاعات شما با بالاترین استانداردهای امنیتی محافظت می‌شود',
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
