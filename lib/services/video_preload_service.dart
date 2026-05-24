import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../widgets/VideoPlayerConfig.dart';

class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal();

  final BaseCacheManager _cacheManager = VideoPlayerConfig().videoCacheManager;
  final Queue<String> _preloadQueue = Queue<String>();
  final Set<String> _currentlyPreloading = {};
  bool _isPreloading = false;

  // حداکثر تعداد ویدیوهایی که همزمان دانلود می‌شوند
  final int maxConcurrent = 2;

  void preloadVideos(List<String> urls) {
    for (final url in urls) {
      if (url.isEmpty || _currentlyPreloading.contains(url)) continue;
      _preloadQueue.add(url);
    }
    _processQueue();
  }

  void _processQueue() async {
    if (_isPreloading || _preloadQueue.isEmpty) return;
    if (_currentlyPreloading.length >= maxConcurrent) return;

    _isPreloading = true;

    while (_preloadQueue.isNotEmpty &&
        _currentlyPreloading.length < maxConcurrent) {
      final url = _preloadQueue.removeFirst();
      _currentlyPreloading.add(url);

      // اجرای دانلود در پس‌زمینه بدون مسدود کردن
      _preloadSingle(url).then((_) {
        _currentlyPreloading.remove(url);
        _processQueue(); // پردازش بعدی
      });
    }

    _isPreloading = false;
  }

  Future<void> _preloadSingle(String url) async {
    try {
      // فقط در صورتی دانلود می‌کنیم که قبلا کش نشده باشد
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo == null) {
        await _cacheManager.downloadFile(url);
      }
    } catch (e) {
      debugPrint('Error preloading video: $e');
    }
  }

  Future<FileInfo?> getCachedVideo(String url) async {
    return await _cacheManager.getFileFromCache(url);
  }
}
