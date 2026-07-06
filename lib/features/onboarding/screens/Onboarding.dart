import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../../../services/onboarding_service.dart';
import 'package:Vista/core/theme/app_theme.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _mainAnimationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _particleAnimationController;
  late AnimationController _textAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;

  int _currentPage = 0;
  final int _totalPages = 6;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'ویستا',
      subtitle: 'شبکه اجتماعی پیشرفته',
      description: 'پلتفرم جامع برای ارتباط، اشتراک‌گذاری و تعامل اجتماعی',
      primaryColor: const Color(0xFF0088CC),
      secondaryColor: const Color(0xFF00A8E8),
      features: [
        'پست‌های عمومی و خصوصی',
        'سیستم استوری',
        'چت و پیام‌رسانی',
        'پروفایل شخصی',
      ],
      illustration: OnboardingIllustration.social,
    ),
    OnboardingSlide(
      title: 'اشتراک‌گذاری محتوا',
      subtitle: 'هر آنچه می‌خواهید به اشتراک بگذارید',
      description:
          'تصاویر، ویدیوها، موزیک و متن را با دوستان خود به اشتراک بگذارید',
      primaryColor: AppColors.success,
      secondaryColor: const Color(0xFF8BC34A),
      features: [
        'آپلود تصاویر و ویدیو',
        'اشتراک‌گذاری موزیک',
        'کامنت و لایک',
        'اشتراک‌گذاری هوشمند',
      ],
      illustration: OnboardingIllustration.content,
    ),
    OnboardingSlide(
      title: 'استوری و موزیک',
      subtitle: 'محتوای زنده و موزیک',
      description: 'استوری‌های 24 ساعته و پخش‌کننده موزیک پیشرفته',
      primaryColor: AppColors.secondary,
      secondaryColor: AppColors.accent,
      features: [
        'استوری‌های تعاملی',
        'پخش‌کننده موزیک',
        'دانلود آهنگ',
        'اشتراک‌گذاری موزیک',
      ],
      illustration: OnboardingIllustration.story,
    ),
    OnboardingSlide(
      title: 'امنیت و حریم خصوصی',
      subtitle: 'حفاظت کامل از اطلاعات شما',
      description: 'حساب‌های خصوصی، رمزگذاری پیشرفته و کنترل حریم خصوصی',
      primaryColor: const Color(0xFFFF5722),
      secondaryColor: AppColors.warning,
      features: [
        'حساب‌های خصوصی',
        'رمزگذاری End-to-End',
        'مسدودسازی کاربران',
        'قفل اپلیکیشن',
      ],
      illustration: OnboardingIllustration.security,
    ),
    OnboardingSlide(
      title: 'عملکرد فوق‌العاده',
      subtitle: 'سرعت و کیفیت در اولویت',
      description: 'کش هوشمند، همگام‌سازی لحظه‌ای و عملکرد بهینه',
      primaryColor: const Color(0xFF3F51B5),
      secondaryColor: AppColors.info,
      features: [
        'کش آفلاین',
        'همگام‌سازی هوشمند',
        'عملکرد بهینه',
        'پشتیبانی چندپلتفرمه',
      ],
      illustration: OnboardingIllustration.performance,
    ),
    OnboardingSlide(
      title: 'آماده شروع',
      subtitle: 'به جامعه ویستا بپیوندید',
      description:
          'همین حالا ثبت نام کنید و از تمام قابلیت‌های شبکه اجتماعی ویستا لذت ببرید',
      primaryColor: AppColors.warning,
      secondaryColor: const Color(0xFFFFC107),
      features: [
        'ثبت نام رایگان',
        'دسترسی فوری',
        'جامعه فعال',
        'پشتیبانی 24/7',
      ],
      illustration: OnboardingIllustration.ready,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _floatingAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _particleAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_floatingAnimationController);

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleAnimationController);

    _textSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _startAnimations();
  }

  void _startAnimations() {
    _mainAnimationController.forward();
    _textAnimationController.forward();
    _floatingAnimationController.repeat(reverse: true);
    _particleAnimationController.repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mainAnimationController.dispose();
    _floatingAnimationController.dispose();
    _particleAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToAuth();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _navigateToAuth() async {
    // علامت‌گذاری onboarding به عنوان تکمیل شده
    await OnboardingService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth');
  }

  void _skipOnboarding() async {
    // Skip هم یعنی «دیدم، دیگر نشان نده» — بدون mark، در اجرای بعدی دوباره
    // onboarding می‌آمد.
    await OnboardingService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSlide = _slides[_currentPage];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentSlide.primaryColor.withValues(alpha: 0.1),
              currentSlide.secondaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isDark, currentSlide),

              // Progress Indicator
              _buildProgressIndicator(isDark, currentSlide),

              const SizedBox(height: 20),

              // Main Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _restartAnimations();
                  },
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    return _buildSlide(_slides[index], isDark);
                  },
                ),
              ),

              // Navigation
              _buildNavigation(isDark, currentSlide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, OnboardingSlide slide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [slide.primaryColor, slide.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: slide.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.rocket_launch, color: Colors.white, size: 24.sp),
          ),

          // Skip Button
          TextButton(
            onPressed: _skipOnboarding,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              'رد کردن',
              style: TextStyle(
                color: slide.primaryColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark, OnboardingSlide slide) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: List.generate(_totalPages, (index) {
          final isActive = index == _currentPage;
          final isCompleted = index < _currentPage;

          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              height: 4.h,
              decoration: BoxDecoration(
                color: isActive || isCompleted
                    ? slide.primaryColor
                    : (isDark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),

              // Illustration
              SizedBox(height: 300.h, child: _buildIllustration(slide)),

              SizedBox(height: 30.h),

              // Text Content
              _buildTextContent(slide, isDark),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(OnboardingSlide slide) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Particles
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(300.w, 300.h),
                painter: ParticleBackgroundPainter(
                  animation: _particleAnimation.value,
                  primaryColor: slide.primaryColor,
                  secondaryColor: slide.secondaryColor,
                ),
              );
            },
          ),

          // Main Illustration
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(_floatingAnimation.value * math.pi * 2) * 10,
                ),
                child: _buildMainIllustration(slide),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainIllustration(OnboardingSlide slide) {
    switch (slide.illustration) {
      case OnboardingIllustration.social:
        return _buildSocialIllustration(slide);
      case OnboardingIllustration.content:
        return _buildContentIllustration(slide);
      case OnboardingIllustration.story:
        return _buildStoryIllustration(slide);
      case OnboardingIllustration.security:
        return _buildSecurityIllustration(slide);
      case OnboardingIllustration.performance:
        return _buildPerformanceIllustration(slide);
      case OnboardingIllustration.ready:
        return _buildReadyIllustration(slide);
    }
  }

  Widget _buildSocialIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Network/People Icon
          Icon(Icons.people, size: 80.sp, color: Colors.white),

          // Chat Bubble
          Positioned(
            bottom: 30.h,
            right: 30.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble,
                size: 20.sp,
                color: slide.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Share Icon
          Icon(Icons.share, size: 80.sp, color: Colors.white),

          // Content Icons around the share
          ...List.generate(4, (index) {
            final angle = (index * math.pi * 2 / 4);
            final icons = [
              Icons.image,
              Icons.videocam,
              Icons.music_note,
              Icons.text_fields,
            ];
            return Positioned(
              top: 50.h + math.sin(angle) * 60.h,
              left: 50.w + math.cos(angle) * 60.w,
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icons[index],
                  size: 16.sp,
                  color: slide.primaryColor,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStoryIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Story/Circle Icon
          Icon(Icons.auto_stories, size: 80.sp, color: Colors.white),

          // Music Note
          Positioned(
            bottom: 30.h,
            right: 30.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.music_note,
                size: 20.sp,
                color: slide.primaryColor,
              ),
            ),
          ),

          // Play Button
          Positioned(
            top: 30.h,
            left: 30.w,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow,
                size: 16.sp,
                color: slide.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shield with Check
          Icon(Icons.verified_user, size: 80.sp, color: Colors.white),

          // Encryption Symbol
          Positioned(
            top: 30.h,
            left: 30.w,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.vpn_key,
                size: 16.sp,
                color: slide.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Speed/Performance Icon
          Icon(Icons.speed, size: 80.sp, color: Colors.white),

          // Cloud Icon
          Positioned(
            bottom: 30.h,
            right: 30.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.cloud_done,
                size: 20.sp,
                color: slide.primaryColor,
              ),
            ),
          ),

          // Cache Icon
          Positioned(
            top: 30.h,
            left: 30.w,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.storage,
                size: 16.sp,
                color: slide.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyIllustration(OnboardingSlide slide) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.primaryColor, slide.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: slide.primaryColor.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rocket Icon
          Icon(Icons.rocket_launch, size: 80.sp, color: Colors.white),

          // Stars
          ...List.generate(4, (index) {
            final angle = (index * math.pi * 2 / 4);
            return Positioned(
              top: 50.h + math.sin(angle) * 60.h,
              left: 50.w + math.cos(angle) * 60.w,
              child: Icon(
                Icons.star,
                size: 12.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextContent(OnboardingSlide slide, bool isDark) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_textSlideAnimation),
      child: FadeTransition(
        opacity: _textFadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [slide.primaryColor, slide.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                slide.title,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(height: 12.h),

            // Subtitle
            Text(
              slide.subtitle,
              style: TextStyle(
                fontSize: 18.sp,
                color: slide.primaryColor,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 8.h),

            // Description
            Text(
              slide.description,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 16.h),

            // Features
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              alignment: WrapAlignment.center,
              children: slide.features.map((feature) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: slide.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: slide.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: slide.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(bool isDark, OnboardingSlide slide) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
      child: Row(
        children: [
          // Previous Button
          if (_currentPage > 0)
            Expanded(
              child: Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: slide.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: slide.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _previousPage,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Center(
                      child: Text(
                        'قبلی',
                        style: TextStyle(
                          color: slide.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_currentPage > 0) SizedBox(width: 12.w),

          // Next/Get Started Button
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [slide.primaryColor, slide.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: slide.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _nextPage,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Center(
                    child: Text(
                      _currentPage == _totalPages - 1 ? 'شروع کنید' : 'بعدی',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _restartAnimations() {
    _mainAnimationController.reset();
    _textAnimationController.reset();
    _mainAnimationController.forward();
    _textAnimationController.forward();
  }
}

class ParticleBackgroundPainter extends CustomPainter {
  final double animation;
  final Color primaryColor;
  final Color secondaryColor;

  ParticleBackgroundPainter({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Draw floating particles
    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi * 2 / 12) + (animation * math.pi * 2);
      final distance =
          radius * 0.8 + (math.sin(animation * math.pi * 2 + i) * 30);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final paint = Paint()
        ..color = (i % 2 == 0 ? primaryColor : secondaryColor).withValues(
          alpha: 0.3 + math.sin(animation * math.pi * 2 + i) * 0.2,
        )
        ..style = PaintingStyle.fill;

      final particleSize = 4 + (math.sin(animation * math.pi * 2 + i) * 2);
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }

    // Draw connecting lines
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angle1 = (i * math.pi * 2 / 12) + (animation * math.pi * 2);
      final angle2 = ((i + 1) * math.pi * 2 / 12) + (animation * math.pi * 2);

      final distance1 =
          radius * 0.8 + (math.sin(animation * math.pi * 2 + i) * 30);
      final distance2 =
          radius * 0.8 + (math.sin(animation * math.pi * 2 + i + 1) * 30);

      final x1 = center.dx + math.cos(angle1) * distance1;
      final y1 = center.dy + math.sin(angle1) * distance1;
      final x2 = center.dx + math.cos(angle2) * distance2;
      final y2 = center.dy + math.sin(angle2) * distance2;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OnboardingSlide {
  final String title;
  final String subtitle;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> features;
  final OnboardingIllustration illustration;

  OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.features,
    required this.illustration,
  });
}

enum OnboardingIllustration {
  social,
  content,
  story,
  security,
  performance,
  ready,
}
