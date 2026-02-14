import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

/// سرویس کش برای فایل‌های وویس
class VoiceCacheService {
  static final VoiceCacheService _instance = VoiceCacheService._internal();
  factory VoiceCacheService() => _instance;
  VoiceCacheService._internal();

  static const String _cacheInfoKey = 'voice_cache_info';
  static const String _cacheDirName = 'voice_cache';

  Directory? _cacheDir;
  Map<String, VoiceCacheInfo> _cacheInfo = {};

  /// تنظیم ProviderContainer برای دسترسی به providers
  void setProviderContainer(ProviderContainer container) {
    print(
        '✅ VoiceCacheService ProviderContainer set for ${container.hashCode}');
  }

  /// مقداردهی اولیه سرویس
  Future<void> initialize() async {
    try {
      await _setupCacheDirectory();
      await _loadCacheInfo();
      await _cleanExpiredCache();
      logInfo('✅ Voice Cache Service initialized');
    } catch (e) {
      logInfo('❌ Failed to initialize Voice Cache Service: $e');
    }
  }

  /// راه‌اندازی دایرکتوری کش
  Future<void> _setupCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory(path.join(appDir.path, _cacheDirName));

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// بارگذاری اطلاعات کش از SharedPreferences
  Future<void> _loadCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheInfoJson = prefs.getString(_cacheInfoKey);

      if (cacheInfoJson != null) {
        final Map<String, dynamic> cacheInfoMap = jsonDecode(cacheInfoJson);
        _cacheInfo = cacheInfoMap
            .map((key, value) => MapEntry(key, VoiceCacheInfo.fromMap(value)));
      }
    } catch (e) {
      logInfo('⚠️ Error loading voice cache info: $e');
      _cacheInfo = {};
    }
  }

  /// ذخیره اطلاعات کش در SharedPreferences
  Future<void> _saveCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheInfoMap =
          _cacheInfo.map((key, value) => MapEntry(key, value.toMap()));
      await prefs.setString(_cacheInfoKey, jsonEncode(cacheInfoMap));
    } catch (e) {
      logInfo('⚠️ Error saving voice cache info: $e');
    }
  }

  /// کش کردن فایل وویس از URL
  Future<String?> cacheVoiceFile(String url, {int? maxAgeDays}) async {
    try {
      if (_cacheDir == null) await _setupCacheDirectory();

      final urlHash = _generateUrlHash(url);
      final fileName = '$urlHash.m4a';
      final filePath = path.join(_cacheDir!.path, fileName);
      final file = File(filePath);

      // اگر فایل قبلاً کش شده و هنوز معتبر است
      if (await file.exists() && _isCacheValid(urlHash, maxAgeDays)) {
        _updateCacheInfo(urlHash, filePath);
        return filePath;
      }

      // دانلود و کش کردن فایل
      final downloadedFile = await _downloadAndCache(url, filePath);
      if (downloadedFile != null) {
        _updateCacheInfo(urlHash, filePath);
        await _saveCacheInfo();
        return filePath;
      }

      return null;
    } catch (e) {
      logInfo('❌ Error caching voice file: $e');
      return null;
    }
  }

  /// کش کردن فایل وویس از فایل محلی
  Future<String?> cacheLocalVoiceFile(String url, File localFile,
      {int? maxAgeDays}) async {
    try {
      if (_cacheDir == null) await _setupCacheDirectory();

      final urlHash = _generateUrlHash(url);
      final fileName = '$urlHash.m4a';
      final filePath = path.join(_cacheDir!.path, fileName);
      // final targetFile = File(filePath); // Not needed

      // کپی کردن فایل محلی به کش
      await localFile.copy(filePath);

      _updateCacheInfo(urlHash, filePath);
      await _saveCacheInfo();

      logInfo('✅ Voice file cached locally: $filePath');
      return filePath;
    } catch (e) {
      logInfo('❌ Error caching local voice file: $e');
      return null;
    }
  }

  /// دانلود و کش کردن فایل
  Future<File?> _downloadAndCache(String url, String filePath) async {
    try {
      final uri = Uri.parse(url);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
      }

      await sink.close();
      return file;
    } catch (e) {
      logInfo('❌ Error downloading voice file: $e');
      return null;
    }
  }

  /// تولید هش از URL
  String _generateUrlHash(String url) {
    return url.hashCode.abs().toString();
  }

  /// بررسی اعتبار کش
  bool _isCacheValid(String urlHash, int? maxAgeDays) {
    final cacheInfo = _cacheInfo[urlHash];
    if (cacheInfo == null) return false;

    final maxAge = maxAgeDays ?? 7;
    final expirationDate = cacheInfo.cachedAt.add(Duration(days: maxAge));
    return DateTime.now().isBefore(expirationDate);
  }

  /// به‌روزرسانی اطلاعات کش
  void _updateCacheInfo(String urlHash, String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      _cacheInfo[urlHash] = VoiceCacheInfo(
        urlHash: urlHash,
        filePath: filePath,
        fileSize: file.lengthSync(),
        cachedAt: DateTime.now(),
      );
    }
  }

  /// دریافت فایل کش شده
  Future<File?> getCachedFile(String url) async {
    try {
      final urlHash = _generateUrlHash(url);
      final cacheInfo = _cacheInfo[urlHash];

      if (cacheInfo != null) {
        final file = File(cacheInfo.filePath);
        if (await file.exists()) {
          return file;
        } else {
          // فایل حذف شده، اطلاعات کش را پاک کن
          _cacheInfo.remove(urlHash);
          await _saveCacheInfo();
        }
      }

      return null;
    } catch (e) {
      logInfo('❌ Error getting cached file: $e');
      return null;
    }
  }

  /// بررسی وجود فایل کش شده
  bool isCached(String url) {
    final urlHash = _generateUrlHash(url);
    return _cacheInfo.containsKey(urlHash);
  }

  /// پاک کردن کش منقضی شده
  Future<void> _cleanExpiredCache() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];

      for (final entry in _cacheInfo.entries) {
        final cacheInfo = entry.value;
        final expirationDate = cacheInfo.cachedAt.add(const Duration(days: 7));

        if (now.isAfter(expirationDate)) {
          expiredKeys.add(entry.key);
        }
      }

      for (final key in expiredKeys) {
        await _removeCacheEntry(key);
      }

      if (expiredKeys.isNotEmpty) {
        await _saveCacheInfo();
        logInfo('🧹 Cleaned ${expiredKeys.length} expired voice cache entries');
      }
    } catch (e) {
      logInfo('❌ Error cleaning expired cache: $e');
    }
  }

  /// حذف یک ورودی کش
  Future<void> _removeCacheEntry(String urlHash) async {
    try {
      final cacheInfo = _cacheInfo[urlHash];
      if (cacheInfo != null) {
        final file = File(cacheInfo.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        _cacheInfo.remove(urlHash);
      }
    } catch (e) {
      logInfo('❌ Error removing cache entry: $e');
    }
  }

  /// پاک کردن تمام کش
  Future<void> clearAllCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }

      _cacheInfo.clear();
      await _saveCacheInfo();
      logInfo('🧹 All voice cache cleared');
    } catch (e) {
      logInfo('❌ Error clearing all cache: $e');
    }
  }

  /// دریافت حجم کش
  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;

      for (final cacheInfo in _cacheInfo.values) {
        totalSize += cacheInfo.fileSize;
      }

      return totalSize;
    } catch (e) {
      logInfo('❌ Error getting cache size: $e');
      return 0;
    }
  }

  /// دریافت تعداد فایل‌های کش شده
  int getCacheCount() {
    return _cacheInfo.length;
  }

  /// دریافت اطلاعات کش
  Map<String, VoiceCacheInfo> getCacheInfo() {
    return Map.from(_cacheInfo);
  }
}

/// اطلاعات کش فایل وویس
class VoiceCacheInfo {
  final String urlHash;
  final String filePath;
  final int fileSize;
  final DateTime cachedAt;

  VoiceCacheInfo({
    required this.urlHash,
    required this.filePath,
    required this.fileSize,
    required this.cachedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'urlHash': urlHash,
      'filePath': filePath,
      'fileSize': fileSize,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  factory VoiceCacheInfo.fromMap(Map<String, dynamic> map) {
    return VoiceCacheInfo(
      urlHash: map['urlHash'],
      filePath: map['filePath'],
      fileSize: map['fileSize'],
      cachedAt: DateTime.parse(map['cachedAt']),
    );
  }
}
