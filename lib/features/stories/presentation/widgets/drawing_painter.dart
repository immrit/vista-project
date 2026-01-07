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
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (path.points.isNotEmpty) {
        final drawPath = Path();
        drawPath.moveTo(path.points.first.dx, path.points.first.dy);
        for (int i = 1; i < path.points.length; i++) {
          drawPath.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(drawPath, paint);
      }
    }

    if (currentPath != null && currentPath!.points.isNotEmpty) {
      final paint = Paint()
        ..color = currentPath!.color
        ..strokeWidth = currentPath!.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final drawPath = Path();
      drawPath.moveTo(
          currentPath!.points.first.dx, currentPath!.points.first.dy);
      for (int i = 1; i < currentPath!.points.length; i++) {
        drawPath.lineTo(currentPath!.points[i].dx, currentPath!.points[i].dy);
      }
      canvas.drawPath(drawPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
