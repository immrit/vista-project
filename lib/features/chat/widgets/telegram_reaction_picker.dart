// lib/features/chat/widgets/telegram_reaction_picker.dart
//
// Reaction Picker دقیقاً مثل تلگرام
//
// ویژگی‌ها:
// ✅ Scale animation برای هر ایموجی
// ✅ Haptic feedback
// ✅ Backdrop blur
// ✅ Smart positioning (بالا/پایین پیام)
// ✅ Expanding animation مثل تلگرام
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

/// لیست ایموجی‌های پیش‌فرض (مثل تلگرام)
const List<String> kDefaultReactions = [
  '👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥',
];

/// Telegram-style Reaction Picker
class TelegramReactionPicker extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback? onClose;
  final List<String> reactions;
  final Offset position;
  final bool showAbove;

  const TelegramReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.onClose,
    this.reactions = kDefaultReactions,
    required this.position,
    this.showAbove = true,
  });

  @override
  State<TelegramReactionPicker> createState() => _TelegramReactionPickerState();
}

class _TelegramReactionPickerState extends State<TelegramReactionPicker>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _scaleController;
  late List<AnimationController> _emojiControllers;
  
  late Animation<double> _expandAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _emojiAnimations;

  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    // انیمیشن باز شدن کل پیکر
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    // انیمیشن scale کلی
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    // انیمیشن هر ایموجی به صورت جداگانه (staggered)
    _emojiControllers = List.generate(
      widget.reactions.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _emojiAnimations = _emojiControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutBack,
        ),
      );
    }).toList();
  }

  void _startAnimations() async {
    // شروع انیمیشن expand
    _expandController.forward();
    _scaleController.forward();

    // شروع انیمیشن ایموجی‌ها با تاخیر (staggered)
    for (int i = 0; i < _emojiControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        _emojiControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _scaleController.dispose();
    for (final controller in _emojiControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 140, // مرکز کردن
      top: widget.showAbove 
          ? widget.position.dy - 70 
          : widget.position.dy + 10,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _expandAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2B2B2B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.reactions.length,
                      (index) => _buildEmojiButton(index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton(int index) {
    final emoji = widget.reactions[index];
    final isHovered = _hoveredIndex == index;

    return ScaleTransition(
      scale: _emojiAnimations[index],
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _hoveredIndex = index);
        },
        onTapUp: (_) {
          HapticFeedback.mediumImpact();
          widget.onReactionSelected(emoji);
          widget.onClose?.call();
        },
        onTapCancel: () {
          setState(() => _hoveredIndex = null);
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: isHovered ? 44 : 36,
            height: isHovered ? 44 : 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isHovered
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: isHovered ? 28 : 24,
                ),
                child: Text(
                  emoji,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reaction Display در Message Bubble (مثل تلگرام)
class TelegramReactionDisplay extends StatelessWidget {
  final Map<String, List<String>> reactions; // emoji -> [userId1, userId2, ...]
  final String currentUserId;
  final Function(String emoji)? onReactionTap;

  const TelegramReactionDisplay({
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
                  ? (isDark
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFE8F5E9))
                  : (isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasMyReaction
                    ? (isDark
                        ? Colors.green[700]!
                        : Colors.green[400]!)
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


