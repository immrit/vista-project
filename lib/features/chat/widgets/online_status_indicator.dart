// lib/features/chat/widgets/online_status_indicator.dart
//
// نشانگر وضعیت آنلاین - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ انیمیشن pulse برای آنلاین
// ✅ نمایش "آخرین بازدید"
// ✅ نمایش "در حال تایپ..." با انیمیشن
// ✅ انتقال روان بین وضعیت‌ها
//

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../theme/chat_theme.dart';

/// نوع وضعیت
enum UserStatus {
  online,
  offline,
  typing,
  recording,
  lastSeen,
}

/// نشانگر وضعیت کاربر
class OnlineStatusIndicator extends StatefulWidget {
  final UserStatus status;
  final DateTime? lastSeen;
  final bool showDot;
  final double dotSize;

  const OnlineStatusIndicator({
    super.key,
    required this.status,
    this.lastSeen,
    this.showDot = true,
    this.dotSize = 10,
  });

  @override
  State<OnlineStatusIndicator> createState() => _OnlineStatusIndicatorState();
}

class _OnlineStatusIndicatorState extends State<OnlineStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.status == UserStatus.online) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(OnlineStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == UserStatus.online && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.status != UserStatus.online) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDot) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.status == UserStatus.online
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: widget.status == UserStatus.online
                  ? [
                      BoxShadow(
                        color: _getStatusColor().withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case UserStatus.online:
        return const Color(0xFF4ADE80); // سبز
      case UserStatus.typing:
      case UserStatus.recording:
        return const Color(0xFF60A5FA); // آبی
      case UserStatus.offline:
      case UserStatus.lastSeen:
        return const Color(0xFF94A3B8); // خاکستری
    }
  }
}

/// متن وضعیت با انیمیشن
class OnlineStatusText extends StatefulWidget {
  final UserStatus status;
  final DateTime? lastSeen;
  final String? typingUserName;

  const OnlineStatusText({
    super.key,
    required this.status,
    this.lastSeen,
    this.typingUserName,
  });

  @override
  State<OnlineStatusText> createState() => _OnlineStatusTextState();
}

class _OnlineStatusTextState extends State<OnlineStatusText>
    with SingleTickerProviderStateMixin {
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    if (widget.status == UserStatus.typing) {
      _typingController.repeat();
    }
  }

  @override
  void didUpdateWidget(OnlineStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == UserStatus.typing && !_typingController.isAnimating) {
      _typingController.repeat();
    } else if (widget.status != UserStatus.typing) {
      _typingController.stop();
    }
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        _getStatusText(),
        key: ValueKey(widget.status.toString() + (widget.lastSeen?.toString() ?? '')),
        style: TextStyle(
          color: _getTextColor(theme),
          fontSize: 12,
          fontWeight: widget.status == UserStatus.online
              ? FontWeight.w500
              : FontWeight.normal,
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (widget.status) {
      case UserStatus.online:
        return 'آنلاین';
      case UserStatus.typing:
        return 'در حال نوشتن...';
      case UserStatus.recording:
        return 'در حال ضبط صدا...';
      case UserStatus.offline:
      case UserStatus.lastSeen:
        return _formatLastSeen();
    }
  }

  Color _getTextColor(ChatTheme theme) {
    switch (widget.status) {
      case UserStatus.online:
        return const Color(0xFF4ADE80);
      case UserStatus.typing:
      case UserStatus.recording:
        return theme.typingColor;
      case UserStatus.offline:
      case UserStatus.lastSeen:
        return theme.secondaryTextColor;
    }
  }

  String _formatLastSeen() {
    if (widget.lastSeen == null) return 'آفلاین';

    final now = DateTime.now();
    final diff = now.difference(widget.lastSeen!);

    if (diff.inMinutes < 1) {
      return 'همین الان آنلاین بود';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} دقیقه پیش';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ساعت پیش';
    } else if (diff.inDays == 1) {
      return 'دیروز آخرین بازدید';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    } else {
      final jalali = Jalali.fromDateTime(widget.lastSeen!);
      return 'آخرین بازدید ${jalali.day} ${_getPersianMonth(jalali.month)}';
    }
  }

  String _getPersianMonth(int month) {
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر',
      'مرداد', 'شهریور', 'مهر', 'آبان',
      'آذر', 'دی', 'بهمن', 'اسفند',
    ];
    return months[month - 1];
  }
}

/// ویجت کامل وضعیت با نقطه و متن
class FullOnlineStatus extends StatelessWidget {
  final UserStatus status;
  final DateTime? lastSeen;
  final String? typingUserName;

  const FullOnlineStatus({
    super.key,
    required this.status,
    this.lastSeen,
    this.typingUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnlineStatusIndicator(
          status: status,
          dotSize: 8,
        ),
        const SizedBox(width: 6),
        OnlineStatusText(
          status: status,
          lastSeen: lastSeen,
          typingUserName: typingUserName,
        ),
      ],
    );
  }
}

/// انیمیشن تایپینگ (سه نقطه)
class TypingDotsAnimation extends StatefulWidget {
  final Color color;
  final double dotSize;

  const TypingDotsAnimation({
    super.key,
    this.color = Colors.blue,
    this.dotSize = 6,
  });

  @override
  State<TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -4).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // شروع با تاخیر
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

