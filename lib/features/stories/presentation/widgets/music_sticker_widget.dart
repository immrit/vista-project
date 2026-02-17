import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class MusicStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const MusicStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? const {};
    final title = (data['title']?.toString().trim().isNotEmpty ?? false)
        ? data['title'].toString().trim()
        : 'Unknown track';
    final artist = (data['artist']?.toString().trim().isNotEmpty ?? false)
        ? data['artist'].toString().trim()
        : 'Unknown artist';
    final coverUrl = data['coverUrl']?.toString();
    final style = element.resolvedStyleIndex % 2;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style == 0 ? Colors.black.withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: style == 0 ? Colors.white24 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: coverUrl != null && coverUrl.trim().isNotEmpty
                ? Image.network(
                    coverUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackCover(style),
                  )
                : _buildFallbackCover(style),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style == 0 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style == 0 ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontFamily: 'Vazir',
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_fill_rounded,
            color: style == 0 ? Colors.white : Colors.black87,
            size: 26,
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(int style) {
    return Container(
      width: 44,
      height: 44,
      color: style == 0 ? Colors.white12 : Colors.black12,
      child: Icon(
        Icons.music_note_rounded,
        color: style == 0 ? Colors.white70 : Colors.black54,
      ),
    );
  }
}
