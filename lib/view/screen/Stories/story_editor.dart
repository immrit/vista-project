import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // برای تبدیل فرمت تصویر
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('Starting image conversion...');
      final result = await compute(_processImage, imageBytes);
      debugPrint('Image conversion completed');
      return result;
    } catch (e) {
      debugPrint('Error in image conversion: $e');
      return null;
    }
  }

  static Future<Uint8List?> _processImage(Uint8List imageBytes) async {
    try {
      // خواندن اطلاعات EXIF قبل از decode تصویر
      Map<String, IfdTag>? exifData;
      try {
        exifData = await readExifFromBytes(imageBytes);
      } catch (e) {
        debugPrint('Error reading EXIF data: $e');
        // ادامه پردازش حتی در صورت خطا در خواندن EXIF
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // اعمال جهت صحیح بر اساس EXIF
      var processedImage = image;

      if (exifData != null && exifData.containsKey('Image Orientation')) {
        final orientationTag = exifData['Image Orientation'];
        if (orientationTag != null) {
          int orientation = int.tryParse(orientationTag.printable) ?? 1;

          switch (orientation) {
            case 3: // چرخش 180 درجه
              processedImage = img.copyRotate(processedImage, angle: 180);
              break;
            case 6: // چرخش 90 درجه CW
              processedImage = img.copyRotate(processedImage, angle: 90);
              break;
            case 8: // چرخش 270 درجه CW (یا 90 درجه CCW)
              processedImage = img.copyRotate(processedImage, angle: 270);
              break;
            case 2: // flip افقی
              processedImage = img.flipHorizontal(processedImage);
              break;
            case 4: // flip عمودی
              processedImage = img.flipVertical(processedImage);
              break;
            case 5: // چرخش 90 درجه CW و flip افقی
              processedImage = img.copyRotate(processedImage, angle: 90);
              processedImage = img.flipHorizontal(processedImage);
              break;
            case 7: // چرخش 270 درجه CW و flip افقی
              processedImage = img.copyRotate(processedImage, angle: 270);
              processedImage = img.flipHorizontal(processedImage);
              break;
          }
        }
      }

      // تنظیم اندازه تصویر
      if (processedImage.width > 1080 || processedImage.height > 1920) {
        double ratio = processedImage.width / processedImage.height;
        int newWidth, newHeight;

        if (ratio > 1) {
          // تصویر افقی
          newWidth = 1080;
          newHeight = (1080 / ratio).round();
        } else {
          // تصویر عمودی
          newHeight = 1920;
          newWidth = (1920 * ratio).round();
        }

        processedImage = img.copyResize(
          processedImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // تبدیل به فرمت JPEG با کیفیت مناسب
      return Uint8List.fromList(img.encodeJpg(processedImage, quality: 85));
    } catch (e) {
      debugPrint('Error processing image: $e');
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
            if (bytes.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تصویر خالی است')),
                );
              }
              return;
            }

            try {
              final jpegBytes = await convertToJpeg(bytes);
              if (jpegBytes != null && jpegBytes.isNotEmpty) {
                if (mounted) {
                  Navigator.pop(context, jpegBytes);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('خطا در پردازش تصویر. لطفاً دوباره تلاش کنید'),
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا: ${e.toString()}')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
