import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';
import 'package:google_fonts/google_fonts.dart';

import 'location_sticker_widget.dart';
import 'weather_sticker_widget.dart';
import 'poll_sticker_widget.dart';
import 'countdown_sticker_widget.dart';
import 'link_sticker_widget.dart';
import 'mention_sticker_widget.dart';
import 'hashtag_sticker_widget.dart';

class StickerFactory {
  /// Builds the appropriate sticker widget based on element type.
  ///
  /// [isEditable] determines the tap behavior:
  /// - true (Editor): Tap toggles visual style
  /// - false (Viewer): Tap performs the interaction (vote, open link, etc.)
  static Widget buildSticker(StoryElement element, {bool isEditable = true}) {
    switch (element.interactionType) {
      case StoryInteractionType.location:
        return LocationStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.poll:
        return PollStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.countdown:
        return CountdownStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.link:
        return LinkStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.mention:
        return MentionStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.hashtag:
        return HashtagStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.weather:
        return WeatherStickerWidget(element: element, isEditable: isEditable);

      case StoryInteractionType.question:
        // Question stickers use the dedicated card style below.
        return _buildQuestionSticker(element);

      case StoryInteractionType.none:
      default:
        // Default Text Rendering
        return Text(
          element.text,
          style: element.fontFamily == 'Vazir'
              ? TextStyle(
                  fontFamily: element.fontFamily,
                  fontSize: element.fontSize,
                  color: element.color,
                )
              : GoogleFonts.getFont(
                  element.fontFamily,
                  fontSize: element.fontSize,
                  color: element.color,
                ),
          textAlign: element.textAlign,
        );
    }
  }

  static Widget _buildQuestionSticker(StoryElement element) {
    final question = element.interactionData?['question'] ?? 'سوالی داری؟';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'پاسخ دهید...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'Vazir',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
