// lib/services/gif_service.dart
//
// Ø³Ø±ÙˆÛŒØ³ Ø¯Ø±ÛŒØ§ÙØª GIF Ø§Ø² Tenor API
// Ù¾Ø´ØªÛŒØ¨Ø§Ù†ÛŒ Ø§Ø² Ù¾Ø±ÙˆÚ©Ø³ÛŒ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø§ÛŒØ±Ø§Ù†ÛŒ

import 'dart:convert';
import 'package:http/http.dart' as http;

class GifService {
  // Ú©Ù„ÛŒØ¯ Ø¹Ù…ÙˆÙ…ÛŒ Tenor (Ø¨Ø±Ø§ÛŒ ØªØ³Øª Ø¹Ø§Ù„ÛŒ Ú©Ø§Ø± Ù…ÛŒØ¯Ù‡)
  static const String _apiKey = 'LIVDSRZULELA';

  // âœ… Ù†Ú©ØªÙ‡ Ø·Ù„Ø§ÛŒÛŒ Ø¨Ø±Ø§ÛŒ Ø§ÛŒØ±Ø§Ù†:
  // Ø§Ú¯Ø± ÙÛŒÙ„ØªØ± Ø¨ÙˆØ¯ØŒ Ú©Ø§ÙÛŒÙ‡ Ø§ÛŒÙ† Ø¢Ø¯Ø±Ø³ Ø±Ùˆ Ø¨Ù‡ Ø¢Ø¯Ø±Ø³ Ù¾Ø±ÙˆÚ©Ø³ÛŒ Ø®ÙˆØ¯ØªÙˆÙ† ØªØºÛŒÛŒØ± Ø¨Ø¯ÛŒØ¯
  // Example: route this through a first-party GIF proxy if direct Tenor access is blocked.
  static const String _baseUrl = 'https://g.tenor.com/v1';

  /// Ø¯Ø±ÛŒØ§ÙØª Ú¯ÛŒÙâ€ŒÙ‡Ø§ÛŒ ØªØ±Ù†Ø¯
  Future<List<GifItem>> getTrendingGifs({String? pos, int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/trending?key=$_apiKey&limit=$limit${pos != null ? "&pos=$pos" : ""}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return _parseGifs(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching trending GIFs: $e');
      return [];
    }
  }

  /// Ø¬Ø³ØªØ¬ÙˆÛŒ Ú¯ÛŒÙ
  Future<List<GifItem>> searchGifs(String query,
      {String? pos, int limit = 20}) async {
    try {
      if (query.trim().isEmpty) {
        return getTrendingGifs(pos: pos, limit: limit);
      }

      final uri = Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&key=$_apiKey&limit=$limit${pos != null ? "&pos=$pos" : ""}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return _parseGifs(response.body);
      }
      return [];
    } catch (e) {
      print('Error searching GIFs: $e');
      return [];
    }
  }

  /// Ù¾Ø§Ø±Ø³ Ú©Ø±Ø¯Ù† Ø¬ÛŒØ³ÙˆÙ† Ø¨Ø±Ø§ÛŒ Ø§Ø³ØªØ®Ø±Ø§Ø¬ Ù„ÛŒÙ†Ú©â€ŒÙ‡Ø§ÛŒ Ø¨Ù‡ÛŒÙ†Ù‡
  List<GifItem> _parseGifs(String responseBody) {
    try {
      final data = json.decode(responseBody);
      final results = data['results'] as List?;

      if (results == null) return [];

      return results
          .map<GifItem>((item) {
            final media = item['media'] as List?;
            if (media == null || media.isEmpty) {
              return GifItem(
                id: item['id']?.toString() ?? '',
                url: '',
                previewUrl: '',
                width: 0,
                height: 0,
              );
            }

            final mediaItem = media[0] as Map<String, dynamic>;

            // Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² Ù†Ø³Ø®Ù‡ nanogif ÛŒØ§ tinygif Ø¨Ø±Ø§ÛŒ preview (Ø³Ø±Ø¹Øª Ø¨Ø§Ù„Ø§ØªØ±)
            final nanogif = mediaItem['nanogif'] as Map<String, dynamic>?;
            final tinygif = mediaItem['tinygif'] as Map<String, dynamic>?;
            final gif = mediaItem['gif'] as Map<String, dynamic>?;
            final mediumgif = mediaItem['mediumgif'] as Map<String, dynamic>?;

            // URL Ø§ØµÙ„ÛŒ GIF Ø¨Ø±Ø§ÛŒ Ø§Ø±Ø³Ø§Ù„ (Ø§ÙˆÙ„ÙˆÛŒØª: gif > mediumgif > tinygif)
            final mainGif = gif ?? mediumgif ?? tinygif ?? nanogif;

            // URL Ø¨Ø±Ø§ÛŒ preview (Ø§ÙˆÙ„ÙˆÛŒØª: nanogif > tinygif)
            final previewGif = nanogif ?? tinygif;

            if (mainGif == null) {
              return GifItem(
                id: item['id']?.toString() ?? '',
                url: '',
                previewUrl: '',
                width: 0,
                height: 0,
              );
            }

            return GifItem(
              id: item['id']?.toString() ?? '',
              url: mainGif['url'] as String? ??
                  '', // URL Ø§ØµÙ„ÛŒ Ø¨Ø±Ø§ÛŒ Ø§Ø±Ø³Ø§Ù„
              previewUrl: previewGif?['url'] as String? ??
                  mainGif['url'] as String? ??
                  '', // URL Ø¨Ø±Ø§ÛŒ preview
              width: (mainGif['dims'] as List?)?[0] as int? ?? 0,
              height: (mainGif['dims'] as List?)?[1] as int? ?? 0,
            );
          })
          .where((item) => item.url.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error parsing GIFs: $e');
      return [];
    }
  }
}

/// Ù…Ø¯Ù„ Ø¯Ø§Ø¯Ù‡ Ø¨Ø±Ø§ÛŒ ÛŒÚ© Ú¯ÛŒÙ
class GifItem {
  final String id;
  final String url;
  final String previewUrl;
  final int width;
  final int height;

  GifItem({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.width,
    required this.height,
  });
}
