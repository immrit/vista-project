import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'file_manager_service.dart';
import 'uploadFileChatService.dart';
import 'uploadImageChatService.dart';

/// مدیریت پیشرفته فایل‌ها در چت - شبیه تلگرام
class AdvancedFileManager {
  static AdvancedFileManager? _instance;
  static AdvancedFileManager get instance {
    _instance ??= AdvancedFileManager._();
    return _instance!;
  }

  AdvancedFileManager._() {
    _init();
  }

  // تنظیمات کش
  static const int maxCacheSizeMB = 500; // حداکثر حجم کش 500MB
  static const Duration maxCacheAge =
      Duration(days: 30); // حداکثر عمر فایل‌ها 30 روز
  static const int maxConcurrentDownloads = 3; // حداکثر دانلود همزمان

  // تنظیمات اتومات دانلود
  bool _autoDownloadEnabled = true;
  int _maxAutoDownloadSizeKB = 1024; // حداکثر حجم اتومات دانلود 1MB

  // کش و دانلود
  final Map<String, FileDownloadTask> _activeDownloads = {};
  final Map<String, File> _fileCache = {};
  final Set<String> _recentlyViewedFiles = {};
  final Map<String, Completer<File?>> _downloadCompleters = {};

  // تنظیمات کاربر
  late SharedPreferences _prefs;
  final String _autoDownloadKey = 'chat_auto_download';
  final String _maxAutoDownloadSizeKey = 'chat_max_auto_download_size_kb';
  final String _fileCacheKey = 'chat_file_cache';

  // Callbacks برای UI updates
  final StreamController<FileDownloadProgress> _progressController =
      StreamController<FileDownloadProgress>.broadcast();

  Stream<FileDownloadProgress> get downloadProgress =>
      _progressController.stream;

  final StreamController<FileUploadProgress> _uploadProgressController =
      StreamController<FileUploadProgress>.broadcast();

  Stream<FileUploadProgress> get uploadProgress =>
      _uploadProgressController.stream;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    await _loadCache();
    await _cleanExpiredCache();
  }

  Future<void> _loadSettings() async {
    _autoDownloadEnabled = _prefs.getBool(_autoDownloadKey) ?? true;
    _maxAutoDownloadSizeKB = _prefs.getInt(_maxAutoDownloadSizeKey) ?? 1024;
  }

  Future<void> _loadCache() async {
    final cacheData = _prefs.getString(_fileCacheKey);
    if (cacheData != null) {
      try {
        final Map<String, dynamic> cache = json.decode(cacheData);
        for (final entry in cache.entries) {
          final file = File(entry.value);
          if (await file.exists()) {
            _fileCache[entry.key] = file;
          }
        }
      } catch (e) {
        debugPrint('Error loading file cache: $e');
      }
    }
  }

  Future<void> _saveCache() async {
    final cacheData = _fileCache.map((key, file) => MapEntry(key, file.path));
    await _prefs.setString(_fileCacheKey, json.encode(cacheData));
  }

  /// تنظیم اتومات دانلود
  Future<void> setAutoDownloadEnabled(bool enabled) async {
    _autoDownloadEnabled = enabled;
    await _prefs.setBool(_autoDownloadKey, enabled);
  }

  /// تنظیم حداکثر حجم اتومات دانلود
  Future<void> setMaxAutoDownloadSizeKB(int sizeKB) async {
    _maxAutoDownloadSizeKB = sizeKB;
    await _prefs.setInt(_maxAutoDownloadSizeKey, sizeKB);
  }

  /// بررسی اینکه آیا فایل باید اتومات دانلود شود
  bool shouldAutoDownload(String url, int? fileSizeBytes) {
    if (!_autoDownloadEnabled) return false;
    if (fileSizeBytes == null) return false;
    final fileSizeKB = fileSizeBytes / 1024;
    return fileSizeKB <= _maxAutoDownloadSizeKB;
  }

  /// دریافت فایل از کش یا دانلود اتومات
  Future<File?> getFile(String url, {bool forceDownload = false}) async {
    // بررسی کش
    if (!forceDownload && _fileCache.containsKey(url)) {
      final cachedFile = _fileCache[url]!;
      if (await cachedFile.exists()) {
        _recentlyViewedFiles.add(url);
        return cachedFile;
      } else {
        _fileCache.remove(url);
      }
    }

    // بررسی دانلود فعال
    if (_downloadCompleters.containsKey(url)) {
      return _downloadCompleters[url]!.future;
    }

    // بررسی حداکثر دانلود همزمان
    if (_activeDownloads.length >= maxConcurrentDownloads) {
      // منتظر تکمیل یکی از دانلودها
      final completer = Completer<File?>();
      _downloadCompleters[url] = completer;

      // برگرداندن null تا UI نشان دهد در صف انتظار است
      return null;
    }

    // شروع دانلود
    return downloadFile(url);
  }

  /// دانلود فایل با پیشرفت
  Future<File?> downloadFile(String url, {Function(double)? onProgress}) async {
    if (_downloadCompleters.containsKey(url)) {
      return _downloadCompleters[url]!.future;
    }

    final completer = Completer<File?>();
    _downloadCompleters[url] = completer;

    try {
      // تعیین پوشه ذخیره‌سازی
      Directory targetDir;
      if (_isPdfFile(url)) {
        targetDir = await FileManagerService.getFilesDirectory();
      } else if (_isImageFile(url)) {
        targetDir = await FileManagerService.getImageDirectory();
      } else {
        targetDir = await FileManagerService.getFilesDirectory();
      }

      // تولید نام فایل پایدار از URL برای استفاده به عنوان کش
      final safeFileName =
          FileManagerService.generateStableFileNameFromUrl(url);
      final filePath = path.join(targetDir.path, safeFileName);
      final file = File(filePath);

      // بررسی وجود فایل
      if (await file.exists() && await FileManagerService.isFileValid(file)) {
        _fileCache[url] = file;
        _recentlyViewedFiles.add(url);
        await _saveCache();
        completer.complete(file);
        _downloadCompleters.remove(url);
        return file;
      }

      // ایجاد دانلود task
      final task = FileDownloadTask(
        url: url,
        filePath: filePath,
        onProgress: (progress) {
          _progressController
              .add(FileDownloadProgress(url: url, progress: progress));
          onProgress?.call(progress);
        },
        onComplete: (downloadedFile) async {
          if (downloadedFile != null) {
            _fileCache[url] = downloadedFile;
            _recentlyViewedFiles.add(url);
            await _saveCache();
          }
          _activeDownloads.remove(url);
          completer.complete(downloadedFile);
          _downloadCompleters.remove(url);
        },
        onError: (error) {
          _activeDownloads.remove(url);
          completer.completeError(error);
          _downloadCompleters.remove(url);
        },
      );

      _activeDownloads[url] = task;
      task.start();

      return completer.future;
    } catch (e) {
      _downloadCompleters.remove(url);
      completer.completeError(e);
      rethrow;
    }
  }

  /// آپلود فایل با پیشرفت
  Future<String?> uploadFile(File file, String conversationId,
      {Function(double)? onProgress, String fileType = 'document'}) async {
    try {
      final uploadId =
          '${conversationId}_${file.path.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

      // گزارش شروع اپلود
      _uploadProgressController.add(FileUploadProgress(
          id: uploadId,
          fileName: path.basename(file.path),
          progress: 0.0,
          status: UploadStatus.uploading));

      String? resultUrl;

      if (fileType == 'document' || _isPdfFile(file.path)) {
        resultUrl = await ChatFileUploadService.uploadChatPdfFile(
          file,
          conversationId,
          onProgress: (progress) {
            _uploadProgressController.add(FileUploadProgress(
                id: uploadId,
                fileName: path.basename(file.path),
                progress: progress,
                status: UploadStatus.uploading));
            onProgress?.call(progress);
          },
        );
      } else {
        // برای تصاویر
        resultUrl = await ChatImageUploadService.uploadChatImage(
          file,
          conversationId,
          onProgress: (progress) {
            _uploadProgressController.add(FileUploadProgress(
                id: uploadId,
                fileName: path.basename(file.path),
                progress: progress,
                status: UploadStatus.uploading));
            onProgress?.call(progress);
          },
        );
      }

      // گزارش تکمیل اپلود
      _uploadProgressController.add(FileUploadProgress(
          id: uploadId,
          fileName: path.basename(file.path),
          progress: 1.0,
          status: resultUrl != null
              ? UploadStatus.completed
              : UploadStatus.failed));

      return resultUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  /// پاکسازی کش منقضی شده
  Future<void> _cleanExpiredCache() async {
    try {
      await FileManagerService.cleanOldFiles(maxAge: maxCacheAge);

      // پاکسازی کش داخلی
      final now = DateTime.now();
      final expiredUrls = <String>[];

      for (final entry in _fileCache.entries) {
        final file = entry.value;
        if (await file.exists()) {
          final lastModified = await file.lastModified();
          if (now.difference(lastModified) > maxCacheAge) {
            try {
              await file.delete();
              expiredUrls.add(entry.key);
            } catch (e) {
              debugPrint('Error deleting expired file: $e');
            }
          }
        } else {
          expiredUrls.add(entry.key);
        }
      }

      // پاکسازی از کش
      for (final url in expiredUrls) {
        _fileCache.remove(url);
      }

      if (expiredUrls.isNotEmpty) {
        await _saveCache();
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }

  /// پاکسازی کش
  Future<void> clearCache() async {
    try {
      _fileCache.clear();
      _recentlyViewedFiles.clear();
      await _saveCache();

      // پاکسازی فایل‌های فیزیکی
      await FileManagerService.clearDirectory('files');
      await FileManagerService.clearDirectory('images');
      await FileManagerService.clearDirectory('audio');
      await FileManagerService.clearDirectory('temp');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// دریافت آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    final stats = await FileManagerService.getStorageInfo();
    return {
      ...stats,
      'cachedUrls': _fileCache.length,
      'recentlyViewed': _recentlyViewedFiles.length,
      'activeDownloads': _activeDownloads.length,
      'autoDownloadEnabled': _autoDownloadEnabled,
      'maxAutoDownloadSizeKB': _maxAutoDownloadSizeKB,
    };
  }

  /// بررسی نوع فایل
  bool _isPdfFile(String url) => url.toLowerCase().contains('.pdf');
  bool _isImageFile(String url) => ['.jpg', '.jpeg', '.png', '.gif', '.webp']
      .any((ext) => url.toLowerCase().contains(ext));

  /// dispose
  void dispose() {
    _progressController.close();
    _uploadProgressController.close();
    for (final task in _activeDownloads.values) {
      task.cancel();
    }
    _activeDownloads.clear();
    _downloadCompleters.clear();
  }
}

/// مدل پیشرفت دانلود
class FileDownloadProgress {
  final String url;
  final double progress;
  final String? fileName;
  final int? fileSize;

  FileDownloadProgress({
    required this.url,
    required this.progress,
    this.fileName,
    this.fileSize,
  });
}

/// مدل پیشرفت اپلود
class FileUploadProgress {
  final String id;
  final String fileName;
  final double progress;
  final UploadStatus status;
  final String? error;

  FileUploadProgress({
    required this.id,
    required this.fileName,
    required this.progress,
    required this.status,
    this.error,
  });
}

/// وضعیت اپلود
enum UploadStatus {
  uploading,
  completed,
  failed,
  cancelled,
}

/// Task دانلود فایل
class FileDownloadTask {
  final String url;
  final String filePath;
  final Function(double) onProgress;
  final Function(File?) onComplete;
  final Function(dynamic) onError;

  http.Client? _client;
  bool _isCancelled = false;

  FileDownloadTask({
    required this.url,
    required this.filePath,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> start() async {
    if (_isCancelled) return;

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final file = File(filePath);
      await file.create(recursive: true);

      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          await file.delete();
          return;
        }

        sink.add(chunk);
        downloaded += chunk.length;

        if (contentLength != null && contentLength > 0) {
          final progress = downloaded / contentLength;
          onProgress(progress.clamp(0.0, 1.0));
        }
      }

      await sink.close();

      // بررسی اعتبار فایل
      if (await FileManagerService.isFileValid(file)) {
        onComplete(file);
      } else {
        await file.delete();
        onComplete(null);
      }
    } catch (e) {
      onError(e);
    } finally {
      _client?.close();
    }
  }

  void cancel() {
    _isCancelled = true;
    _client?.close();
  }
}

