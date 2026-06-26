// lib/features/chat/widgets/modern_reaction_picker.dart
//
// Reaction Picker به سبک ویستا iOS
//
// ویژگی‌ها:
// ✅ ظاهر شیشه‌ای و قرصی (Pill Shape)
// ✅ اسکرول افقی برای ایموجی‌های زیاد
// ✅ انیمیشن نرم هنگام انتخاب و اسکرول
// ✅ لیست کامل ایموجی‌ها

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:Vista/core/theme/app_theme.dart';

/// لیست گسترده‌ای از ری‌اکشن‌ها مشابه ویستا
const List<String> kDefaultReactions = [
  '👍',
  '👎',
  '❤️',
  '🔥',
  '🥰',
  '👏',
  '😁',
  '🤔',
  '🤯',
  '😱',
  '🤬',
  '😢',
  '🎉',
  '🤩',
  '🤮',
  '💩',
  '🙏',
  '👌',
  '🕊️',
  '🤡',
  '🥱',
  '🥴',
  '😍',
  '🐳',
  '💯',
  '🤣',
  '⚡',
  '🍌',
  '🏆',
  '💔',
  '🤨',
  '😐',
  '🍓',
  '🍾',
  '💋',
  '🖕',
];

/// Modern-style Reaction Picker با اسکرول افقی
class ModernReactionPicker extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback? onClose;
  final List<String> reactions;
  final Offset position;
  final bool showAbove;

  const ModernReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.onClose,
    this.reactions = kDefaultReactions,
    required this.position,
    this.showAbove = true,
  });

  @override
  State<ModernReactionPicker> createState() => _ModernReactionPickerState();
}

class _ModernReactionPickerState extends State<ModernReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _widthAnimation;

  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // انیمیشن باز شدن (Scale)
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    // انیمیشن باز شدن عرضی
    _widthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
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
    final screenSize = MediaQuery.of(context).size;

    // محاسبه عرض: حداکثر عرض صفحه منهای حاشیه، اما نه بیشتر از 360
    final pickerWidth = (screenSize.width - 32).clamp(200.0, 360.0);
    const pickerHeight = 52.0;

    // محاسبه دقیق موقعیت برای اینکه از صفحه بیرون نزند
    double left = widget.position.dx - (pickerWidth / 2);
    left = left.clamp(16.0, screenSize.width - pickerWidth - 16.0);

    // محاسبه دقیق موقعیت عمودی
    double top =
        widget.showAbove ? widget.position.dy - 70 : widget.position.dy + 10;

    return Positioned(
      left: left,
      top: top,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment:
            widget.showAbove ? Alignment.bottomCenter : Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _widthAnimation,
          builder: (context, child) {
            // انیمیشن باز شدن عرضی
            return SizedBox(
              width: pickerWidth * _widthAnimation.value,
              height: pickerHeight,
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF252525).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.85),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(), // افکت اسکرول iOS
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: widget.reactions.length,
                    itemBuilder: (context, index) {
                      return _buildEmojiItem(index);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiItem(int index) {
    final emoji = widget.reactions[index];
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _hoveredIndex = index);
        },
        onTapUp: (_) {
          HapticFeedback.mediumImpact();
          widget.onReactionSelected(emoji);
          widget.onClose?.call();
          setState(() => _hoveredIndex = null);
        },
        onTapCancel: () {
          setState(() => _hoveredIndex = null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: isHovered ? 50 : 42, // بزرگ شدن در حالت انتخاب
          height: 52,
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, isHovered ? -4.0 : 0.0), // کمی بالا آمدن
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: isHovered ? 32 : 26, // سایز فونت ایموجی
              fontFamily: 'Apple Color Emoji',
              fontFamilyFallback: const [
                'Segoe UI Emoji',
                'Noto Color Emoji',
              ],
            ),
            child: Text(emoji),
          ),
        ),
      ),
    );
  }
}

/// Reaction Display در Message Bubble (مثل ویستا)
class ModernReactionDisplay extends StatelessWidget {
  final Map<String, List<String>> reactions; // emoji -> [userId1, userId2, ...]
  final String currentUserId;
  final Function(String emoji)? onReactionTap;

  const ModernReactionDisplay({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final count = users.length;
        final hasMyReaction = users.contains(currentUserId);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onReactionTap?.call(emoji);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasMyReaction
                  ? (isDark ? AppColors.darkSurfaceVariant : const Color(0xFFE8F5E9))
                  : (isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurfaceVariant),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasMyReaction
                    ? (isDark ? Colors.green[700]! : Colors.green[400]!)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasMyReaction
                          ? (isDark ? Colors.green[300] : Colors.green[700])
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
