import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Middleware برای بررسی نشست قبل از دسترسی به صفحات.
///
/// علاوه بر نمایش صفحه، یک guard هوشمند برای دکمه بازگشت فراهم می‌کند:
/// - اگر route قبلی وجود داشته باشد → pop معمولی
/// - اگر stack خالی باشد (مثلاً deep link یا redirect مستقیم) → به صفحه خانه هدایت
class SessionMiddleware extends ConsumerStatefulWidget {
  final Widget child;

  const SessionMiddleware({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SessionMiddleware> createState() => _SessionMiddlewareState();
}

class _SessionMiddlewareState extends ConsumerState<SessionMiddleware> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false — ما خودمان pop را کنترل می‌کنیم
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          // route قبلی وجود دارد — pop معمولی
          navigator.pop();
        } else {
          // stack خالی است — به صفحه خانه برمی‌گردیم
          navigator.pushNamedAndRemoveUntil('/home', (_) => false);
        }
      },
      child: widget.child,
    );
  }
}

