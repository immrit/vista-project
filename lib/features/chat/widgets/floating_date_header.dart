// lib/features/chat/widgets/floating_date_header.dart
//
// تاریخ شناور - با الهام از ویستا
//
// ویژگی‌ها:
// ✅ نمایش تاریخ هنگام اسکرول
// ✅ محو شدن با انیمیشن بعد از توقف اسکرول
// ✅ استایل یکسان با DateDivider
// ✅ هماهنگ با تم
//

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';
import 'date_divider.dart';

/// ویجت تاریخ شناور
class FloatingDateHeader extends StatefulWidget {
  final DateTime? currentDate;
  final bool isScrolling;

  /// Optional content placed behind the floating date chip. Leave null to use
  /// this widget as a standalone overlay (so the message list it floats over is
  /// not rebuilt whenever [isScrolling] / [currentDate] change).
  final Widget? child;

  const FloatingDateHeader({
    super.key,
    this.currentDate,
    required this.isScrolling,
    this.child,
  });

  @override
  State<FloatingDateHeader> createState() => _FloatingDateHeaderState();
}

class _FloatingDateHeaderState extends State<FloatingDateHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _hideTimer;
  bool _isVisible = false;
  DateTime? _displayedDate;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void didUpdateWidget(FloatingDateHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // تاریخ جدید - اگر تاریخ تغییر کرد، نمایش بده
    // If parent cleared the date, hide and clear displayed date to avoid
    // lingering "Today" when there are no messages.
    if (widget.currentDate == null && _displayedDate != null) {
      _displayedDate = null;
      _hideDate();
      return;
    }

    if (widget.currentDate != null && widget.currentDate != _displayedDate) {
      _displayedDate = widget.currentDate;
      // اگر تاریخ تغییر کرد، نمایش بده (مخصوصاً وقتی پیام جدید ارسال می‌شه)
      _showDate();
    }

    // شروع اسکرول - نمایش
    if (widget.isScrolling && !oldWidget.isScrolling) {
      _showDate();
    }

    // توقف اسکرول - شروع تایمر برای مخفی کردن
    if (!widget.isScrolling && oldWidget.isScrolling) {
      _startHideTimer();
    }

    // اگه در حال اسکرول هستیم، تایمر رو ریست کن
    if (widget.isScrolling) {
      _hideTimer?.cancel();
    }
  }

  void _showDate() {
    if (!_isVisible) {
      setState(() => _isVisible = true);
      _animationController.forward();
    }
    _hideTimer?.cancel();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !widget.isScrolling) {
        _hideDate();
      }
    });
  }

  void _hideDate() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // محاسبه ارتفاع نوار وضعیت + اپ‌بار
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Stack(
      children: [
        // ✅ محتوای اصلی (لیست پیام‌ها) — فقط وقتی به‌صورت wrapper استفاده شود
        // هیچ پدینگ یا تغییری به این نمی‌دهیم تا پشت اپ‌بار برود
        if (widget.child != null)
          Positioned.fill(
            child: widget.child!,
          ),

        // ✅ تاریخ شناور
        // فقط این را به پایین هل می‌دهیم
        if (_displayedDate != null)
          Positioned(
            top: topPadding + -50, // ارتفاع اپ‌بار + کمی فاصله
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  if (!_isVisible && _animationController.isDismissed) {
                    return const SizedBox.shrink();
                  }
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: _FloatingDateChip(date: _displayedDate!),
              ),
            ),
          ),
      ],
    );
  }
}

/// چیپ تاریخ شناور - استایل یکسان با DateDivider
class _FloatingDateChip extends StatelessWidget {
  final DateTime date;

  const _FloatingDateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DateChipStyle.horizontalPadding,
        vertical: DateChipStyle.verticalPadding,
      ),
      decoration: DateChipStyle.getDecoration(theme).copyWith(
        // فقط shadow برای شناور بودن
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        formatPersianDate(date),
        style: DateChipStyle.getTextStyle(theme),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 SCROLL POSITION NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// Controller برای مدیریت تاریخ شناور
class FloatingDateController extends ChangeNotifier {
  DateTime? _currentDate;
  bool _isScrolling = false;

  DateTime? get currentDate => _currentDate;
  bool get isScrolling => _isScrolling;

  void updateDate(DateTime date) {
    if (_currentDate != date) {
      _currentDate = date;
      notifyListeners();
    }
  }

  void setScrolling(bool scrolling) {
    if (_isScrolling != scrolling) {
      _isScrolling = scrolling;
      notifyListeners();
    }
  }
}

/// Wrapper برای استفاده راحت‌تر
class FloatingDateScrollWrapper extends StatefulWidget {
  final ScrollController scrollController;
  final List<DateTime> messageDates;
  final Widget child;

  const FloatingDateScrollWrapper({
    super.key,
    required this.scrollController,
    required this.messageDates,
    required this.child,
  });

  @override
  State<FloatingDateScrollWrapper> createState() =>
      _FloatingDateScrollWrapperState();
}

class _FloatingDateScrollWrapperState extends State<FloatingDateScrollWrapper> {
  bool _isScrolling = false;
  DateTime? _currentVisibleDate;
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _scrollEndTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // شروع اسکرول
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
    }

    // آپدیت تاریخ بر اساس موقعیت اسکرول
    _updateCurrentDate();

    // ریست تایمر پایان اسکرول
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isScrolling = false);
      }
    });
  }

  void _updateCurrentDate() {
    if (widget.messageDates.isEmpty) return;

    // تخمین ایندکس پیام قابل مشاهده
    final scrollOffset = widget.scrollController.offset;
    final itemHeight = 60.0; // تقریبی
    final visibleIndex = (scrollOffset / itemHeight).floor();

    if (visibleIndex >= 0 && visibleIndex < widget.messageDates.length) {
      final newDate = widget.messageDates[visibleIndex];
      if (_currentVisibleDate != newDate) {
        setState(() => _currentVisibleDate = newDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingDateHeader(
      currentDate: _currentVisibleDate,
      isScrolling: _isScrolling,
      child: widget.child,
    );
  }
}
