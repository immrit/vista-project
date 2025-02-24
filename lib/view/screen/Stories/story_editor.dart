import 'dart:io';
import 'dart:typed_data';
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

  static Uint8List? _processImage(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // چرخش 180 درجه و flip افقی
      var processedImage = img.copyRotate(image, angle: 180);
      processedImage =
          img.flip(processedImage, direction: img.FlipDirection.horizontal);

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

      // اعمال تغییرات برای نسبت تصویر
      if (processedImage.width / processedImage.height < 16 / 9) {
        const bgWidth = 1080;
        const bgHeight = 1920;

        final background = img.Image(
          width: bgWidth,
          height: bgHeight,
          format: img.Format.uint8,
        );

        final offsetX = (bgWidth - processedImage.width) ~/ 2;
        final offsetY = (bgHeight - processedImage.height) ~/ 2;

        img.compositeImage(
          background,
          processedImage,
          dstX: offsetX,
          dstY: offsetY,
          blend: img.BlendMode.alpha,
        );

        processedImage = background;
      }

      // حذف اطلاعات EXIF و تبدیل به JPEG
      processedImage.exif.clear();

      return Uint8List.fromList(
        img.encodeJpg(
          processedImage,
          quality: 85,
        ),
      );
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
