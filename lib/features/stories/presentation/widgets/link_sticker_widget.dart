import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';
import 'glass_layer.dart';

class LinkStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const LinkStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  static const List<Color> _colors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF000000), // Black
    Color(0xFFFFFFFF), // White
  ];

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? {};
    // Extract actual link but display label if present, otherwise shorten the link
    final String url = data['url'] ?? 'https://vista.ir';
    final String label = data['label'] ??
        url.replaceFirst('https://', '').replaceFirst('http://', '');

    final styleRaw = data['style'];
    final style = styleRaw is num
        ? styleRaw.toInt()
        : int.tryParse(styleRaw?.toString() ?? '') ??
            (element.resolvedStyleIndex % 3);
    final colorIndexRaw = data['colorIndex'];
    final int colorIndex = colorIndexRaw is num
        ? colorIndexRaw.toInt()
        : int.tryParse(colorIndexRaw?.toString() ?? '') ?? 0;
    final Color color = _colors[colorIndex % _colors.length];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _buildStyle(style, label, color),
    );
  }

  Widget _buildStyle(int style, String label, Color color) {
    final Key key = ValueKey<int>(style);
    switch (style) {
      case 1: // Dark Glass (Premium)
        return _buildDarkGlassStyle(key, label);
      case 2: // Minimal Light (Clean)
        return _buildLightStyle(key, label, color);
      case 0: // Gradient (Standard)
      default:
        return _buildGradientStyle(key, label, color);
    }
  }

  Widget _buildGradientStyle(Key key, String label, Color color) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Vazir',
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'tap to visit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
        ],
      ),
    );
  }

  Widget _buildDarkGlassStyle(Key key, String label) {
    return GlassLayer(
      key: key,
      borderRadius: BorderRadius.circular(20),
      blur: 20,
      opacity: 0.6,
      baseColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link, color: Colors.black, size: 16),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                fontFamily: 'Vazir',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightStyle(Key key, String label, Color color) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, color: color, size: 20),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
