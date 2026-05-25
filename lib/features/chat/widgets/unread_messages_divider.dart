// lib/features/chat/widgets/unread_messages_divider.dart
//
// نشانگر پیام‌های خوانده نشده - با الهام از ویستا
//
// ویژگی‌ها:
// ✅ انیمیشن ظاهر شدن
// ✅ نمایش تعداد پیام‌ها
// ✅ قابلیت کلیک برای scroll
// ✅ استایل زیبا
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';

/// نشانگر پیام‌های خوانده نشده
class UnreadMessagesDivider extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onTap;

  const UnreadMessagesDivider({
    super.key,
    required this.unreadCount,
    this.onTap,
  });

  @override
  State<UnreadMessagesDivider> createState() => _UnreadMessagesDividerState();
}

class _UnreadMessagesDividerState extends State<UnreadMessagesDivider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap?.call();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                // خط چپ
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          theme.sendButtonColor.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),

                // باکس متن
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.sendButtonColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.sendButtonColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: theme.sendButtonColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.unreadCount == 1
                            ? '۱ پیام خوانده نشده'
                            : '${_toPersianNumber(widget.unreadCount)} پیام خوانده نشده',
                        style: TextStyle(
                          color: theme.sendButtonColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // خط راست
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.sendButtonColor.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _toPersianNumber(int number) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.toString().split('').map((d) {
      final digit = int.tryParse(d);
      return digit != null ? persianDigits[digit] : d;
    }).join();
  }
}

/// نسخه ساده‌تر بدون انیمیشن
class SimpleUnreadDivider extends StatelessWidget {
  final int count;

  const SimpleUnreadDivider({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.sendButtonColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count پیام جدید',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
