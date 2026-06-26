import 'package:flutter/material.dart';

import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/utils/vista_motion.dart';

/// VistaGradientButton — CTA برندی با گرادینت `AppColors.primaryGradient`.
///
/// چرا: گرادینت‌های دستی با هگزِ خام پراکنده بودند. این primitive گرادینت برند
/// + شعاع/تایمینگِ توکن‌محور را یک‌جا می‌دهد (press-state با scale ملایم).
class VistaGradientButton extends StatefulWidget {
  const VistaGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.expand = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool expand;
  final double height;

  @override
  State<VistaGradientButton> createState() => _VistaGradientButtonState();
}

class _VistaGradientButtonState extends State<VistaGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(AppRadius.sm);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: VistaMotion.durationFast,
          curve: VistaMotion.snappy,
          child: Container(
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: widget.gradient ?? AppColors.primaryGradient,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
