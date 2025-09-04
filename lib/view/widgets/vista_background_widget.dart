import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'vista_story_template_widget.dart';

/// ویجت فقط بک‌گراند VISTA (بدون کارت پست)
class VistaBackgroundWidget extends StatelessWidget {
  final String? customBackgroundText;
  final Color? backgroundColor;
  final Color? textColor;
  final GlobalKey? repaintBoundaryKey;

  const VistaBackgroundWidget({
    Key? key,
    this.customBackgroundText,
    this.backgroundColor,
    this.textColor,
    this.repaintBoundaryKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        width: 1080, // ابعاد استاندارد اینستاگرام
        height: 1920, // نسبت 9:16 استاندارد
        color: backgroundColor ?? Colors.white,
        child: _buildBackgroundText(),
      ),
    );
  }

  /// ساخت پس‌زمینه با نوشته VISTA
  Widget _buildBackgroundText() {
    return Positioned.fill(
      child: Container(
        color: backgroundColor ?? Colors.white,
        child: CustomPaint(
          painter: VistaThreadsStylePainter(
            textColor: textColor ?? Colors.black,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

// VistaThreadsStylePainter is imported from vista_story_template_widget.dart to avoid duplication
