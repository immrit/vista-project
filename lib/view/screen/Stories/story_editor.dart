import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:exif/exif.dart';

class StoryEditorScreen extends StatefulWidget {
  final File imageFile;

  const StoryEditorScreen({super.key, required this.imageFile});

  @override
  _StoryEditorScreenState createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  late final DrawingController _drawingController;
  late final TextEditingController _textController;
  String _text = '';
  Color _textColor = Colors.white;
  double _textSize = 24;
  final Offset _textPosition = Offset.zero;
  bool _isDrawingEnabled = false;
  Color _currentDrawingColor = Colors.white;
  double _currentStrokeWidth = 3.0;
  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];
  final List<Offset> _points = [];
  String? _selectedSticker;

  @override
  void initState() {
    super.initState();
    _drawingController = DrawingController(
      config: DrawConfig(
          color: _currentDrawingColor,
          strokeWidth: _currentStrokeWidth,
          contentType: ui.Image // اضافه کردن این خط
          ),
    );
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _drawingController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _showDrawingOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ضخامت قلم',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _currentStrokeWidth,
              min: 1,
              max: 10,
              onChanged: (value) {
                setState(() {
                  _currentStrokeWidth = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'رنگ قلم',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentDrawingColor = color;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == _currentDrawingColor
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<ui.Image> _loadAndCorrectImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      // Try both potential keys
      final tags = await readExifFromBytes(bytes);
      int? orientation;
      if (tags.containsKey('Image Orientation')) {
        orientation =
            (tags['Image Orientation']?.values.toList().first) as int?;
      } else if (tags.containsKey('Orientation')) {
        orientation = (tags['Orientation']?.values.toList().first) as int?;
      }
      debugPrint('EXIF Orientation: $orientation');

      // Decode the image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      // Apply rotation/flip based on orientation
      if (orientation != null) {
        switch (orientation) {
          case 2: // Flip horizontal
            image = img.flipHorizontal(image);
            break;
          case 3: // Rotate 180°
            image = img.copyRotate(image, angle: 180);
            break;
          case 4: // Flip vertical
            image = img.flipVertical(image);
            break;
          case 5: // Rotate 90° clockwise and flip horizontal
            image = img.copyRotate(image, angle: 90);
            image = img.flipHorizontal(image);
            break;
          case 6: // Rotate 90° clockwise (adjust to -90 if needed)
            image = img.copyRotate(image, angle: 90);
            break;
          case 7: // Rotate 90° clockwise and flip vertical
            image = img.copyRotate(image, angle: 90);
            image = img.flipVertical(image);
            break;
          case 8: // Rotate 270° clockwise (or try -90)
            image = img.copyRotate(image, angle: 270);
            break;
          default:
            break;
        }
      }

      // Resize while keeping aspect ratio
      const maxWidth = 1080;
      const maxHeight = 1920;
      double ratio = image.width / image.height;
      int newWidth, newHeight;
      if (ratio > maxWidth / maxHeight) {
        newWidth = maxWidth;
        newHeight = (maxWidth / ratio).round();
      } else {
        newHeight = maxHeight;
        newWidth = (maxHeight * ratio).round();
      }

      if (image.width != newWidth || image.height != newHeight) {
        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Convert to PNG and create ui.Image
      final correctedBytes = img.encodePng(image);
      final codec = await ui.instantiateImageCodec(
        correctedBytes,
        targetWidth: newWidth,
        targetHeight: newHeight,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error in _loadAndCorrectImage: $e');
      // Fallback to direct loading if correction fails
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      return frame.image;
    }
  }

  void _showTextEditorDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'متن خود را وارد کنید',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _textSize,
                      min: 12,
                      max: 48,
                      onChanged: (value) {
                        setState(() => _textSize = value);
                      },
                    ),
                  ),
                  Text('${_textSize.round()}'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _textColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == _textColor
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _text = _textController.text);
                  Navigator.pop(context);
                },
                child: const Text('اضافه کردن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Size _calculateTargetSize(ui.Image image) {
    const maxWidth = 1080.0;
    const maxHeight = 1920.0;

    final sourceRatio = image.width / image.height;
    final targetRatio = maxWidth / maxHeight;

    late final double width;
    late final double height;

    if (sourceRatio > targetRatio) {
      // Image is wider than target ratio
      width = maxWidth;
      height = maxWidth / sourceRatio;
    } else {
      // Image is taller than target ratio
      height = maxHeight;
      width = maxHeight * sourceRatio;
    }

    return Size(width, height);
  }

  Future<File> _getEditedImage() async {
    ui.Image? originalImage;
    ui.Image? renderedImage;

    try {
      // بارگذاری و اصلاح تصویر (چرخش، تغییر اندازه و …)
      originalImage = await _loadAndCorrectImage(widget.imageFile);
      final targetSize = _calculateTargetSize(originalImage);

      // Create recorder with proper dimensions
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw background (optional)
      canvas.drawColor(Colors.black, BlendMode.src);

      // رسم تصویر با ابعاد نهایی
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
            originalImage.height.toDouble()),
        Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        Paint(),
      );

      // محاسبه سایز پیش‌نمایش دقیق (با در نظر گرفتن AppBar و statusBar)
      final screenSize = MediaQuery.of(context).size;
      final appBarHeight = AppBar().preferredSize.height;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final previewHeight = screenSize.height - appBarHeight - statusBarHeight;
      final previewSize = Size(screenSize.width, previewHeight);

      // نسبت مقیاس: نسبت ابعاد تصویر نهایی به پیش‌نمایش
      final scaleX = targetSize.width / previewSize.width;
      final scaleY = targetSize.height / previewSize.height;

      // رسم متن با مقیاس صحیح
      if (_text.isNotEmpty) {
        final scaledPosition = Offset(
          _textPosition.dx * scaleX,
          _textPosition.dy * scaleY,
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: _text,
            style: TextStyle(
              color: _textColor,
              fontSize: _textSize * scaleX, // افزایش اندازه به نسبت x
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        );
        textPainter.layout();
        textPainter.paint(canvas, scaledPosition);
      }

      // رسم خطوط (دست‌نوشته) با مقیاس صحیح
      if (_points.isNotEmpty) {
        final drawPaint = Paint()
          ..color = _currentDrawingColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _currentStrokeWidth * scaleX
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < _points.length - 1; i++) {
          final start = Offset(_points[i].dx * scaleX, _points[i].dy * scaleY);
          final end =
              Offset(_points[i + 1].dx * scaleX, _points[i + 1].dy * scaleY);
          canvas.drawLine(start, end, drawPaint);
        }
      }

      // رسم استیکر (در صورت انتخاب)
      if (_selectedSticker != null) {
        final stickerBytes = await File(_selectedSticker!).readAsBytes();
        final stickerCodec = await ui.instantiateImageCodec(stickerBytes);
        final stickerFrame = await stickerCodec.getNextFrame();
        final stickerImage = stickerFrame.image;

        final stickerSize = Size(100 * scaleX, 100 * scaleY);
        // برای مثال، موقعیت استیکر می‌تواند به صورت ثابت باشد یا توسط کاربر تنظیم شده باشد
        final stickerPosition = Offset(50 * scaleX, 50 * scaleY);

        canvas.drawImageRect(
          stickerImage,
          Rect.fromLTWH(0, 0, stickerImage.width.toDouble(),
              stickerImage.height.toDouble()),
          Rect.fromLTWH(
            stickerPosition.dx,
            stickerPosition.dy,
            stickerSize.width,
            stickerSize.height,
          ),
          Paint(),
        );
      }

      // دریافت تصویر نهایی
      final picture = recorder.endRecording();
      renderedImage = await picture.toImage(
        targetSize.width.round(),
        targetSize.height.round(),
      );

      // فشرده‌سازی و ذخیره فایل
      final compressedData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (compressedData == null) throw Exception('Failed to compress image');

      final bytes = compressedData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/edited_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      return tempFile;
    } catch (e) {
      debugPrint('Error in _getEditedImage: $e');
      return widget.imageFile;
    } finally {
      // آزادسازی منابع
      originalImage?.dispose();
      renderedImage?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadAndCorrectImage(widget.imageFile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final correctedImage = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ویرایش استوری'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  final editedImage = await _getEditedImage();
                  Navigator.pop(context, editedImage);
                },
              ),
            ],
          ),
          body: GestureDetector(
            onPanUpdate: _isDrawingEnabled ? _handlePanUpdate : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: ImagePainter(correctedImage),
                    size: Size(correctedImage.width.toDouble(),
                        correctedImage.height.toDouble()),
                  ),
                ),
                CustomPaint(
                  painter: DrawingPainter(
                      _points, _currentDrawingColor, _currentStrokeWidth),
                  child: Container(),
                ),
                if (_text.isNotEmpty)
                  Positioned(
                    left: _textPosition.dx,
                    top: _textPosition.dy,
                    child: Text(
                      _text,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: _textSize,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.black.withOpacity(0.8),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildToolButton(
                      icon: Icons.text_fields,
                      label: 'متن',
                      onPressed: _showTextEditorDialog,
                    ),
                    _buildToolButton(
                      icon: Icons.brush,
                      label: 'نقاشی',
                      isActive: _isDrawingEnabled,
                      onPressed: () {
                        setState(() {
                          _isDrawingEnabled = !_isDrawingEnabled;
                        });
                        if (_isDrawingEnabled) {
                          _showDrawingOptions();
                        }
                      },
                    ),
                    _buildToolButton(
                      icon: Icons.emoji_emotions,
                      label: 'استیکر',
                      onPressed: _showStickerPicker,
                    ),
                    _buildToolButton(
                      icon: Icons.filter,
                      label: 'فیلتر',
                      onPressed: _applyFilter,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _points.add(details.localPosition);
    });
  }

  void _applyFilter() {
    // Placeholder for applying filter logic
    setState(() {
      // Filter application logic goes here
    });
  }

  void _showStickerPicker() {
    // Placeholder for sticker picker logic
    // For now, simply show a dialog indicating that it's not implemented yet
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sticker Picker'),
          content: const Text('Sticker picker is not implemented yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          color: isActive ? Colors.blue : Colors.white,
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingPainter(this.points, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
