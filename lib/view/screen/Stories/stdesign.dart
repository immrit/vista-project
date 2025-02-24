import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // برای تبدیل فرمت تصویر
import 'package:pro_image_editor/pro_image_editor.dart';

class ImageEditorScreen extends StatefulWidget {
  final String imagePath;
  const ImageEditorScreen({required this.imagePath, super.key});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late File _imageFile;
  final GlobalKey<ProImageEditorState> _editorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
  }

  // متد برای تبدیل Uint8List به فرمت JPEG و حذف EXIF
  Future<Uint8List?> convertToJpeg(Uint8List imageBytes) async {
    try {
      // تبدیل Uint8List به تصویر
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('تصویر نامعتبر است');
      }

      double aspectRatio = image.width / image.height;
      // اگر نسبت تصویر کمتر از 16:9 باشد (مثلاً 1:1)
      if (aspectRatio < (16.0 / 9.0)) {
        // تعیین ابعاد پس‌زمینه (مثلاً رزولوشن استاندارد از یک صفحه کامل)
        const int bgWidth = 1080;
        const int bgHeight = 1920;

        // ایجاد پس زمینه با تغییر اندازه تصویر به ابعاد پس زمینه
        img.Image background =
            img.copyResize(image, width: bgWidth, height: bgHeight);
        // اعمال بلور (با شعاع دلخواه، مثال: 10)
        background = img.gaussianBlur(background, radius: 10);

        // قرار دادن تصویر اصلی با سایز واقعی در مرکز پس‌زمینه
        final int offsetX = (bgWidth - image.width) ~/ 2;
        final int offsetY = (bgHeight - image.height) ~/ 2;
        // ترکیب تصویر اصلی روی پس‌زمینه
// ترکیب تصویر اصلی روی پس‌زمینه با استفاده از copyInto
        img.copyInto(background, image, dstX: offsetX, dstY: offsetY);
        // حذف اطلاعات EXIF
        background.exif.clear();
        return Uint8List.fromList(img.encodeJpg(background));
      } else {
        // حذف EXIF و برگرداندن تصویر اصلی
        image.exif.clear();
        return Uint8List.fromList(img.encodeJpg(image));
      }
    } catch (e) {
      debugPrint('خطا در تبدیل تصویر: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProImageEditor.file(
        _imageFile,
        key: _editorKey,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            if (bytes.isNotEmpty && mounted) {
              try {
                // اعتبارسنجی و تبدیل تصویر به فرمت JPEG
                final jpegBytes = await convertToJpeg(bytes);
                if (jpegBytes != null) {
                  // بازگرداندن تصویر ویرایش‌شده به صفحه قبلی
                  Navigator.pop(context, jpegBytes);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فرمت تصویر نامعتبر است')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا: ${e.toString()}')),
                );
              }
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تصویر ویرایش‌شده یافت نشد')),
              );
            }
          },
        ),
      ),
    );
  }
}
