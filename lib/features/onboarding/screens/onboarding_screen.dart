import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/onboarding_service.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with TickerProviderStateMixin {
  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      kicker: 'به ویستا خوش آمدی',
      title: 'آدم‌ها را نزدیک‌تر ببین',
      description:
          'گفت‌وگو، پست و لحظه‌های واقعی؛ همه در فضایی ساخته‌شده برای ارتباط‌های معنادار.',
      assetPath: 'assets/images/onboarding/viu_connect.png',
      accent: Color(0xFF00A8D8),
      accentDeep: Color(0xFF0077B6),
      glow: Color(0xFF8CE5F5),
      imageScale: 1.23,
    ),
    _OnboardingSlide(
      kicker: 'برای هر لحظه',
      title: 'لحظه‌هایت را زنده کن',
      description:
          'از عکس و ویدیو تا استوری و موسیقی؛ خلاقیتت را ساده و با حال‌وهوای خودت به اشتراک بگذار.',
      assetPath: 'assets/images/onboarding/viu_create.png',
      accent: Color(0xFFFF7168),
      accentDeep: Color(0xFFE84F5E),
      glow: Color(0xFFFFC9B8),
      imageScale: 1.23,
    ),
    _OnboardingSlide(
      kicker: 'با خیال راحت',
      title: 'فضای تو، انتخاب تو',
      description:
          'حریم خصوصی و گفت‌وگوهای امن، با کنترل‌هایی که همیشه در دست خودت می‌مانند.',
      assetPath: 'assets/images/onboarding/viu_private.png',
      accent: Color(0xFF274C9B),
      accentDeep: Color(0xFF142E69),
      glow: Color(0xFF79DFF3),
      imageScale: 1.17,
    ),
  ];

  late final PageController _pageController;
  late final AnimationController _entranceController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  int _currentPage = 0;
  bool _isLeaving = false;
  bool _didPrecacheAssets = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.055),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();
    _floatingController.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didPrecacheAssets) {
      _didPrecacheAssets = true;
      for (final slide in _slides) {
        unawaited(precacheImage(AssetImage(slide.assetPath), context));
      }
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _floatingController
        ..stop()
        ..value = 0.5;
      _entranceController.value = 1;
    } else {
      _floatingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    if (_isLeaving) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _isLeaving = true);
    await OnboardingService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth');
  }

  void _nextPage() {
    if (_currentPage == _slides.length - 1) {
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousPage() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _currentPage = index);
    if (_reduceMotion) {
      _entranceController.value = 1;
    } else {
      _entranceController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slide = _slides[_currentPage];
    final background =
        isDark ? const Color(0xFF071018) : const Color(0xFFF7FBFD);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: AnimatedContainer(
          duration:
              _reduceMotion ? Duration.zero : const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.85, -0.75),
              radius: 1.45,
              colors: [
                slide.glow.withValues(alpha: isDark ? 0.12 : 0.24),
                background,
                background,
              ],
              stops: const [0, 0.52, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _OnboardingHeader(
                  accent: slide.accent,
                  isDark: isDark,
                  onSkip: _isLeaving ? null : _finishOnboarding,
                ),
                _ProgressRail(
                  currentPage: _currentPage,
                  totalPages: _slides.length,
                  accent: slide.accent,
                  isDark: isDark,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: _onPageChanged,
                    allowImplicitScrolling: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        slide: _slides[index],
                        pageNumber: index + 1,
                        totalPages: _slides.length,
                        isDark: isDark,
                        floatingController: _floatingController,
                        fadeAnimation: _fadeAnimation,
                        slideAnimation: _slideAnimation,
                      );
                    },
                  ),
                ),
                _NavigationBar(
                  currentPage: _currentPage,
                  totalPages: _slides.length,
                  slide: slide,
                  isDark: isDark,
                  isLoading: _isLeaving,
                  onBack: _previousPage,
                  onNext: _nextPage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.accent,
    required this.isDark,
    required this.onSkip,
  });

  final Color accent;
  final bool isDark;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(22.w, 10.h, 22.w, 10.h),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF071D2E),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 18.r,
                  offset: Offset(0, 7.h),
                ),
              ],
            ),
            child: Image.asset(
              'lib/utils/images/vistalogo-new.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VISTA',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF09243A),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  height: 1,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'دنیای نزدیک‌تر',
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF617484),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.white70 : const Color(0xFF355062),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              'رد کردن',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRail extends StatelessWidget {
  const _ProgressRail({
    required this.currentPage,
    required this.totalPages,
    required this.accent,
    required this.isDark,
  });

  final int currentPage;
  final int totalPages;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'مرحله ${currentPage + 1} از $totalPages',
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.w, 2.h, 24.w, 4.h),
        child: Row(
          children: List.generate(totalPages, (index) {
            final active = index <= currentPage;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                height: active ? 4.h : 3.h,
                margin: EdgeInsetsDirectional.only(
                    end: index == totalPages - 1 ? 0 : 7.w),
                decoration: BoxDecoration(
                  color: active
                      ? accent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFD9E4EA)),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: active && index == currentPage
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 8.r,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.slide,
    required this.pageNumber,
    required this.totalPages,
    required this.isDark,
    required this.floatingController,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  final _OnboardingSlide slide;
  final int pageNumber;
  final int totalPages;
  final bool isDark;
  final AnimationController floatingController;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label:
          '${slide.kicker}، ${slide.title}، مرحله $pageNumber از $totalPages',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 570.h;
          final stageHeight = math.min(
            compact ? 250.h : 330.h,
            constraints.maxHeight * (compact ? 0.54 : 0.58),
          );

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(22.w, 10.h, 22.w, 8.h),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 18.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: stageHeight,
                    child: _MascotStage(
                      slide: slide,
                      isDark: isDark,
                      animation: floatingController,
                    ),
                  ),
                  SizedBox(height: compact ? 14.h : 22.h),
                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: _SlideCopy(slide: slide, isDark: isDark),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MascotStage extends StatelessWidget {
  const _MascotStage({
    required this.slide,
    required this.isDark,
    required this.animation,
  });

  final _OnboardingSlide slide;
  final bool isDark;
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF0B1A25) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(34.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : slide.accent.withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: slide.accent.withValues(alpha: isDark ? 0.12 : 0.14),
            blurRadius: 30.r,
            offset: Offset(0, 14.h),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.88,
                colors: [
                  slide.glow.withValues(alpha: isDark ? 0.16 : 0.28),
                  slide.accent.withValues(alpha: isDark ? 0.05 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 215.w,
              height: 215.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: slide.accent.withValues(alpha: isDark ? 0.12 : 0.14),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.glow.withValues(alpha: isDark ? 0.06 : 0.1),
              ),
            ),
          ),
          PositionedDirectional(
            top: 22.h,
            end: 24.w,
            child: _DecorativeDot(color: slide.accent, size: 9.w),
          ),
          PositionedDirectional(
            bottom: 30.h,
            start: 28.w,
            child: _DecorativeDot(color: slide.glow, size: 13.w),
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final eased = Curves.easeInOut.transform(animation.value);
              return Transform.translate(
                offset: Offset(0, -4.h + (eased * 8.h)),
                child: Transform.rotate(
                  angle: (-0.006) + (eased * 0.012),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(22.w, 12.h, 22.w, 6.h),
              child: Transform.scale(
                scale: slide.imageScale,
                child: Image.asset(
                  slide.assetPath,
                  semanticLabel: 'تصویر شخصیت ویو برای ${slide.title}',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Container(
                        width: 112.w,
                        height: 112.w,
                        decoration: BoxDecoration(
                          color: slide.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  const _DecorativeDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide, required this.isDark});

  final _OnboardingSlide slide;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: slide.accent.withValues(alpha: isDark ? 0.13 : 0.09),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Text(
            slide.kicker,
            style: TextStyle(
              color: slide.accent,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: 11.h),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF09243A),
            fontSize: 26.sp,
            fontWeight: FontWeight.w900,
            height: 1.25,
            letterSpacing: -0.35,
          ),
        ),
        SizedBox(height: 9.h),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 330.w),
          child: Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF526A79),
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              height: 1.75,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.currentPage,
    required this.totalPages,
    required this.slide,
    required this.isDark,
    required this.isLoading,
    required this.onBack,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final _OnboardingSlide slide;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == totalPages - 1;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(22.w, 8.h, 22.w, 18.h),
      child: Row(
        children: [
          if (currentPage > 0) ...[
            SizedBox(
              height: 52.h,
              child: OutlinedButton(
                onPressed: isLoading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white70 : const Color(0xFF355062),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFD6E3E9),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17.r),
                  ),
                ),
                child: Text(
                  'قبلی',
                  style:
                      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
            child: Container(
              height: 52.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [slide.accent, slide.accentDeep],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(17.r),
                boxShadow: [
                  BoxShadow(
                    color: slide.accent.withValues(alpha: 0.28),
                    blurRadius: 18.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onNext,
                  borderRadius: BorderRadius.circular(17.r),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: isLoading
                          ? SizedBox(
                              key: const ValueKey('loading'),
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLast ? 'ورود به ویستا' : 'ادامه',
                              key: ValueKey(isLast),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                              ),
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
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.kicker,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.accent,
    required this.accentDeep,
    required this.glow,
    required this.imageScale,
  });

  final String kicker;
  final String title;
  final String description;
  final String assetPath;
  final Color accent;
  final Color accentDeep;
  final Color glow;
  final double imageScale;
}
