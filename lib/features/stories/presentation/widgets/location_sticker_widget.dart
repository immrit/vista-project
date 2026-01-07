import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class LocationStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const LocationStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (element.interactionType != StoryInteractionType.location) {
      return const SizedBox.shrink();
    }

    final data = element.interactionData ?? {};
    final String city = data['city'] ?? 'Location';

    // 0: Classic (White/Transparent)
    // 1: Gradient (Purple/Blue)
    // 2: Minimal (Text Only)
    final int style = element.styleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(style),
        child: _buildStyle(context, style, city),
      ),
    );
  }

  Widget _buildStyle(BuildContext context, int style, String city) {
    switch (style) {
      case 1:
        return _buildGradientStyle(city);
      case 2:
        return _buildMinimalStyle(city);
      case 0:
      default:
        return _buildClassicStyle(city);
    }
  }

  Widget _buildClassicStyle(String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Colors.blue, size: 20),
          const SizedBox(width: 4),
          Text(
            city.toUpperCase(),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientStyle(String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(
            city,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalStyle(String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pin_drop, color: Colors.redAccent, size: 18),
          const SizedBox(width: 4),
          Text(
            city,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
