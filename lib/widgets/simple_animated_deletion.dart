import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';

/// نسخه ساده‌شده انیمیشن حذف که مستقیماً در ChatScreen استفاده می‌شه
class SimpleAnimatedDeletion extends StatefulWidget {
  final MessageModel message;
  final Widget child;
  final bool isDeleting;
  final VoidCallback? onAnimationComplete;

  const SimpleAnimatedDeletion({
    super.key,
    required this.message,
    required this.child,
    this.isDeleting = false,
    this.onAnimationComplete,
  });

  @override
  State<SimpleAnimatedDeletion> createState() => _SimpleAnimatedDeletionState();
}

class _SimpleAnimatedDeletionState extends State<SimpleAnimatedDeletion>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInBack),
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.3),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInQuart),
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(SimpleAnimatedDeletion oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDeleting && !oldWidget.isDeleting) {
      _startDeletionAnimation();
    }
  }

  Future<void> _startDeletionAnimation() async {
    await _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Simple wrapper برای استفاده آسان در ChatScreen
class MessageWithDeletionAnimation extends ConsumerWidget {
  final MessageModel message;
  final Widget child;
  final Set<String> deletingMessageIds;

  const MessageWithDeletionAnimation({
    super.key,
    required this.message,
    required this.child,
    required this.deletingMessageIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleting = deletingMessageIds.contains(message.id);

    return SimpleAnimatedDeletion(
      message: message,
      isDeleting: isDeleting,
      onAnimationComplete: () {
        debugPrint('✅ انیمیشن حذف پیام ${message.id} تکمیل شد');
      },
      child: child,
    );
  }
}

/// Extension برای استفاده آسان در ChatScreen
extension MessageDeletionAnimation on Widget {
  Widget withDeletionAnimation({
    required MessageModel message,
    required Set<String> deletingMessageIds,
  }) {
    return MessageWithDeletionAnimation(
      message: message,
      deletingMessageIds: deletingMessageIds,
      child: this,
    );
  }
}
