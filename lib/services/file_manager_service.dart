import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileManagerService {
  static const String filesFolder = 'files';
  static const String imageFolder = 'images';
  static const String audioFolder = 'audio_files';
  static const String tempFolder = 'temp';

  /// دریافت مسیر پایه برنامه
  static Future<Directory> _getBaseDirectory() async {
    try {
      Directory base;
      if (Platform.isAndroid) {
        // اولویت با Downloads directory
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          base = downloads;
        } else {
          // fallback به external storage
          base = (await getExternalStorageDirectory())!;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        base = await getApplicationDocumentsDirectory();
      } else if (Platform.isLinux || Platform.isWindows) {
        base = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        base = await getTemporaryDirectory();
      }
      return base;
    } catch (e) {
      // fallback به temp directory
      return await getTemporaryDirectory();
    }
  }

  /// دریافت پوشه Vista
  static Future<Directory> getVistaDirectory() async {
    final base = await _getBaseDirectory();
    final vistaDir = Directory(path.join(base.path, 'Vista'));

    if (!await vistaDir.exists()) {
      await vistaDir.create(recursive: true);
    }

    return vistaDir;
  }

  /// دریافت پوشه مخصوص فایل‌ها (PDF و سایر فرمت‌ها)
  static Future<Directory> getFilesDirectory() async {
    final vistaDir = await getVistaDirectory();
    final filesDir = Directory(path.join(vistaDir.path, filesFolder));

    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    return filesDir;
  }

  /// دریافت پوشه مخصوص تصاویر
  static Future<Directory> getImageDirectory() async {
    final vistaDir = await getVistaDirectory();
    final imageDir = Directory(path.join(vistaDir.path, imageFolder));

    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    return imageDir;
  }

  /// دریافت پوشه مخصوص فایل‌های صوتی
  static Future<Directory> getAudioDirectory() async {
    final vistaDir = await getVistaDirectory();
    final audioDir = Directory(path.join(vistaDir.path, audioFolder));

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  /// دریافت پوشه temporary
  static Future<Directory> getTempDirectory() async {
    final vistaDir = await getVistaDirectory();
    final tempDir = Directory(path.join(vistaDir.path, tempFolder));

    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir;
  }

  /// تولید نام فایل امن و یکتا
  /// نکته: برای فایل‌های دانلودی که قرار است کش شوند، از
  /// [generateStableFileNameFromUrl] استفاده کنید تا هر بار نام جدید تولید نشود.
  static String generateSafeFileName(String originalName, {String? prefix}) {
    // حذف کاراکترهای غیرمجاز
    final safeName = originalName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');

    // محدودیت طول نام فایل
    final maxLength = 100;
    final extension = path.extension(safeName);
    final nameWithoutExt = path.basenameWithoutExtension(safeName);

    final truncatedName = nameWithoutExt.length > maxLength - extension.length
        ? nameWithoutExt.substring(0, maxLength - extension.length)
        : nameWithoutExt;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueName = '${prefix ?? ''}${truncatedName}_$timestamp$extension';

    return uniqueName;
  }

  /// تولید نام فایل پایدار بر اساس URL (بدون افزودن timestamp)
  /// این تابع برای کش دانلود استفاده می‌شود تا روی همان نام فایل ذخیره شود
  /// و در دفعات بعدی با همان URL، فایل از کش خوانده شود.
  static String generateStableFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      var base = path.basename(uri.path);
      // پاک‌سازی نام فایل از کاراکترهای غیرمجاز
      base = base.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      // محدودیت طول
      if (base.length > 120) {
        final ext = path.extension(base);
        final name = path.basenameWithoutExtension(base);
        final truncated =
            name.substring(0, (120 - ext.length).clamp(0, name.length));
        base = '$truncated$ext';
      }
      // اگر نام خالی شد، از hash مسیر استفاده شود
      if (base.isEmpty || base == '.') {
        final sanitized = uri.path.replaceAll('/', '_');
        base = 'file_$sanitized';
      }
      return base;
    } catch (_) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// بررسی وجود فایل و اعتبار آن
  static Future<bool> isFileValid(File file) async {
    try {
      if (!await file.exists()) return false;

      final fileSize = await file.length();
      if (fileSize == 0) return false;

      // حداقل اندازه فایل برای PDF (حداقل 1KB)
      if (fileSize < 1024) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// پاک کردن فایل‌های قدیمی
  static Future<void> cleanOldFiles({
    Duration maxAge = const Duration(days: 30),
    int maxFilesPerDirectory = 100,
  }) async {
    try {
      final directories = [
        await getFilesDirectory(),
        await getImageDirectory(),
        await getAudioDirectory(),
        await getTempDirectory(),
      ];

      final now = DateTime.now();

      for (final dir in directories) {
        if (!await dir.exists()) continue;

        final files = await dir.list().toList();
        final fileList = files.whereType<File>().toList();

        // مرتب‌سازی بر اساس تاریخ آخرین تغییر (قدیمی‌ترین اول)
        fileList.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

        // پاک کردن فایل‌های قدیمی
        for (final file in fileList) {
          try {
            final lastModified = file.lastModifiedSync();
            if (now.difference(lastModified) > maxAge) {
              await file.delete();
            }
          } catch (e) {
            // نادیده گرفتن خطاهای پاک کردن فایل
          }
        }

        // اگر تعداد فایل‌ها بیش از حد مجاز است، قدیمی‌ترین‌ها را پاک کن
        if (fileList.length > maxFilesPerDirectory) {
          final filesToDelete =
              fileList.take(fileList.length - maxFilesPerDirectory);
          for (final file in filesToDelete) {
            try {
              await file.delete();
            } catch (e) {
              // نادیده گرفتن خطاهای پاک کردن فایل
            }
          }
        }
      }
    } catch (e) {
      // نادیده گرفتن خطاهای پاکسازی
    }
  }

  /// دریافت اطلاعات فضای ذخیره‌سازی
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final vistaDir = await getVistaDirectory();
      int totalSize = 0;
      int fileCount = 0;

      final directories = [
        await getFilesDirectory(),
        await getImageDirectory(),
        await getAudioDirectory(),
        await getTempDirectory(),
      ];

      for (final dir in directories) {
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              fileCount++;
              totalSize += await entity.length();
            }
          }
        }
      }

      return {
        'totalSize': totalSize,
        'fileCount': fileCount,
        'directoryPath': vistaDir.path,
      };
    } catch (e) {
      return {
        'totalSize': 0,
        'fileCount': 0,
        'directoryPath': 'unknown',
      };
    }
  }

  /// پاک کردن تمام فایل‌ها در یک پوشه خاص
  static Future<void> clearDirectory(String directoryType) async {
    try {
      Directory targetDir;

      switch (directoryType) {
        case 'files':
          targetDir = await getFilesDirectory();
          break;
        case 'images':
          targetDir = await getImageDirectory();
          break;
        case 'audio':
          targetDir = await getAudioDirectory();
          break;
        case 'temp':
          targetDir = await getTempDirectory();
          break;
        case 'all':
          targetDir = await getVistaDirectory();
          break;
        default:
          return;
      }

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
    } catch (e) {
      // نادیده گرفتن خطاها
    }
  }
}
