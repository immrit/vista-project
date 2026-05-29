import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

/// نقاش مسیرها در ویرایشگر استوری
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? currentPath;

  DrawingPainter({this.paths = const [], this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      canvas.drawPath(_buildSmoothPath(path.points), _makePaint(path.color, path.strokeWidth));
    }
    if (currentPath != null && currentPath!.points.isNotEmpty) {
      canvas.drawPath(
        _buildSmoothPath(currentPath!.points),
        _makePaint(currentPath!.color, currentPath!.strokeWidth),
      );
    }
  }

  Paint _makePaint(Color color, double strokeWidth) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
  }

  /// Builds a smooth quadratic Bézier path through the given points.
  /// Uses midpoint control points for a natural hand-drawn feel.
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points.first, radius: 1));
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.paths != paths ||
        oldDelegate.currentPath != currentPath;
  }
}
