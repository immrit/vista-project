import 'package:flutter/material.dart';

import 'package:Vista/core/theme/app_theme.dart';

/// VistaCard — کارت استاندارد روی توکن‌ها (`AppRadius` + `AppElevation`).
///
/// چرا: ۱۶۶ `BoxShadow` و ۷۲۳ radius دستیِ پراکنده. این primitive سلسله‌مراتب
/// عمق و شعاع گوشه را یکنواخت می‌کند.
class VistaCard extends StatelessWidget {
  const VistaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.md,
    this.elevation = 1,
    this.color,
    this.border = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 0 = بدون سایه، 1 = e1، 2 = e2، 3 = e3.
  final int elevation;
  final Color? color;
  final bool border;
  final VoidCallback? onTap;

  List<BoxShadow>? get _shadow {
    switch (elevation) {
      case 1:
        return AppElevation.e1;
      case 2:
        return AppElevation.e2;
      case 3:
        return AppElevation.e3;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface);
    final br = BorderRadius.circular(radius);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: border
            ? Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: isDark ? 0.8 : 1.0,
              )
            : null,
        boxShadow: isDark ? null : _shadow, // سایه روی dark معمولاً نامرئی
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: br,
      child: InkWell(borderRadius: br, onTap: onTap, child: content),
    );
  }
}
