// lib/features/chat/widgets/improved_floating_date_header.dart
//
// هدر تاریخ شناور با انیمیشن‌های بهبود یافته
//

import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';

class ImprovedFloatingDateHeader extends StatefulWidget {
  final Widget child;
  final DateTime? currentDate;
  final bool isScrolling;
  final Duration showDuration;
  final Duration fadeDuration;

  const ImprovedFloatingDateHeader({
    super.key,
    required this.child,
    this.currentDate,
    this.isScrolling = false,
    this.showDuration = const Duration(seconds: 2),
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ImprovedFloatingDateHeader> createState() =>
      _ImprovedFloatingDateHeaderState();
}

class _ImprovedFloatingDateHeaderState extends State<ImprovedFloatingDateHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: widget.fadeDuration,
      vsync: this,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Slide from top animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Scale animation (zoom in effect)
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // Blur animation
    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(ImprovedFloatingDateHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // وقتی شروع به اسکرول می‌کنیم یا تاریخ تغییر می‌کند
    if (widget.isScrolling && !oldWidget.isScrolling) {
      _controller.forward();
    }
    // وقتی اسکرول متوقف می‌شود
    else if (!widget.isScrolling && oldWidget.isScrolling) {
      Future.delayed(widget.showDuration, () {
        if (mounted && !widget.isScrolling) {
          _controller.reverse();
        }
      });
    }
    // اگر تاریخ تغییر کرد
    else if (widget.currentDate != oldWidget.currentDate &&
        widget.currentDate != null) {
      _controller.forward();
      Future.delayed(widget.showDuration, () {
        if (mounted && !widget.isScrolling) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Stack(
      children: [
        // محتوای اصلی (لیست پیام‌ها)
        widget.child,

        // هدر تاریخ شناور
        if (widget.currentDate != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (_fadeAnimation.value == 0.0) {
                  return const SizedBox.shrink();
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Center(
                        child: _FloatingDateBadge(
                          date: widget.currentDate!,
                          theme: theme,
                          blurIntensity: _blurAnimation.value,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// نشان تاریخ شناور
class _FloatingDateBadge extends StatelessWidget {
  final DateTime date;
  final ChatTheme theme;
  final double blurIntensity;

  const _FloatingDateBadge({
    required this.date,
    required this.theme,
    required this.blurIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity,
            sigmaY: blurIntensity,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: theme.isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  date.toFloatingDateLabel(),
                  style: TextStyle(
                    color: theme.isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
