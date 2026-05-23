import 'package:flutter/material.dart';

class VistaToast {
  VistaToast._();

  static void show({
    required BuildContext context,
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF1E2130) : Colors.white;
    final defaultText = isDark ? Colors.white : Colors.black87;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) {
        return _VistaToastWidget(
          message: message,
          icon: icon,
          backgroundColor: backgroundColor ?? defaultBg,
          textColor: textColor ?? defaultText,
          duration: duration,
          onDismissed: () => overlayEntry.remove(),
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  static void error({
    required BuildContext context,
    required String message,
  }) {
    show(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
    );
  }

  static void info({
    required BuildContext context,
    required String message,
  }) {
    show(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
    );
  }
}

class _VistaToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _VistaToastWidget({
    required this.message,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_VistaToastWidget> createState() => _VistaToastWidgetState();
}

class _VistaToastWidgetState extends State<_VistaToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0.0, -0.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    
    _controller.forward();
    
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.textColor, size: 24),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Vazir',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
