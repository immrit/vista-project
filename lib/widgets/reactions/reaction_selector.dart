import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/reaction_provider.dart';

class ReactionSelectorWidget extends ConsumerStatefulWidget {
  final String messageId;
  final String conversationId;

  const ReactionSelectorWidget({
    super.key,
    required this.messageId,
    required this.conversationId,
  });

  @override
  ConsumerState<ReactionSelectorWidget> createState() =>
      _ReactionSelectorWidgetState();
}

class _ReactionSelectorWidgetState extends ConsumerState<ReactionSelectorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // لیست ایموجی‌های پیشنهادی (مثل تلگرام)
  static const List<String> quickReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
    '👏',
    '🔥'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // محاسبه عرض تقریبی نوار (8 ایموجی + 1 آیکون + padding)
    final estimatedWidth =
        (8.0 * 36.0) + 24.0 + 20.0; // 36px per emoji + icon + padding
    final maxAllowedWidth = screenWidth * 0.85; // 85% of screen width
    final actualWidth =
        estimatedWidth < maxAllowedWidth ? estimatedWidth : maxAllowedWidth;

    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: actualWidth,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ایموجی‌های سریع
                ...quickReactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final emoji = entry.value;

                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 80 + (index * 25)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();

                        // ✅ استفاده از toggleReaction از MessageNotifier برای optimistic update
                        try {
                          final reactionService =
                              ref.read(reactionServiceProvider);
                          await reactionService.toggleReaction(
                            messageId: widget.messageId,
                            conversationId: widget.conversationId,
                            emoji: emoji,
                          );
                        } catch (e) {
                          // Fallback به service در صورت خطا
                          final service = ref.read(reactionServiceProvider);
                          await service.toggleReaction(
                            messageId: widget.messageId,
                            conversationId: widget.conversationId,
                            emoji: emoji,
                          );
                        }

                        // بستن selector
                        ref
                            .read(reactionSelectorProvider(widget.messageId)
                                .notifier)
                            .state = false;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          emoji,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // آیکون + برای افزودن ری‌اکشن‌های بیشتر
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // TODO: نمایش picker کامل ایموجی‌ها
                    ref
                        .read(
                            reactionSelectorProvider(widget.messageId).notifier)
                        .state = false;
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2, right: 4),
                    child: Icon(
                      Icons.add,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.grey[700],
                      size: 18,
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
}
