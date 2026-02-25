import 'package:flutter/material.dart';
import 'dart:math' as math;

class VistaAboutSlideshow extends StatefulWidget {
  const VistaAboutSlideshow({super.key});

  @override
  State<VistaAboutSlideshow> createState() => _VistaAboutSlideshowState();
}

class _VistaAboutSlideshowState extends State<VistaAboutSlideshow>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late AnimationController _particleAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<double> _particleAnimation;

  int _currentPage = 0;
  final int _totalPages = 6;

  final List<SlideData> _slides = [
    SlideData(
      title: 'به ویستا خوش آمدید',
      subtitle: 'پلتفرم اجتماعی پیشرفته و امن',
      description: 'چت، اشتراک‌گذاری، استوری، موزیک',
      icon: Icons.rocket_launch,
      color: const Color(0xFF2196F3),
      gradient: const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        'چت و پیام‌رسانی پیشرفته',
        'اشتراک‌گذاری محتوا',
        'سیستم استوری',
        'پخش‌کننده موزیک',
      ],
    ),
    SlideData(
      title: 'امنیت در اولویت',
      subtitle: 'رمزگذاری End-to-End',
      description: 'حفاظت کامل از اطلاعات شما',
      icon: Icons.security,
      color: const Color(0xFF4CAF50),
      gradient: const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        'رمزگذاری End-to-End',
        'تایید دو مرحله‌ای',
        'قفل اپلیکیشن',
        'مسدودسازی کاربران',
      ],
    ),
    SlideData(
      title: 'تحت ابر قدرتمند',
      subtitle: 'زیرساخت ابری پیشرفته',
      description: '۹۹.۹٪ زمان کارکرد تضمین شده',
      icon: Icons.cloud,
      color: const Color(0xFF9C27B0),
      gradient: const LinearGradient(
        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        'زیرساخت AWS',
        'پشتیبان‌گیری خودکار',
        'مقیاس‌پذیری بالا',
        'CDN جهانی',
      ],
    ),
    SlideData(
      title: 'عملکرد فوق‌العاده',
      subtitle: 'بهینه‌سازی شده برای سرعت',
      description: 'کاهش ۸۵٪ مصرف حافظه',
      icon: Icons.speed,
      color: const Color(0xFFFF9800),
      gradient: const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        'کاهش ۸۵٪ مصرف حافظه',
        'کاهش ۶۰٪ مصرف CPU',
        'سیستم کش هوشمند',
        'مدیریت حافظه پیشرفته',
      ],
    ),
    SlideData(
      title: 'سرعت فوق‌العاده',
      subtitle: 'بهینه‌سازی شده برای عملکرد',
      description: 'تجربه‌ای روان و سریع',
      icon: Icons.offline_bolt,
      color: const Color(0xFF607D8B),
      gradient: const LinearGradient(
        colors: [Color(0xFF607D8B), Color(0xFF90A4AE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        'کش آفلاین کامل',
        'همگام‌سازی هوشمند',
        'دسترسی به پیام‌ها',
        'مشاهده پست‌ها',
      ],
    ),
    SlideData(
      title: 'آمار و دستاوردها',
      subtitle: 'تایید شده توسط کاربران',
      description: '۱۰۰,۰۰۰+ کاربر فعال',
      icon: Icons.emoji_events,
      color: const Color(0xFFE91E63),
      gradient: const LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFFF06292)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      features: [
        '۱۰۰,۰۰۰+ کاربر فعال',
        'امتیاز ۴.۸ از ۵',
        'بهترین اپ سال',
        'پشتیبانی ۲۴/۷',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _particleAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.elasticOut,
    ));

    _iconRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOut,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleAnimationController);

    _animationController.forward();
    _iconAnimationController.forward();
    _particleAnimationController.repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _iconAnimationController.dispose();
    _particleAnimationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
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
          child: Column(
            children: [
              // Header with glassmorphism
              Container(
                margin: const EdgeInsets.all(20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _slides[_currentPage].color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.close,
                        color: _slides[_currentPage].color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'درباره ویستا',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _slides[_currentPage].color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentPage + 1}/$_totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Enhanced Progress Indicator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / _totalPages,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _slides[_currentPage].color,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Page View with enhanced animations
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _animationController.reset();
                    _iconAnimationController.reset();
                    _animationController.forward();
                    _iconAnimationController.forward();
                  },
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    return _buildEnhancedSlide(_slides[index], isDark);
                  },
                ),
              ),

              // Enhanced Navigation
              Container(
                margin: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  _slides[_currentPage].color.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _slides[_currentPage]
                                    .color
                                    .withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _previousPage,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Text(
                                  'قبلی',
                                  style: TextStyle(
                                    color: _slides[_currentPage].color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: _currentPage == 0 ? 1 : 1,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _slides[_currentPage].gradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _slides[_currentPage].color.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _nextPage,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Text(
                                _currentPage == _totalPages - 1
                                    ? 'تمام'
                                    : 'بعدی',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSlide(SlideData slide, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced Icon with particles
              Stack(
                alignment: Alignment.center,
                children: [
                  // Particle effects
                  AnimatedBuilder(
                    animation: _particleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: ParticlePainter(
                          animation: _particleAnimation.value,
                          color: slide.color,
                        ),
                      );
                    },
                  ),
                  // Main icon container
                  ScaleTransition(
                    scale: _iconScaleAnimation,
                    child: RotationTransition(
                      turns: _iconRotationAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: slide.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: slide.color.withOpacity(0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Icon(
                          slide.icon,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Enhanced Title
              ShaderMask(
                shaderCallback: (bounds) => slide.gradient.createShader(bounds),
                child: Text(
                  slide.title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Subtitle - بدون کادر
              Text(
                slide.subtitle,
                style: TextStyle(
                  fontSize: 18,
                  color: slide.color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double animation;
  final Color color;

  ParticlePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2 / 8) + (animation * math.pi * 2);
      final distance =
          radius * 0.7 + (math.sin(animation * math.pi * 2 + i) * 20);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final particleSize = 3 + (math.sin(animation * math.pi * 2 + i) * 2);
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SlideData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final List<String> features;

  SlideData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.features,
  });
}
