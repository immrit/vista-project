import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../model/publicPostModel.dart';

/// سرویس تولید قالب استوری Vista
class VistaStoryTemplateGenerator {
  static final VistaStoryTemplateGenerator _instance =
      VistaStoryTemplateGenerator._internal();
  factory VistaStoryTemplateGenerator() => _instance;
  VistaStoryTemplateGenerator._internal();

  Future<File?> generateStoryTemplate({
    required PublicPostModel post,
    required GlobalKey repaintBoundaryKey,
    String? customBackgroundText,
    Color? backgroundColor,
    Color? textColor,
    String? customPostText,
    String? customImageUrl,
  }) async {
    try {
      return await _generateFromWidget(
        repaintBoundaryKey,
        post,
        customBackgroundText: customBackgroundText,
        backgroundColor: backgroundColor,
        textColor: textColor,
        customPostText: customPostText,
        customImageUrl: customImageUrl,
      );
    } catch (e) {
      debugPrint('Error generating Vista story template: $e');
      return null;
    }
  }

  /// تولید تصویر از ویجت Flutter
  Future<File?> _generateFromWidget(
    GlobalKey repaintBoundaryKey,
    PublicPostModel post, {
    String? customBackgroundText,
    Color? backgroundColor,
    Color? textColor,
    String? customPostText,
    String? customImageUrl,
  }) async {
    try {
      debugPrint('=== شروع تولید تصویر از ویجت ===');
      debugPrint('RepaintBoundary key: $repaintBoundaryKey');

      final RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      debugPrint('RenderRepaintBoundary پیدا شد');

      // گرفتن تصویر با رزولوشن مناسب برای استوری
      debugPrint('تبدیل ویجت به تصویر...');
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      debugPrint('اندازه تصویر: ${image.width}x${image.height}');

      // تبدیل به ByteData
      debugPrint('تبدیل تصویر به ByteData...');
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('❌ تبدیل ویجت به تصویر ناموفق');
        throw Exception('Failed to convert widget to image');
      }
      debugPrint('اندازه ByteData: ${byteData.lengthInBytes} بایت');

      // درخواست مجوز ذخیره (برای اندروید 13+)
      debugPrint('درخواست مجوز photos...');
      PermissionStatus status = await Permission.photos.request();
      debugPrint('وضعیت مجوز photos: $status');

      // اگر photos رد شد، photosAddOnly را امتحان کن
      if (status != PermissionStatus.granted) {
        debugPrint('درخواست مجوز photosAddOnly...');
        status = await Permission.photosAddOnly.request();
        debugPrint('وضعیت مجوز photosAddOnly: $status');
      }

      // اگر هر دو رد شدند، از temp directory استفاده کن
      if (status != PermissionStatus.granted) {
        debugPrint('⚠️ مجوز photos رد شد، استفاده از temp directory');
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName =
            'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        debugPrint('فایل در temp directory ذخیره شد: ${file.path}');
        return file;
      }

      // ذخیره تصویر در پوشه Pictures
      debugPrint('دریافت مسیر external storage...');
      final Directory? picturesDir = await getExternalStorageDirectory();
      debugPrint('مسیر external storage: ${picturesDir?.path}');

      if (picturesDir == null) {
        debugPrint(
            '⚠️ دسترسی به external storage ممکن نیست، استفاده از temp directory');
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName =
            'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        debugPrint('فایل در temp directory ذخیره شد: ${file.path}');
        return file;
      }

      // ایجاد پوشه Pictures در external storage
      final Directory picturesPath =
          Directory('${picturesDir.path}/Pictures/Vista');
      debugPrint('مسیر مقصد: ${picturesPath.path}');

      if (!await picturesPath.exists()) {
        debugPrint('ایجاد پوشه Pictures/Vista...');
        await picturesPath.create(recursive: true);
        debugPrint('✅ پوشه ایجاد شد');
      } else {
        debugPrint('✅ پوشه از قبل موجود است');
      }

      final String fileName =
          'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${picturesPath.path}/$fileName');
      debugPrint('نام فایل: $fileName');
      debugPrint('مسیر کامل: ${file.path}');

      debugPrint('نوشتن فایل...');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final fileSize = await file.length();
      debugPrint('اندازه فایل نهایی: $fileSize بایت');
      debugPrint('✅ تصویر با موفقیت تولید شد: ${file.path}');
      debugPrint('=== پایان تولید تصویر ===');

      return file;
    } catch (e, stackTrace) {
      debugPrint('❌ خطا در تولید تصویر: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== پایان تولید تصویر با خطا ===');
      return null;
    }
  }

  /// اشتراک‌گذاری قالب به اینستاگرام استوری
  Future<void> shareToInstagramStory(File imageFile) async {
    try {
      final String filePath = imageFile.path;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Shared from Vista',
        subject: 'Vista Story Template',
      );
    } catch (e) {
      debugPrint('Error sharing to Instagram: $e');
      throw Exception('Failed to share to Instagram');
    }
  }

  /// ذخیره تصویر در گالری
  Future<bool> saveToGallery(File imageFile) async {
    try {
      debugPrint('=== شروع ذخیره تصویر ===');
      debugPrint('مسیر فایل ورودی: ${imageFile.path}');
      debugPrint('آیا فایل وجود دارد: ${await imageFile.exists()}');

      if (await imageFile.exists()) {
        final fileSize = await imageFile.length();
        debugPrint('اندازه فایل: $fileSize بایت');
      }

      // درخواست مجوز (برای اندروید 13+)
      debugPrint('درخواست مجوز photos...');
      PermissionStatus status = await Permission.photos.request();
      debugPrint('وضعیت مجوز photos: $status');

      // اگر photos رد شد، photosAddOnly را امتحان کن
      if (status != PermissionStatus.granted) {
        debugPrint('درخواست مجوز photosAddOnly...');
        status = await Permission.photosAddOnly.request();
        debugPrint('وضعیت مجوز photosAddOnly: $status');
      }

      if (status != PermissionStatus.granted) {
        debugPrint('❌ مجوز photos رد شد');
        return false;
      }

      // استفاده از image_gallery_saver برای ذخیره در گالری
      debugPrint('شروع ذخیره با image_gallery_saver...');

      try {
        final Uint8List imageBytes = await imageFile.readAsBytes();

        final result = await ImageGallerySaver.saveImage(
          imageBytes,
          quality: 100,
          name: 'Vista_Story_${DateTime.now().millisecondsSinceEpoch}',
        );

        debugPrint('نتیجه ذخیره image_gallery_saver: $result');

        if (result['isSuccess'] == true) {
          debugPrint('✅ تصویر با موفقیت در گالری ذخیره شد');
          debugPrint('مسیر ذخیره: ${result['filePath']}');
          debugPrint('=== پایان ذخیره تصویر ===');
          return true;
        } else {
          debugPrint(
              '❌ خطا در ذخیره با image_gallery_saver: ${result['errorMessage']}');
          debugPrint('تلاش با روش fallback...');
          return await _saveToGalleryFallback(imageFile);
        }
      } catch (e) {
        debugPrint('❌ خطا در image_gallery_saver: $e');
        debugPrint('تلاش با روش fallback...');
        return await _saveToGalleryFallback(imageFile);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ خطا در ذخیره تصویر: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('تلاش با روش fallback...');

      // fallback به روش قدیمی
      return await _saveToGalleryFallback(imageFile);
    }
  }

  /// روش fallback برای ذخیره در گالری
  Future<bool> _saveToGalleryFallback(File imageFile) async {
    try {
      debugPrint('=== شروع fallback ذخیره ===');

      // کپی فایل به پوشه Pictures
      debugPrint('دریافت مسیر external storage...');
      final Directory? picturesDir = await getExternalStorageDirectory();
      debugPrint('مسیر external storage: ${picturesDir?.path}');

      if (picturesDir == null) {
        debugPrint('❌ دسترسی به external storage ممکن نیست');
        return false;
      }

      final Directory picturesPath =
          Directory('${picturesDir.path}/Pictures/Vista');
      debugPrint('مسیر مقصد: ${picturesPath.path}');

      if (!await picturesPath.exists()) {
        debugPrint('ایجاد پوشه Pictures/Vista...');
        await picturesPath.create(recursive: true);
        debugPrint('✅ پوشه ایجاد شد');
      } else {
        debugPrint('✅ پوشه از قبل موجود است');
      }

      final String fileName =
          'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
      final File savedFile = File('${picturesPath.path}/$fileName');
      debugPrint('نام فایل نهایی: $fileName');
      debugPrint('مسیر کامل فایل: ${savedFile.path}');

      debugPrint('شروع کپی فایل...');
      await imageFile.copy(savedFile.path);

      final savedFileSize = await savedFile.length();
      debugPrint('اندازه فایل ذخیره شده: $savedFileSize بایت');
      debugPrint('✅ تصویر با موفقیت ذخیره شد: ${savedFile.path}');
      debugPrint('=== پایان fallback ذخیره ===');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ خطا در fallback ذخیره: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== پایان fallback ذخیره با خطا ===');
      return false;
    }
  }
}
