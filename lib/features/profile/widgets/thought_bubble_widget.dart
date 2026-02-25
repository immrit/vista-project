import 'package:flutter/material.dart';

import '../data/models/profile_note_model.dart';

/// ویجت ابر فکری برای نمایش وضعیت پروفایل
/// این ویجت به صورت یک حباب متن فشرده در کنار آواتار نمایش داده می‌شود
class ThoughtBubbleWidget extends StatelessWidget {
  /// مدل وضعیت
  final ProfileNoteModel note;

  /// Callback وقتی روی ابر کلیک شد
  final VoidCallback? onTap;

  /// آیا این پروفایل کاربر فعلی است؟
  final bool isCurrentUser;

  /// آیا دم حباب باید به بالا وصل شود؟ (برای وقتی حباب پایین آواتار است)
  /// اگر false باشد، دم به پایین وصل می‌شود (برای وقتی حباب بالای آواتار است)
  final bool tailAtTop;

  const ThoughtBubbleWidget({
    super.key,
    required this.note,
    this.onTap,
    this.isCurrentUser = false,
    this.tailAtTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleContent = Container(
      constraints: const BoxConstraints(
        maxWidth: 75, // عرض کمتر باز هم
        minWidth: 40,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Text(
        note.content,
        style: TextStyle(
          fontSize: 11, // سایز متن کمی کوچکتر
          color: isDark ? Colors.white : Colors.black87,
          height: 1.3,
          fontFamily: 'Vazir',
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLines: 2, // حداکثر ۲ خط نمایش داده شود
        overflow: TextOverflow.ellipsis, // بقیه متن سه نقطه شود
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            tailAtTop ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Tail on the Left (pointing to avatar)
          Padding(
            // تنظیم فاصله عمودی دم برای زیبایی بیشتر
            padding: EdgeInsets.only(
              bottom: tailAtTop ? 0 : 8.0,
              top: tailAtTop ? 8.0 : 0,
            ),
            child: _BubbleTail(isDark: isDark, isTop: tailAtTop),
          ),
          const SizedBox(width: 3),
          bubbleContent,
        ],
      ),
    );
  }
}

/// دم حباب فکری
class _BubbleTail extends StatelessWidget {
  final bool isDark;
  final bool isTop;

  const _BubbleTail({required this.isDark, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    final mediumCircle = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: borderColor, width: 0.5),
      ),
    );

    final smallCircle = Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: borderColor, width: 0.5),
      ),
    );

    // Horizontal layout
    // اگر دم بالا باشد (isTop)، باید کمی به سمت پایین بیاید تا به آواتار برسد؟
    // ترتیب افقی همیشه کوچک -> بزرگ -> حباب است
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isTop ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        smallCircle,
        const SizedBox(width: 2),
        mediumCircle,
      ],
    );
  }
}

/// ویجت کوچک‌تر برای نمایش در لیست‌ها
class CompactThoughtBubble extends StatelessWidget {
  final String content;
  final VoidCallback? onTap;

  const CompactThoughtBubble({
    super.key,
    required this.content,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 80,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
