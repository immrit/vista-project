import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadInfo {
  final String url;
  final String fileName;
  final String localPath;
  final double progress;
  final DownloadStatus status;
  final String? error;

  DownloadInfo({
    required this.url,
    required this.fileName,
    required this.localPath,
    this.progress = 0.0,
    this.status = DownloadStatus.notStarted,
    this.error,
  });

  DownloadInfo copyWith({
    String? url,
    String? fileName,
    String? localPath,
    double? progress,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadInfo(
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

enum DownloadStatus { notStarted, downloading, completed, failed, canceled }

class MusicDownloadManager extends StateNotifier<Map<String, DownloadInfo>> {
  MusicDownloadManager() : super({});

  // بررسی وضعیت دانلود موزیک
  DownloadInfo? getDownloadInfo(String url) {
    return state[url];
  }

  // بررسی اینکه آیا فایل قبلاً دانلود شده است
  bool isDownloaded(String url) {
    final info = state[url];
    if (info == null) {
      // بررسی می‌کنیم که آیا فایل در مسیر پیش‌فرض وجود دارد
      final fileName = _getFileNameFromUrl(url);
      final path = _getDefaultFilePath(fileName);
      return File(path).existsSync();
    }
    return info.status == DownloadStatus.completed &&
        File(info.localPath).existsSync();
  }

  // دریافت مسیر فایل دانلود شده
  Future<String?> getDownloadedFilePath(String url) async {
    // اگر در حافظه داریم
    final info = state[url];
    if (info != null && info.status == DownloadStatus.completed) {
      if (File(info.localPath).existsSync()) {
        return info.localPath;
      }
    }

    // بررسی در مسیر پیش‌فرض
    final fileName = _getFileNameFromUrl(url);
    final path = _getDefaultFilePath(fileName);
    if (File(path).existsSync()) {
      // اضافه کردن به حافظه
      _updateDownloadState(url, DownloadStatus.completed, 1.0, localPath: path);
      return path;
    }

    return null;
  }

  // شروع دانلود فایل
  Future<String?> downloadMusic(String url,
      {Function(double)? onProgress}) async {
    if (kIsWeb) {
      // در نسخه وب، نیازی به دانلود نیست
      return url;
    }

    // بررسی دسترسی به حافظه
    if (!await _checkStoragePermission()) {
      _updateDownloadState(url, DownloadStatus.failed, 0.0,
          error: 'دسترسی به حافظه داده نشد');
      return null;
    }

    final fileName = _getFileNameFromUrl(url);

    // بررسی می‌کنیم که آیا قبلاً دانلود شده است
    final existingPath = await getDownloadedFilePath(url);
    if (existingPath != null) {
      return existingPath;
    }

    // مسیر ذخیره سازی فایل
    final directory = await getApplicationDownloadsDirectory();
    final filePath = '${directory.path}/$fileName';

    // اگر فایل وجود ندارد، دانلود را آغاز می‌کنیم
    _updateDownloadState(url, DownloadStatus.downloading, 0.0,
        fileName: fileName, localPath: filePath);

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('خطا در دانلود: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          onProgress?.call(progress);
          _updateDownloadState(url, DownloadStatus.downloading, progress,
              fileName: fileName, localPath: filePath);
        }
      }

      await sink.flush();
      await sink.close();

      _updateDownloadState(url, DownloadStatus.completed, 1.0,
          fileName: fileName, localPath: filePath);

      return filePath;
    } catch (e) {
      _updateDownloadState(url, DownloadStatus.failed, 0.0,
          fileName: fileName, localPath: filePath, error: e.toString());
      return null;
    }
  }

  // لغو دانلود
  void cancelDownload(String url) {
    final info = state[url];
    if (info != null && info.status == DownloadStatus.downloading) {
      _updateDownloadState(url, DownloadStatus.canceled, info.progress);

      // حذف فایل ناقص
      try {
        final file = File(info.localPath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('خطا در حذف فایل ناقص: $e');
      }
    }
  }

  // حذف فایل دانلود شده
  Future<bool> deleteDownloadedFile(String url) async {
    final info = state[url];
    String? filePath;

    if (info != null) {
      filePath = info.localPath;
    } else {
      final fileName = _getFileNameFromUrl(url);
      filePath = _getDefaultFilePath(fileName);
    }

    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();

        // حذف از حافظه
        final newState = Map<String, DownloadInfo>.from(state);
        newState.remove(url);
        state = newState;

        return true;
      }
    } catch (e) {
      debugPrint('خطا در حذف فایل: $e');
    }

    return false;
  }

  // دریافت حجم فایل دانلود شده
  Future<String> getFileSize(String url) async {
    final info = state[url];
    String? filePath;

    if (info != null && info.status == DownloadStatus.completed) {
      filePath = info.localPath;
    } else {
      final path = await getDownloadedFilePath(url);
      if (path != null) {
        filePath = path;
      }
    }

    if (filePath != null) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final bytes = await file.length();
          return _formatFileSize(bytes);
        }
      } catch (e) {
        debugPrint('خطا در محاسبه حجم فایل: $e');
      }
    }

    return 'نامشخص';
  }

  // به روز رسانی وضعیت دانلود
  void _updateDownloadState(String url, DownloadStatus status, double progress,
      {String? fileName, String? localPath, String? error}) {
    final currentInfo = state[url];
    final newInfo = (currentInfo ??
            DownloadInfo(
              url: url,
              fileName: fileName ?? _getFileNameFromUrl(url),
              localPath: localPath ??
                  _getDefaultFilePath(fileName ?? _getFileNameFromUrl(url)),
            ))
        .copyWith(
      status: status,
      progress: progress,
      fileName: fileName ?? currentInfo?.fileName,
      localPath: localPath ?? currentInfo?.localPath,
      error: error,
    );

    state = {...state, url: newInfo};
  }

  // دریافت نام فایل از URL
  String _getFileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    String fileName = uri.pathSegments.last;

    // اطمینان از اینکه پسوند فایل صوتی است
    if (!fileName.endsWith('.mp3') &&
        !fileName.endsWith('.wav') &&
        !fileName.endsWith('.ogg') &&
        !fileName.endsWith('.m4a')) {
      fileName = '$fileName.mp3';
    }

    return fileName;
  }

  // دریافت مسیر پیش فرض
  String _getDefaultFilePath(String fileName) {
    // این مقدار باید با مقداری که در مرحله دانلود استفاده می‌شود یکسان باشد
    return '/data/user/0/com.example.yourapp/app_flutter/$fileName';
  }

  // بررسی دسترسی به حافظه
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final storagePermission = await Permission.storage.request();
      if (storagePermission != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  // تبدیل حجم فایل به فرمت قابل خواندن
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// تابعی برای دریافت مسیر دانلود‌های برنامه
Future<Directory> getApplicationDownloadsDirectory() async {
  if (Platform.isAndroid) {
    // استفاده از پوشه داخلی برنامه
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/downloads');

    // ایجاد پوشه اگر وجود ندارد
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return downloadDir;
  } else {
    // برای سیستم‌عامل iOS
    return await getApplicationDocumentsDirectory();
  }
}

// تعریف provider برای استفاده در برنامه
final musicDownloadManagerProvider =
    StateNotifierProvider<MusicDownloadManager, Map<String, DownloadInfo>>(
  (ref) => MusicDownloadManager(),
);
