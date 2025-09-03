import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../model/publicPostModel.dart';

class PostImageGenerator {
  static final PostImageGenerator _instance = PostImageGenerator._internal();
  factory PostImageGenerator() => _instance;
  PostImageGenerator._internal();

  /// تولید تصویر از پست برای اشتراک‌گذاری
  Future<File?> generatePostImage(
    PublicPostModel post,
    GlobalKey repaintBoundaryKey, {
    Size? customSize,
    bool includeBackground = true,
    bool includeLogo = true,
    bool isStoryFormat = false,
  }) async {
    try {
      // گرفتن RenderObject از کلید
      final RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // گرفتن تصویر با رزولوشن بالاتر برای کیفیت بهتر
      final double pixelRatio = isStoryFormat ? 2.0 : 3.0;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // تبدیل به ByteData
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      // تبدیل به Uint8List
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // ذخیره تصویر به فایل موقت
      final Directory tempDir = await getTemporaryDirectory();
      final String format = isStoryFormat ? 'story' : 'post';
      final String fileName =
          '${format}_${post.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      print('Error generating post image: $e');
      return null;
    }
  }

  /// تولید تصویر استوری با بک‌گراند سفارشی
  Future<File?> generateStoryImage(
    PublicPostModel post,
    GlobalKey repaintBoundaryKey,
  ) async {
    try {
      // گرفتن RenderObject از کلید
      final RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // گرفتن تصویر با رزولوشن مناسب برای استوری
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);

      // تبدیل به ByteData
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert story image to bytes');
      }

      // تبدیل به Uint8List
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // ذخیره تصویر به فایل موقت
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'story_${post.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      print('Error generating story image: $e');
      return null;
    }
  }

  /// اشتراک‌گذاری تصویر پست به اینستاگرام استوری
  Future<void> shareToInstagramStory(File imageFile) async {
    try {
      final String filePath = imageFile.path;

      // استفاده از share_plus برای اشتراک‌گذاری به اینستاگرام
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Shared from Vista',
        subject: 'Vista Post',
      );
    } catch (e) {
      print('Error sharing to Instagram: $e');
      throw Exception('Failed to share to Instagram');
    }
  }

  /// اشتراک‌گذاری تصویر پست به واتساپ
  Future<void> shareToWhatsApp(File imageFile, {String? text}) async {
    try {
      final String filePath = imageFile.path;

      // استفاده از share_plus برای اشتراک‌گذاری به واتساپ
      await Share.shareXFiles(
        [XFile(filePath)],
        text: text ?? 'Shared from Vista',
        subject: 'Vista Post',
      );
    } catch (e) {
      print('Error sharing to WhatsApp: $e');
      throw Exception('Failed to share to WhatsApp');
    }
  }

  /// اشتراک‌گذاری تصویر پست به پلاتفرم‌های دیگر
  Future<void> shareToOtherApps(File imageFile, {String? text}) async {
    try {
      final String filePath = imageFile.path;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: text ?? 'Shared from Vista',
        subject: 'Vista Post',
      );
    } catch (e) {
      print('Error sharing image: $e');
      throw Exception('Failed to share image');
    }
  }

  /// پاک کردن فایل‌های موقت
  Future<void> cleanupTempFiles() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> files = tempDir.listSync();

      for (final FileSystemEntity file in files) {
        if (file is File &&
            file.path.contains('post_') &&
            file.path.endsWith('.png')) {
          try {
            await file.delete();
          } catch (e) {
            print('Error deleting temp file: $e');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }

  /// تغییر اندازه تصویر برای اشتراک‌گذاری بهتر
  Future<File?> resizeImageForSharing(File imageFile,
      {int maxWidth = 1200, int maxHeight = 2000}) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        return null;
      }

      // محاسبه اندازه جدید با حفظ نسبت تصویر
      final double aspectRatio = originalImage.width / originalImage.height;
      int newWidth = maxWidth;
      int newHeight = (newWidth / aspectRatio).round();

      if (newHeight > maxHeight) {
        newHeight = maxHeight;
        newWidth = (newHeight * aspectRatio).round();
      }

      // تغییر اندازه تصویر با کیفیت بالاتر
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic, // کیفیت بالاتر
      );

      // ذخیره تصویر تغییر اندازه داده شده
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'resized_post_${DateTime.now().millisecondsSinceEpoch}.png';
      final File resizedFile = File('${tempDir.path}/$fileName');

      final Uint8List resizedBytes = img.encodePng(resizedImage);
      await resizedFile.writeAsBytes(resizedBytes);

      return resizedFile;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }
}
