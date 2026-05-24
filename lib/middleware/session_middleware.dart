import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Middleware برای بررسی نشست قبل از دسترسی به صفحات
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
    // فقط child را نمایش بده - تمام بررسی‌ها در SplashScreen انجام شده
    return widget.child;
  }
}
