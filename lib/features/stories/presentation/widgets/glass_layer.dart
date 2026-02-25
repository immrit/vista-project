import 'dart:ui';
import 'package:flutter/material.dart';

class GlassLayer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color baseColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassLayer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.2,
    this.baseColor = Colors.black,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: baseColor.withOpacity(opacity),
              borderRadius: borderRadius,
              border: border ??
                  Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
