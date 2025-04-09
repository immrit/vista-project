import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// وضعیت‌های مختلف دانلود
enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

// کلاس برای ذخیره اطلاعات دانلود
class DownloadInfo {
  final DownloadStatus status;
  final double progress;
  final String? localPath;

  DownloadInfo({
    required this.status,
    this.progress = 0.0,
    this.localPath,
  });
}

// نوتیفایر برای مدیریت دانلود
class MusicDownloadManagerNotifier
    extends StateNotifier<Map<String, DownloadInfo>> {
  MusicDownloadManagerNotifier() : super({});

  // بررسی وضعیت دانلود یک فایل
  bool isDownloaded(String url) {
    final info = state[url];
    return info?.status == DownloadStatus.downloaded && info?.localPath != null;
  }

  // گرفتن مسیر فایل دانلود شده
  String? getDownloadPath(String url) {
    final info = state[url];
    if (info?.status == DownloadStatus.downloaded) {
      return info?.localPath;
    }
    return null;
  }

  // دانلود موزیک با استفاده از http

  Future<String?> downloadMusic(
    String url, {
    Function(double)? onProgress,
  }) async {
    debugPrint('شروع دانلود موزیک از آدرس: $url');

    // بررسی معتبر بودن URL
    if (!await _isValidUrl(url)) {
      state = {
        ...state,
        url: DownloadInfo(
          status: DownloadStatus.failed,
          progress: 0,
        ),
      };
      return null;
    }
    // اگر قبلاً دانلود شده باشد، مسیر را برمی‌گرداند
    if (isDownloaded(url)) {
      debugPrint('فایل قبلاً دانلود شده است: ${state[url]?.localPath}');
      return state[url]?.localPath;
    }

    // بررسی و درخواست دسترسی به حافظه
    if (!kIsWeb && !await _checkAndRequestPermission()) {
      debugPrint('خطا: دسترسی به حافظه وجود ندارد');
      state = {
        ...state,
        url: DownloadInfo(
          status: DownloadStatus.failed,
          progress: 0,
        ),
      };
      return null;
    }

    try {
      // تنظیم مسیر ذخیره‌سازی
      final fileName = url.split('/').last;
      Directory? directory;
      debugPrint('نام فایل: $fileName');

      if (Platform.isAndroid) {
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            debugPrint(
                'پوشه دانلود پیش‌فرض وجود ندارد، استفاده از مسیر جایگزین');
            directory = await getExternalStorageDirectory();
          }
        } catch (e) {
          debugPrint('خطا در دسترسی به پوشه دانلود اندروید: $e');
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        debugPrint(
            'هیچ پوشه‌ای برای ذخیره‌سازی پیدا نشد، استفاده از پوشه موقت');
        directory = await getTemporaryDirectory();
      }

      final savePath = '${directory.path}/$fileName';
      debugPrint('مسیر ذخیره‌سازی: $savePath');

      // بررسی اگر فایل قبلاً دانلود شده باشد
      final file = File(savePath);
      if (await file.exists()) {
        debugPrint('فایل از قبل موجود است در: $savePath');
        state = {
          ...state,
          url: DownloadInfo(
            status: DownloadStatus.downloaded,
            progress: 1,
            localPath: savePath,
          ),
        };
        return savePath;
      }

      // شروع دانلود
      debugPrint('شروع دانلود فایل...');
      state = {
        ...state,
        url: DownloadInfo(
          status: DownloadStatus.downloading,
          progress: 0,
        ),
      };

      // دریافت اطلاعات فایل برای تخمین اندازه
      debugPrint('دریافت اندازه فایل...');
      final response = await http.head(Uri.parse(url));
      final fileSize =
          int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
      debugPrint('اندازه فایل: $fileSize بایت');

      // دانلود با استفاده از http
      debugPrint('ارسال درخواست دانلود...');
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await http.Client().send(request);

      debugPrint('شروع دریافت داده‌ها...');
      final output = file.openWrite();
      int receivedBytes = 0;

      await for (final chunk in streamedResponse.stream) {
        output.add(chunk);
        receivedBytes += chunk.length;

        if (fileSize > 0) {
          final progress = receivedBytes / fileSize;
          state = {
            ...state,
            url: DownloadInfo(
              status: DownloadStatus.downloading,
              progress: progress,
            ),
          };
          onProgress?.call(progress);

          if (receivedBytes % (fileSize ~/ .5) == 0) {
            debugPrint(
                'پیشرفت دانلود: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      }

      await output.close();
      debugPrint('دانلود کامل شد. فایل در $savePath ذخیره شد');

      // دانلود موفقیت‌آمیز
      state = {
        ...state,
        url: DownloadInfo(
          status: DownloadStatus.downloaded,
          progress: 1,
          localPath: savePath,
        ),
      };

      return savePath;
    } catch (e, stackTrace) {
      debugPrint('خطا در دانلود: $e');
      debugPrint('جزئیات خطا: $stackTrace');
      state = {
        ...state,
        url: DownloadInfo(
          status: DownloadStatus.failed,
          progress: 0,
        ),
      };
      return null;
    }
  }

  // بررسی و درخواست دسترسی به حافظه
  Future<bool> _checkAndRequestPermission() async {
    if (Platform.isAndroid) {
      debugPrint('بررسی دسترسی به حافظه برای اندروید...');

      // دریافت اطلاعات نسخه اندروید
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        // اندروید 11 یا بالاتر
        debugPrint('اندروید 11 یا بالاتر شناسایی شد');

        // درخواست دسترسی MANAGE_EXTERNAL_STORAGE
        if (!await Permission.manageExternalStorage.isGranted) {
          debugPrint('درخواست دسترسی مدیریت فایل...');
          final status = await Permission.manageExternalStorage.request();
          if (status != PermissionStatus.granted) {
            debugPrint('دسترسی به مدیریت فایل رد شد');
            return false;
          }
        }
        return true;
      } else {
        // برای نسخه‌های قدیمی‌تر
        debugPrint('درخواست دسترسی ذخیره‌سازی استاندارد...');
        final status = await Permission.storage.request();
        return status == PermissionStatus.granted;
      }
    }
    return true; // برای iOS و سایر پلتفرم‌ها
  }

  Future<Directory?> _getStorageDirectory() async {
    try {
      if (Platform.isAndroid) {
        // ابتدا پوشه Downloads را امتحان می‌کنیم
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          debugPrint('استفاده از پوشه Download');
          return downloadsDir;
        }

        // اگر در دسترس نبود، از مسیر اختصاصی برنامه استفاده می‌کنیم
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          debugPrint('استفاده از پوشه اختصاصی برنامه: ${appDir.path}');
          return appDir;
        }
      }

      // برای iOS از مسیر Documents استفاده می‌کنیم
      if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }

      // در نهایت از پوشه موقت استفاده می‌کنیم
      debugPrint('استفاده از پوشه موقت');
      return await getTemporaryDirectory();
    } catch (e) {
      debugPrint('خطا در دریافت مسیر ذخیره‌سازی: $e');
      return await getTemporaryDirectory();
    }
  }

  // اضافه کردن متد جدید برای بررسی معتبر بودن URL
  Future<bool> _isValidUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // بررسی می‌کنیم که URL به یک سرور واقعی اشاره کند
      if (!uri.hasScheme || !uri.hasAuthority) {
        debugPrint('URL نامعتبر است: $url');
        return false;
      }

      // بررسی می‌کنیم که فایل قابل دسترسی باشد
      final response = await http.head(uri).timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        debugPrint('خطا در دسترسی به URL: کد وضعیت ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('خطا در بررسی URL: $e');
      return false;
    }
  }

  // حذف یک فایل دانلود شده
  Future<bool> deleteDownloadedFile(String url) async {
    final path = getDownloadPath(url);
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        state = {
          ...state,
          url: DownloadInfo(
            status: DownloadStatus.notDownloaded,
            progress: 0,
          ),
        };
        return true;
      } catch (e) {
        debugPrint('خطا در حذف فایل: $e');
        return false;
      }
    }
    return false;
  }
}

// پرووایدر برای MusicDownloadManager
final musicDownloadManagerProvider = StateNotifierProvider<
    MusicDownloadManagerNotifier, Map<String, DownloadInfo>>(
  (ref) => MusicDownloadManagerNotifier(),
);
