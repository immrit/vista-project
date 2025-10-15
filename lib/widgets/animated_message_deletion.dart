import '../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';

/// سیستم انیمیشن پودر شدن پیام‌ها به سبک تلگرام
class AnimatedMessageDeletion extends StatefulWidget {
  final MessageModel message;
  final Widget child;
  final VoidCallback? onAnimationComplete;
  final bool startAnimation;

  const AnimatedMessageDeletion({
    super.key,
    required this.message,
    required this.child,
    this.onAnimationComplete,
    this.startAnimation = false,
  });

  @override
  State<AnimatedMessageDeletion> createState() =>
      _AnimatedMessageDeletionState();
}

class _AnimatedMessageDeletionState extends State<AnimatedMessageDeletion>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // انیمیشن fade out
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // انیمیشن scale down
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // انیمیشن slide up
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // تنظیم انیمیشن‌ها
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.3),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInQuart,
    ));

    // شروع انیمیشن اگر درخواست شده
    if (widget.startAnimation) {
      _startDeletionAnimation();
    }
  }

  @override
  void didUpdateWidget(AnimatedMessageDeletion oldWidget) {
    super.didUpdateWidget(oldWidget);

    // اگر انیمیشن باید شروع شود
    if (widget.startAnimation && !oldWidget.startAnimation) {
      _startDeletionAnimation();
    }
  }

  /// شروع انیمیشن حذف پودری
  void _startDeletionAnimation() async {
    try {
      // مرحله 1: شروع همزمان fade و scale
      await Future.wait([
        _fadeController.forward(),
        _scaleController.forward(),
      ]);

      // مرحله 2: slide up سریع
      await _slideController.forward();

      // اتمام انیمیشن - اطلاع به parent
      widget.onAnimationComplete?.call();
    } catch (e) {
      logDebug('خطا در انیمیشن حذف: $e');
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _scaleAnimation,
        _slideAnimation,
      ]),
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

/// Provider برای مدیریت state پیام‌های در حال حذف
final deletingMessagesProvider = StateProvider<Set<String>>((ref) => {});

/// Widget wrapper برای پیام‌ها با قابلیت انیمیشن حذف
class DeletableMessageWidget extends ConsumerWidget {
  final MessageModel message;
  final Widget child;
  final VoidCallback? onDeleted;

  const DeletableMessageWidget({
    super.key,
    required this.message,
    required this.child,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletingMessages = ref.watch(deletingMessagesProvider);
    final isDeleting = deletingMessages.contains(message.id);

    return AnimatedMessageDeletion(
      message: message,
      startAnimation: isDeleting,
      onAnimationComplete: () {
        // حذف از لیست پیام‌های در حال حذف
        ref.read(deletingMessagesProvider.notifier).update((state) {
          final newState = Set<String>.from(state);
          newState.remove(message.id);
          return newState;
        });

        // اطلاع به parent که انیمیشن تمام شد
        onDeleted?.call();
      },
      child: child,
    );
  }
}

/// Extension برای شروع انیمیشن حذف
extension AnimatedDeletionExtension on WidgetRef {
  /// شروع انیمیشن حذف پیام
  void startDeletionAnimation(String messageId) {
    read(deletingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.add(messageId);
      return newState;
    });
  }

  /// متوقف کردن انیمیشن حذف (برای rollback)
  void stopDeletionAnimation(String messageId) {
    read(deletingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.remove(messageId);
      return newState;
    });
  }

  /// بررسی آیا پیام در حال حذف است
  bool isMessageDeleting(String messageId) {
    return read(deletingMessagesProvider).contains(messageId);
  }
}

/// Widget برای نمایش effect های اضافی حین حذف
class DeletionEffectWidget extends StatefulWidget {
  final Widget child;
  final bool isDeleting;

  const DeletionEffectWidget({
    super.key,
    required this.child,
    required this.isDeleting,
  });

  @override
  State<DeletionEffectWidget> createState() => _DeletionEffectWidgetState();
}

class _DeletionEffectWidgetState extends State<DeletionEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(DeletionEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDeleting && !oldWidget.isDeleting) {
      _shimmerController.forward();
    } else if (!widget.isDeleting && oldWidget.isDeleting) {
      _shimmerController.reverse();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDeleting) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3 * _shimmerAnimation.value),
                blurRadius: 8 * _shimmerAnimation.value,
                spreadRadius: 2 * _shimmerAnimation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Message container با انیمیشن های حذف کامل
class AnimatedMessageContainer extends ConsumerWidget {
  final MessageModel message;
  final Widget child;
  final VoidCallback? onDeleted;
  final bool enableDeletionEffect;

  const AnimatedMessageContainer({
    super.key,
    required this.message,
    required this.child,
    this.onDeleted,
    this.enableDeletionEffect = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleting = ref.watch(deletingMessagesProvider).contains(message.id);

    Widget wrappedChild = child;

    // اعمال effect حین حذف
    if (enableDeletionEffect) {
      wrappedChild = DeletionEffectWidget(
        isDeleting: isDeleting,
        child: wrappedChild,
      );
    }

    // اعمال انیمیشن حذف
    return DeletableMessageWidget(
      message: message,
      onDeleted: onDeleted,
      child: wrappedChild,
    );
  }
}

/// Utility functions
class DeletionAnimationUtils {
  /// تأخیر مناسب برای انیمیشن تا کامل شود
  static const Duration animationDuration = Duration(milliseconds: 600);

  /// شروع انیمیشن حذف و انتظار برای تکمیل
  static Future<void> animateAndDelete({
    required WidgetRef ref,
    required String messageId,
    required VoidCallback onComplete,
  }) async {
    // شروع انیمیشن
    ref.startDeletionAnimation(messageId);

    // انتظار برای تکمیل انیمیشن
    await Future.delayed(animationDuration);

    // تکمیل حذف
    onComplete();
  }

  /// لغو انیمیشن در صورت خطا
  static void cancelAnimation({
    required WidgetRef ref,
    required String messageId,
  }) {
    ref.stopDeletionAnimation(messageId);
  }
}
