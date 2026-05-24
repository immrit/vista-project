// lib/features/chat/widgets/retry_indicator_widget.dart
//
// نمایش وضعیت ارسال پیام با الهام از ویستا
//
// ویژگی‌ها:
// ✅ Clock icon برای pending (مثل ویستا)
// ✅ Checkmark animation برای sent
// ✅ Double checkmark برای read
// ✅ Error icon با retry
// ✅ Smooth animations
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// وضعیت پیام
enum MessageSendStatus {
  pending, // در حال ارسال - ساعت
  sent, // ارسال شده - یک تیک
  delivered, // تحویل داده شده - دو تیک خاکستری
  read, // خوانده شده - دو تیک آبی
  failed, // خطا - علامت تعجب قرمز
}

/// Retry Indicator به سبک ویستا
class TelegramRetryIndicator extends StatefulWidget {
  final MessageSendStatus status;
  final VoidCallback? onRetry;
  final bool isMe;

  const TelegramRetryIndicator({
    super.key,
    required this.status,
    this.onRetry,
    this.isMe = true,
  });

  @override
  State<TelegramRetryIndicator> createState() => _TelegramRetryIndicatorState();
}

class _TelegramRetryIndicatorState extends State<TelegramRetryIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 60,
      ),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    // شروع انیمیشن برای pending
    if (widget.status == MessageSendStatus.pending) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TelegramRetryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.status != widget.status) {
      if (widget.status == MessageSendStatus.pending) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMe) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: child,
        );
      },
      child: _buildStatusIcon(),
    );
  }

  Widget _buildStatusIcon() {
    switch (widget.status) {
      case MessageSendStatus.pending:
        return _buildPendingIcon();
      case MessageSendStatus.sent:
        return _buildSentIcon();
      case MessageSendStatus.delivered:
        return _buildDeliveredIcon();
      case MessageSendStatus.read:
        return _buildReadIcon();
      case MessageSendStatus.failed:
        return _buildFailedIcon();
    }
  }

  /// ساعت برای pending (مثل ویستا)
  Widget _buildPendingIcon() {
    return RotationTransition(
      turns: _rotationAnimation,
      child: Icon(
        Icons.access_time_rounded,
        size: 14,
        color: Colors.white.withOpacity(0.6),
        key: const ValueKey('pending'),
      ),
    );
  }

  /// یک تیک برای sent (مثل ویستا)
  Widget _buildSentIcon() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Icon(
        Icons.check,
        size: 14,
        color: Colors.white,
        key: ValueKey('sent'),
      ),
    );
  }

  /// دو تیک خاکستری برای delivered (مثل ویستا)
  Widget _buildDeliveredIcon() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: 18,
        height: 14,
        key: const ValueKey('delivered'),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Icon(
                Icons.check,
                size: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Positioned(
              left: 4,
              child: Icon(
                Icons.check,
                size: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دو تیک آبی برای read (مثل ویستا)
  Widget _buildReadIcon() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: 18,
        height: 14,
        key: const ValueKey('read'),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Icon(
                Icons.check,
                size: 14,
                color: Colors.blue[400],
              ),
            ),
            Positioned(
              left: 4,
              child: Icon(
                Icons.check,
                size: 14,
                color: Colors.blue[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// علامت خطا با قابلیت retry (مثل ویستا)
  Widget _buildFailedIcon() {
    return GestureDetector(
      onTap: () {
        if (widget.onRetry != null) {
          HapticFeedback.lightImpact();
          widget.onRetry!();
        }
      },
      child: Container(
        width: 18,
        height: 18,
        key: const ValueKey('failed'),
        decoration: BoxDecoration(
          color: Colors.red[400],
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Connection Status Banner (مثل ویستا)
class TelegramConnectionBanner extends StatefulWidget {
  final bool isConnected;
  final VoidCallback? onRetry;

  const TelegramConnectionBanner({
    super.key,
    required this.isConnected,
    this.onRetry,
  });

  @override
  State<TelegramConnectionBanner> createState() =>
      _TelegramConnectionBannerState();
}

class _TelegramConnectionBannerState extends State<TelegramConnectionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (!widget.isConnected) {
      _controller.forward();
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(TelegramConnectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isConnected != widget.isConnected) {
      if (widget.isConnected) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[600],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // آیکون در حال اتصال
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.orange[100]),
                ),
              ),
              const SizedBox(width: 12),
              // متن
              Expanded(
                child: Text(
                  'در حال اتصال...',
                  style: TextStyle(
                    color: Colors.orange[50],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // دکمه retry
              if (widget.onRetry != null)
                TextButton(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'تلاش مجدد',
                    style: TextStyle(
                      color: Colors.orange[50],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pending Messages Counter (مثل ویستا)
class TelegramPendingCounter extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const TelegramPendingCounter({
    super.key,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange[400],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.orange[50]),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count پیام در حال ارسال',
              style: TextStyle(
                color: Colors.orange[50],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
