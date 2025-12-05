// lib/features/chat/widgets/improved_date_divider.dart
//
// جداکننده تاریخ بین پیام‌ها با طراحی بهبود یافته
//

import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';

class ImprovedDateDivider extends StatelessWidget {
  final DateTime date;
  final EdgeInsets? padding;
  final double? fontSize;

  const ImprovedDateDivider({
    super.key,
    required this.date,
    this.padding,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
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
                    theme.dividerColor.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // نشان تاریخ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? theme.dividerColor.withOpacity(0.15)
                    : theme.dividerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                date.toDateDividerLabel(),
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: fontSize ?? 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          // خط راست
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.dividerColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نسخه کوچک‌تر برای استفاده در لیست‌های فشرده
class CompactDateDivider extends StatelessWidget {
  final DateTime date;

  const CompactDateDivider({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          date.toDateDividerLabel(),
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

