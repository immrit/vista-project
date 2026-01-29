import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/logging_utility.dart';

/// سرویس پاکسازی خودکار کش و فایل‌های موقت
/// اجرا در background isolate برای جلوگیری از کندی UI
class AutoCleanService {
  AutoCleanService._();

  static const String _lastCleanKey = 'auto_clean_last_run';

  // تنظیمات
  static const int _maxCacheSizeMB = 500; // حداکثر حجم کش به مگابایت
  static const int _maxFileAgeDays = 30; // حداکثر سن فایل به روز
  static const Duration _cleanInterval = Duration(hours: 24); // فاصله پاکسازی

  /// اجرای پاکسازی در background (فراخوانی در main.dart)
  static Future<void> performMaintenanceIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanTimestamp = prefs.getInt(_lastCleanKey) ?? 0;
      final lastClean = DateTime.fromMillisecondsSinceEpoch(lastCleanTimestamp);

      // اگر کمتر از 24 ساعت پیش پاکسازی شده، انجام نده
      if (DateTime.now().difference(lastClean) < _cleanInterval) {
        logInfo(
            '🧹 AutoClean: Skipping - last clean was ${DateTime.now().difference(lastClean).inHours}h ago');
        return;
      }

      // اجرا در isolate جداگانه
      await compute(_performMaintenanceIsolate, null);

      // ثبت زمان پاکسازی
      await prefs.setInt(_lastCleanKey, DateTime.now().millisecondsSinceEpoch);
      logInfo('🧹 AutoClean: Maintenance completed');
    } catch (e) {
      logInfo('🧹 AutoClean Error: $e');
    }
  }

  /// تابع اصلی پاکسازی (اجرا در isolate)
  static Future<void> _performMaintenanceIsolate(void _) async {
    try {
      await performMaintenance();
    } catch (_) {}
  }

  /// اجرای پاکسازی (قابل فراخوانی مستقیم برای تست)
  static Future<CleanupResult> performMaintenance() async {
    int deletedFiles = 0;
    int freedBytes = 0;

    try {
      // 1. پاکسازی دایرکتوری کش
      final cacheDir = await getTemporaryDirectory();
      final cacheResult = await _cleanDirectory(
        cacheDir,
        maxAgeDays: _maxFileAgeDays,
        maxSizeMB: _maxCacheSizeMB,
      );
      deletedFiles += cacheResult.deletedFiles;
      freedBytes += cacheResult.freedBytes;

      // 2. پاکسازی دایرکتوری اپلیکیشن (فایل‌های موقت)
      final appDir = await getApplicationDocumentsDirectory();
      final tempSubDir = Directory('${appDir.path}/temp');
      if (await tempSubDir.exists()) {
        final tempResult = await _cleanDirectory(
          tempSubDir,
          maxAgeDays: 7, // فایل‌های موقت زودتر حذف شوند
          maxSizeMB: 100,
        );
        deletedFiles += tempResult.deletedFiles;
        freedBytes += tempResult.freedBytes;
      }

      // 3. پاکسازی voice drafts قدیمی
      final voiceResult = await _cleanVoiceDrafts();
      deletedFiles += voiceResult.deletedFiles;
      freedBytes += voiceResult.freedBytes;

      // 4. پاکسازی تصاویر کش‌شده قدیمی
      final imageResult = await _cleanCachedImages();
      deletedFiles += imageResult.deletedFiles;
      freedBytes += imageResult.freedBytes;

      logInfo(
          '🧹 Cleanup complete: $deletedFiles files, ${(freedBytes / 1024 / 1024).toStringAsFixed(2)} MB freed');

      return CleanupResult(
        deletedFiles: deletedFiles,
        freedBytes: freedBytes,
        success: true,
      );
    } catch (e) {
      logInfo('🧹 Cleanup error: $e');
      return CleanupResult(
        deletedFiles: deletedFiles,
        freedBytes: freedBytes,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// پاکسازی یک دایرکتوری
  static Future<CleanupResult> _cleanDirectory(
    Directory directory, {
    required int maxAgeDays,
    required int maxSizeMB,
  }) async {
    int deletedFiles = 0;
    int freedBytes = 0;

    if (!await directory.exists()) {
      return CleanupResult(deletedFiles: 0, freedBytes: 0, success: true);
    }

    try {
      final now = DateTime.now();
      final maxAge = Duration(days: maxAgeDays);
      final maxSizeBytes = maxSizeMB * 1024 * 1024;

      // جمع‌آوری لیست فایل‌ها با اطلاعات
      final files = <FileInfo>[];
      int totalSize = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.accessed);
            files.add(FileInfo(
              file: entity,
              size: stat.size,
              lastAccessed: stat.accessed,
              age: age,
            ));
            totalSize += stat.size;
          } catch (_) {}
        }
      }

      // مرتب‌سازی بر اساس زمان دسترسی (قدیمی‌ترین اول)
      files.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

      // حذف فایل‌های قدیمی
      for (final fileInfo in files) {
        bool shouldDelete = false;

        // شرط 1: سن بیش از حد مجاز
        if (fileInfo.age > maxAge) {
          shouldDelete = true;
        }

        // شرط 2: حجم کل بیش از حد مجاز (حذف قدیمی‌ترها)
        if (totalSize > maxSizeBytes) {
          shouldDelete = true;
        }

        if (shouldDelete) {
          try {
            final size = fileInfo.size;
            await fileInfo.file.delete();
            deletedFiles++;
            freedBytes += size;
            totalSize -= size;
          } catch (_) {}
        }
      }
    } catch (e) {
      logInfo('🧹 Directory clean error: $e');
    }

    return CleanupResult(
      deletedFiles: deletedFiles,
      freedBytes: freedBytes,
      success: true,
    );
  }

  /// پاکسازی voice drafts قدیمی
  static Future<CleanupResult> _cleanVoiceDrafts() async {
    int deletedFiles = 0;
    int freedBytes = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync().whereType<File>();

      for (final file in files) {
        if (file.path.contains('vista_voice_')) {
          try {
            final stat = await file.stat();
            final age = DateTime.now().difference(stat.modified);

            // حذف voice drafts بیش از 1 روز
            if (age.inHours > 24) {
              final size = stat.size;
              await file.delete();
              deletedFiles++;
              freedBytes += size;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      logInfo('🧹 Voice draft clean error: $e');
    }

    return CleanupResult(
      deletedFiles: deletedFiles,
      freedBytes: freedBytes,
      success: true,
    );
  }

  /// پاکسازی تصاویر کش‌شده قدیمی
  static Future<CleanupResult> _cleanCachedImages() async {
    int deletedFiles = 0;
    int freedBytes = 0;

    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');

      if (!await imageCacheDir.exists()) {
        return CleanupResult(deletedFiles: 0, freedBytes: 0, success: true);
      }

      final result = await _cleanDirectory(
        imageCacheDir,
        maxAgeDays: 14, // تصاویر کش‌شده 2 هفته نگهداری شوند
        maxSizeMB: 200,
      );

      deletedFiles = result.deletedFiles;
      freedBytes = result.freedBytes;
    } catch (e) {
      logInfo('🧹 Image cache clean error: $e');
    }

    return CleanupResult(
      deletedFiles: deletedFiles,
      freedBytes: freedBytes,
      success: true,
    );
  }

  /// دریافت حجم کل کش
  static Future<int> getCacheSize() async {
    int totalSize = 0;

    try {
      final cacheDir = await getTemporaryDirectory();

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (_) {}
        }
      }
    } catch (_) {}

    return totalSize;
  }

  /// فرمت حجم به رشته قابل خواندن
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// نتیجه عملیات پاکسازی
class CleanupResult {
  final int deletedFiles;
  final int freedBytes;
  final bool success;
  final String? error;

  const CleanupResult({
    required this.deletedFiles,
    required this.freedBytes,
    required this.success,
    this.error,
  });
}

/// اطلاعات یک فایل برای مرتب‌سازی
class FileInfo {
  final File file;
  final int size;
  final DateTime lastAccessed;
  final Duration age;

  const FileInfo({
    required this.file,
    required this.size,
    required this.lastAccessed,
    required this.age,
  });
}
