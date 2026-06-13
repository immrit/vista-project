import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

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
    bool waitForRender = true,
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
        waitForRender: waitForRender,
      );
    } catch (e) {
      logDebug('Error generating Vista story template: $e');
      return null;
    }
  }

  /// تولید فقط بک‌گراند VISTA (بدون کارت پست)
  Future<File?> generateBackgroundOnly({
    required GlobalKey repaintBoundaryKey,
    String? customBackgroundText,
    Color? backgroundColor,
    Color? textColor,
  }) async {
    try {
      return await _generateBackgroundFromWidget(
        repaintBoundaryKey,
        customBackgroundText: customBackgroundText,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );
    } catch (e) {
      logDebug('Error generating Vista background: $e');
      return null;
    }
  }

  /// تولید فقط کارت پست (بدون بک‌گراند)
  Future<File?> generatePostCardOnly({
    required PublicPostModel post,
    required GlobalKey repaintBoundaryKey,
    String? customPostText,
    String? customImageUrl,
  }) async {
    try {
      return await _generatePostCardFromWidget(
        repaintBoundaryKey,
        post,
        customPostText: customPostText,
        customImageUrl: customImageUrl,
      );
    } catch (e) {
      logDebug('Error generating Vista post card: $e');
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
    bool waitForRender = true,
  }) async {
    try {
      logDebug('=== شروع تولید تصویر از ویجت ===');
      logDebug('RepaintBoundary key: $repaintBoundaryKey');

      if (waitForRender) {
        await _waitForWidgetRender();
      }

      final BuildContext? context = repaintBoundaryKey.currentContext;
      if (context == null) {
        debugPrint(
            '❌ خطا: repaintBoundaryKey.currentContext is null for story template');
        return null;
      }
      final RenderRepaintBoundary boundary =
          context.findRenderObject() as RenderRepaintBoundary;
      logDebug('RenderRepaintBoundary پیدا شد');

      // گرفتن تصویر با رزولوشن بالا برای کیفیت بهتر
      logDebug('تبدیل ویجت به تصویر...');
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      logDebug('اندازه تصویر: ${image.width}x${image.height}');

      // تبدیل به ByteData
      logDebug('تبدیل تصویر به ByteData...');
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        logDebug('❌ تبدیل ویجت به تصویر ناموفق');
        throw Exception('Failed to convert widget to image');
      }
      logDebug('اندازه ByteData: ${byteData.lengthInBytes} بایت');

      // درخواست مجوز ذخیره (برای اندروید 13+)
      logDebug('درخواست مجوز photos...');
      PermissionStatus status = await Permission.photos.request();
      logDebug('وضعیت مجوز photos: $status');

      // اگر photos رد شد، photosAddOnly را امتحان کن
      if (status != PermissionStatus.granted) {
        logDebug('درخواست مجوز photosAddOnly...');
        status = await Permission.photosAddOnly.request();
        logDebug('وضعیت مجوز photosAddOnly: $status');
      }

      // اگر هر دو رد شدند، از temp directory استفاده کن
      if (status != PermissionStatus.granted) {
        logDebug('⚠️ مجوز photos رد شد، استفاده از temp directory');
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName =
            'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        logDebug('فایل در temp directory ذخیره شد: ${file.path}');
        return file;
      }

      // ذخیره تصویر در پوشه Pictures
      logDebug('دریافت مسیر external storage...');
      final Directory? picturesDir = await getExternalStorageDirectory();
      logDebug('مسیر external storage: ${picturesDir?.path}');

      if (picturesDir == null) {
        debugPrint(
            '⚠️ دسترسی به external storage ممکن نیست، استفاده از temp directory');
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName =
            'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        logDebug('فایل در temp directory ذخیره شد: ${file.path}');
        return file;
      }

      // ایجاد پوشه Pictures در external storage
      final Directory picturesPath =
          Directory('${picturesDir.path}/Pictures/Vista');
      logDebug('مسیر مقصد: ${picturesPath.path}');

      if (!await picturesPath.exists()) {
        logDebug('ایجاد پوشه Pictures/Vista...');
        await picturesPath.create(recursive: true);
        logDebug('✅ پوشه ایجاد شد');
      } else {
        logDebug('✅ پوشه از قبل موجود است');
      }

      final String fileName =
          'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${picturesPath.path}/$fileName');
      logDebug('نام فایل: $fileName');
      logDebug('مسیر کامل: ${file.path}');

      logDebug('نوشتن فایل...');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final fileSize = await file.length();
      logDebug('اندازه فایل نهایی: $fileSize بایت');
      logDebug('✅ تصویر با موفقیت تولید شد: ${file.path}');
      logDebug('=== پایان تولید تصویر ===');

      return file;
    } catch (e, stackTrace) {
      logDebug('❌ خطا در تولید تصویر: $e');
      logDebug('Stack trace: $stackTrace');
      logDebug('=== پایان تولید تصویر با خطا ===');
      return null;
    }
  }

  Future<void> _waitForWidgetRender() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  /// اشتراک‌گذاری قالب به ویستا استوری
  Future<void> shareToSocialStory(File imageFile) async {
    try {
      final String filePath = imageFile.path;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Shared from Vista',
        subject: 'Vista Story Template',
      );
    } catch (e) {
      logDebug('Error sharing to Social: $e');
      throw Exception('Failed to share to Social');
    }
  }

  /// ذخیره تصویر در گالری
  Future<bool> saveToGallery(File imageFile) async {
    try {
      logDebug('=== شروع ذخیره تصویر ===');
      logDebug('مسیر فایل ورودی: ${imageFile.path}');
      logDebug('آیا فایل وجود دارد: ${await imageFile.exists()}');

      if (await imageFile.exists()) {
        final fileSize = await imageFile.length();
        logDebug('اندازه فایل: $fileSize بایت');
      }

      // درخواست مجوز (برای اندروید 13+)
      logDebug('درخواست مجوز photos...');
      PermissionStatus status = await Permission.photos.request();
      logDebug('وضعیت مجوز photos: $status');

      // اگر photos رد شد، photosAddOnly را امتحان کن
      if (status != PermissionStatus.granted) {
        logDebug('درخواست مجوز photosAddOnly...');
        status = await Permission.photosAddOnly.request();
        logDebug('وضعیت مجوز photosAddOnly: $status');
      }

      if (status != PermissionStatus.granted) {
        logDebug('❌ مجوز photos رد شد');
        return false;
      }

      // استفاده از gal برای ذخیره در گالری
      logDebug('شروع ذخیره با gal...');

      try {
        await Gal.putImage(imageFile.path);
        logDebug('✅ تصویر با موفقیت در گالری ذخیره شد');
        logDebug('=== پایان ذخیره تصویر ===');
        return true;
      } catch (e) {
        logDebug('❌ خطا در gal: $e');
        logDebug('تلاش با روش fallback...');
        return await _saveToGalleryFallback(imageFile);
      }
    } catch (e, stackTrace) {
      logDebug('❌ خطا در ذخیره تصویر: $e');
      logDebug('Stack trace: $stackTrace');
      logDebug('تلاش با روش fallback...');

      // fallback به روش قدیمی
      return await _saveToGalleryFallback(imageFile);
    }
  }

  /// روش fallback برای ذخیره در گالری
  Future<bool> _saveToGalleryFallback(File imageFile) async {
    try {
      logDebug('=== شروع fallback ذخیره ===');

      // کپی فایل به پوشه Pictures
      logDebug('دریافت مسیر external storage...');
      final Directory? picturesDir = await getExternalStorageDirectory();
      logDebug('مسیر external storage: ${picturesDir?.path}');

      if (picturesDir == null) {
        logDebug('❌ دسترسی به external storage ممکن نیست');
        return false;
      }

      final Directory picturesPath =
          Directory('${picturesDir.path}/Pictures/Vista');
      logDebug('مسیر مقصد: ${picturesPath.path}');

      if (!await picturesPath.exists()) {
        logDebug('ایجاد پوشه Pictures/Vista...');
        await picturesPath.create(recursive: true);
        logDebug('✅ پوشه ایجاد شد');
      } else {
        logDebug('✅ پوشه از قبل موجود است');
      }

      final String fileName =
          'Vista_Story_${DateTime.now().millisecondsSinceEpoch}.png';
      final File savedFile = File('${picturesPath.path}/$fileName');
      logDebug('نام فایل نهایی: $fileName');
      logDebug('مسیر کامل فایل: ${savedFile.path}');

      logDebug('شروع کپی فایل...');
      await imageFile.copy(savedFile.path);

      final savedFileSize = await savedFile.length();
      logDebug('اندازه فایل ذخیره شده: $savedFileSize بایت');
      logDebug('✅ تصویر با موفقیت ذخیره شد: ${savedFile.path}');
      logDebug('=== پایان fallback ذخیره ===');

      return true;
    } catch (e, stackTrace) {
      logDebug('❌ خطا در fallback ذخیره: $e');
      logDebug('Stack trace: $stackTrace');
      logDebug('=== پایان fallback ذخیره با خطا ===');
      return false;
    }
  }

  /// تولید تصویر بک‌گراند از ویجت Flutter
  Future<File?> _generateBackgroundFromWidget(
    GlobalKey repaintBoundaryKey, {
    String? customBackgroundText,
    Color? backgroundColor,
    Color? textColor,
  }) async {
    try {
      final BuildContext? context = repaintBoundaryKey.currentContext;
      if (context == null) {
        debugPrint(
            '❌ خطا: repaintBoundaryKey.currentContext is null for background');
        return null;
      }
      final RenderRepaintBoundary boundary =
          context.findRenderObject() as RenderRepaintBoundary;

      // تولید تصویر با کیفیت بالا
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        logDebug('❌ خطا در تبدیل تصویر به byte data');
        return null;
      }

      // ذخیره فایل
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'Vista_Background_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      logDebug('✅ تصویر بک‌گراند تولید شد: ${file.path}');
      return file;
    } catch (e) {
      logDebug('❌ خطا در تولید تصویر بک‌گراند: $e');
      return null;
    }
  }

  /// تولید تصویر کارت پست از ویجت Flutter
  Future<File?> _generatePostCardFromWidget(
    GlobalKey repaintBoundaryKey,
    PublicPostModel post, {
    String? customPostText,
    String? customImageUrl,
  }) async {
    try {
      final BuildContext? context = repaintBoundaryKey.currentContext;
      if (context == null) {
        debugPrint(
            '❌ خطا: repaintBoundaryKey.currentContext is null for post card');
        return null;
      }
      final RenderRepaintBoundary boundary =
          context.findRenderObject() as RenderRepaintBoundary;

      // تولید تصویر با کیفیت بالا
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        logDebug('❌ خطا در تبدیل تصویر کارت پست به byte data');
        return null;
      }

      // ذخیره فایل
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'Vista_PostCard_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      logDebug('✅ تصویر کارت پست تولید شد: ${file.path}');
      return file;
    } catch (e) {
      logDebug('❌ خطا در تولید تصویر کارت پست: $e');
      return null;
    }
  }
}
