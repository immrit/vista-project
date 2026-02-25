// lib/services/gif_service.dart
//
// سرویس دریافت GIF از Tenor API
// پشتیبانی از پروکسی برای کاربران ایرانی

import 'dart:convert';
import 'package:http/http.dart' as http;

class GifService {
  // کلید عمومی Tenor (برای تست عالی کار میده)
  static const String _apiKey = 'LIVDSRZULELA';
  
  // ✅ نکته طلایی برای ایران:
  // اگر فیلتر بود، کافیه این آدرس رو به آدرس پروکسی خودتون تغییر بدید
  // مثلا: https://my-supabase-func.com/tenor-proxy
  static const String _baseUrl = 'https://g.tenor.com/v1';

  /// دریافت گیف‌های ترند
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

  /// جستجوی گیف
  Future<List<GifItem>> searchGifs(String query, {String? pos, int limit = 20}) async {
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

  /// پارس کردن جیسون برای استخراج لینک‌های بهینه
  List<GifItem> _parseGifs(String responseBody) {
    try {
      final data = json.decode(responseBody);
      final results = data['results'] as List?;
      
      if (results == null) return [];
      
      return results.map<GifItem>((item) {
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
        
        // استفاده از نسخه nanogif یا tinygif برای preview (سرعت بالاتر)
        final nanogif = mediaItem['nanogif'] as Map<String, dynamic>?;
        final tinygif = mediaItem['tinygif'] as Map<String, dynamic>?;
        final gif = mediaItem['gif'] as Map<String, dynamic>?;
        final mediumgif = mediaItem['mediumgif'] as Map<String, dynamic>?;
        
        // URL اصلی GIF برای ارسال (اولویت: gif > mediumgif > tinygif)
        final mainGif = gif ?? mediumgif ?? tinygif ?? nanogif;
        
        // URL برای preview (اولویت: nanogif > tinygif)
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
          url: mainGif['url'] as String? ?? '', // URL اصلی برای ارسال
          previewUrl: previewGif?['url'] as String? ?? mainGif['url'] as String? ?? '', // URL برای preview
          width: (mainGif['dims'] as List?)?[0] as int? ?? 0,
          height: (mainGif['dims'] as List?)?[1] as int? ?? 0,
        );
      }).where((item) => item.url.isNotEmpty).toList();
    } catch (e) {
      print('Error parsing GIFs: $e');
      return [];
    }
  }
}

/// مدل داده برای یک گیف
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

