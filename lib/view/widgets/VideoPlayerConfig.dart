import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoPlayerConfig {
  static const String _qualityKey = 'video_quality';
  static const String _dataSaverKey = 'data_saver';
  static const String _autoQualityKey = 'auto_quality';
  static const String _volumeKey = 'volume';
  static const String _lastPlayedPositionPrefix = 'video_position_';
  static const String _autoPlayKey = 'video_auto_play';

  // Singleton instance
  static final VideoPlayerConfig _instance = VideoPlayerConfig._internal();
  factory VideoPlayerConfig() => _instance;
  VideoPlayerConfig._internal();

  // Custom cache manager for videos
  final BaseCacheManager videoCacheManager = CacheManager(
    Config(
      'video_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 20,
      fileService: HttpFileService(),
    ),
  );

  // Preferences methods
  Future<String> getPreferredQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_qualityKey) ?? 'auto';
  }

  Future<bool> getDataSaverMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dataSaverKey) ?? false;
  }

  Future<bool> getAutoQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoQualityKey) ?? true;
  }

  Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_volumeKey) ?? 1.0;
  }

  Future<void> setPreferredQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, quality);
  }

  Future<void> setDataSaverMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, enabled);
  }

  Future<void> setAutoQuality(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoQualityKey, enabled);
  }

  Future<void> setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, volume);
  }

  // Video position management
  Future<Duration> getLastPlayedPosition(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final position = prefs.getInt('$_lastPlayedPositionPrefix$videoId') ?? 0;
    return Duration(milliseconds: position);
  }

  Future<void> savePlayedPosition(String videoId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        '$_lastPlayedPositionPrefix$videoId', position.inMilliseconds);
  }

  Future<bool> getAutoPlay() async {
    final prefs = await SharedPreferences.getInstance();
    // پیش‌فرض: فعال باشد (اگر قبلاً ست نشده)
    return prefs.getBool(_autoPlayKey) ?? true;
  }

  Future<void> setAutoPlay(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, enabled);
  }
}
