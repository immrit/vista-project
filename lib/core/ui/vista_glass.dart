import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:Vista/core/theme/app_theme.dart';

/// VistaGlass — کانتینر glass واحد برای کل اپ.
///
/// چرا: ۲۶ `BackdropFilter` + ۱۸ `ImageFilter.blur` پراکنده با sigmaی هاردکد بود.
/// این widget تک‌نقطه‌ی کنترل ظاهر glass + ریسک پرفورمنس است.
///
/// ⚠️ Perf: blur پشت محتوای اسکرول‌شونده jankِ رستر می‌سازد. روی لیست‌های
/// طولانی از `sigma` بزرگ پرهیز کن یا `enabled: false` بده (طبق memory پروژه).
class VistaGlass extends StatelessWidget {
  const VistaGlass({
    super.key,
    required this.child,
    this.sigma,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.border = true,
    this.enabled = true,
  });

  final Widget child;

  /// شدت blur. پیش‌فرض از توکن `AppGlass.blurSigma`.
  final double? sigma;

  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// override رنگ پس‌زمینه؛ پیش‌فرض از توکن glass بر اساس brightness.
  final Color? backgroundColor;
  final Color? borderColor;
  final bool border;

  /// اگر false → بدون BackdropFilter رندر می‌شود (برای صرفه‌جویی GPU روی اسکرول).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final bg = backgroundColor ??
        (isDark ? AppGlass.backgroundDark : AppGlass.backgroundLight);
    final bd = borderColor ??
        (isDark ? AppGlass.borderDark : AppGlass.borderLight);
    final s = sigma ?? AppGlass.blurSigma;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border ? Border.all(color: bd, width: 0.8) : null,
      ),
      child: child,
    );

    if (!enabled) return ClipRRect(borderRadius: radius, child: content);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
        child: content,
      ),
    );
  }
}
