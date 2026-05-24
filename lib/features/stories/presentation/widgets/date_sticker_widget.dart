import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class DateStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const DateStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? const {};
    final displayText =
        (data['displayText']?.toString().trim().isNotEmpty ?? false)
            ? data['displayText'].toString().trim()
            : _buildDisplayDate(data['dateIso']?.toString());
    final style = element.resolvedStyleIndex % 3;

    switch (style) {
      case 1:
        return _buildDark(displayText);
      case 2:
        return _buildMinimal(displayText);
      case 0:
      default:
        return _buildClassic(displayText);
    }
  }

  Widget _buildClassic(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded,
              color: Colors.black87, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDark(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'Vazir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimal(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Vazir',
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  String _buildDisplayDate(String? dateIso) {
    final parsed = DateTime.tryParse(dateIso ?? '');
    final now = parsed ?? DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }
}
