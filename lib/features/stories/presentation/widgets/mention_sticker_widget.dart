import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class MentionStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isHashtag;
  final bool isEditable;

  const MentionStickerWidget({
    super.key,
    required this.element,
    this.isHashtag = false,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? {};
    // Fallback to elemental text if no specific data key exists
    String label = isHashtag
        ? (data['hashtag'] ?? element.text).toString()
        : (data['username'] ?? element.text).toString();

    // Ensure prefix is correct
    if (isHashtag && !label.startsWith('#')) label = '#$label';
    if (!isHashtag && !label.startsWith('@')) label = '@$label';

    final int style = element.styleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _buildStyle(style, label),
    );
  }

  Widget _buildStyle(int style, String label) {
    final Key key = ValueKey<int>(style);
    switch (style) {
      case 1: // Solid White
        return _buildWhiteStyle(key, label);
      case 2: // Semi-transparent Black
        return _buildBlackStyle(key, label);
      case 0: // Gram Gradient
      default:
        return _buildGradientStyle(key, label);
    }
  }

  Widget _buildGradientStyle(Key key, String label) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFE8C00),
            Color(0xFFF83600)
          ], // Instagram-ish Orange/Red
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF83600).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'Vazir',
        ),
      ),
    );
  }

  Widget _buildWhiteStyle(Key key, String label) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isHashtag
              ? Colors.blue
              : const Color(0xFFE1306C), // Blue for tags, Pink for mention
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'Vazir',
        ),
      ),
    );
  }

  Widget _buildBlackStyle(Key key, String label) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          fontFamily: 'Vazir',
        ),
      ),
    );
  }
}
