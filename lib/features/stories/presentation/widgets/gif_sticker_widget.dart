import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class GifStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const GifStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? const {};
    final gifUrl = data['gifUrl']?.toString() ?? '';
    final width = _asDouble(data['width']) ?? element.width ?? 180;
    final height = _asDouble(data['height']) ?? element.height ?? 180;
    final style = element.resolvedStyleIndex % 2;

    if (gifUrl.trim().isEmpty) {
      return _buildFallback(width, height);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: style == 0 ? null : Border.all(color: Colors.white54, width: 1),
        boxShadow: style == 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      // Use gifUrl directly for animated GIF; Image.network supports animation.
      child: Image.network(
        gifUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _buildFallback(width, height),
      ),
    );
  }

  Widget _buildFallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.white12,
      child: const Center(
        child: Icon(Icons.gif_box_outlined, color: Colors.white70, size: 28),
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
