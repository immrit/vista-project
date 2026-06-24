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
    final route = ModalRoute.of(context);
    final isFirst = route?.isFirst ?? false;
    final routeName = route?.settings.name;
    
    final isRootLike = routeName == '/home' || 
                       routeName == '/' || 
                       routeName == '/auth' || 
                       routeName == '/profile-setup' ||
                       routeName == '/mandatory-password';

    final isDeepLink = isFirst && !isRootLike;

    if (!isDeepLink) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
      child: widget.child,
    );
  }
}

