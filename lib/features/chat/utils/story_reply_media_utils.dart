import '../../../utils/env_config.dart';
import '../../stories/domain/entities/entities.dart';

/// Helpers for story-reply thumbnails in chat.
class StoryReplyMediaUtils {
  StoryReplyMediaUtils._();

  static String? resolveMediaUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('/')) {
      return '${EnvConfig.apiBaseUrl}$value';
    }
    return value;
  }

  static String thumbnailFromStory(Story story) {
    final thumb = story.media.thumbnailUrl?.trim();
    final media = story.media.url.trim();
    final picked = (thumb != null && thumb.isNotEmpty) ? thumb : media;
    return resolveMediaUrl(picked) ?? '';
  }

  static bool isGenericStoryLabel(String? text) {
    final value = text?.trim() ?? '';
    return value == 'استوری تصویری' ||
        value == 'استوری ویدیویی' ||
        value == 'Image Story' ||
        value == 'Video Story';
  }
}
