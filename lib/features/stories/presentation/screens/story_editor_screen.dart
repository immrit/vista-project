import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/story_enums.dart';
import '../../domain/entities/story_editor_models.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/story_sticker_sheet.dart';

/// ویرایشگر استوری
class StoryEditorScreen extends StatefulWidget {
  final File mediaFile;
  final StoryMediaType mediaType;

  const StoryEditorScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<StoryElement> _elements = [];
  StoryElement? _selectedElement;

  bool _isDrawing = false;
  bool _showTextInput = false;
  bool _isSaving = false;

  // ابزار نقاشی
  Color _drawingColor = Colors.white;
  final double _brushSize = 4.0;
  final List<DrawingPath> _drawingPaths = [];
  DrawingPath? _currentPath;

  // تنظیمات متن
  Color _textColor = Colors.white;
  double _fontSize = 28;
  final String _fontFamily = 'Vazir';
  final TextAlign _textAlign = TextAlign.center;

  late ui.Image? _backgroundImage;
  bool _imageLoaded = false;
  double _dragStartY = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.mediaFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _backgroundImage = frame.image;
        _imageLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: (details) {
          _dragStartY = details.globalPosition.dy;
        },
        onVerticalDragEnd: (details) {
          final screenHeight = MediaQuery.of(context).size.height;
          // Ignore swipes starting from the very bottom edge (system gesture area)
          if (_dragStartY > screenHeight * 0.9) return;

          // اگر در حال نقاشی نیستیم و حرکت رو به بالا بود
          // Threshold increased to -300 to avoid accidental triggers
          if (!_isDrawing && (details.primaryVelocity ?? 0) < -300) {
            _showStickerSheet();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // کانواس
            RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                onPanStart: _isDrawing ? _onDrawStart : null,
                onPanUpdate: _isDrawing ? _onDrawUpdate : null,
                onPanEnd: _isDrawing ? _onDrawEnd : null,
                onTap: () {
                  setState(() => _selectedElement = null);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // تصویر پس‌زمینه
                    if (_imageLoaded && _backgroundImage != null)
                      RawImage(
                        image: _backgroundImage,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: Colors.black),

                    // لایه نقاشی
                    CustomPaint(
                      painter: DrawingPainter(
                        paths: _drawingPaths,
                        currentPath: _currentPath,
                      ),
                      size: Size.infinite,
                    ),

                    // المان‌های متنی
                    ..._elements.map((element) => _buildTextElement(element)),
                  ],
                ),
              ),
            ),

            // هدر
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: _buildHeader(),
            ),

            // تولبار
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 60,
              child: _buildToolbar(),
            ),

            // دکمه تایید
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 16,
              right: 16,
              child: _buildBottomActions(),
            ),

            // فلش راهنما برای استیکرها
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white.withOpacity(0.5),
                      size: 24,
                    ),
                    Text(
                      'استیکرها',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ورودی متن
            if (_showTextInput) _buildTextInputOverlay(),

            // لودینگ
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
        const Spacer(),
        // Undo
        if (_drawingPaths.isNotEmpty || _elements.isNotEmpty)
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      children: [
        // متن
        _buildToolButton(
          icon: Icons.text_fields,
          isActive: _showTextInput,
          onTap: () {
            setState(() {
              _isDrawing = false;
              _showTextInput = true;
            });
          },
        ),
        const SizedBox(height: 12),

        // استیکر
        _buildToolButton(
          icon: Icons.emoji_emotions,
          isActive: false,
          onTap: _showStickerSheet,
        ),
        const SizedBox(height: 12),

        // نقاشی
        _buildToolButton(
          icon: Icons.brush,
          isActive: _isDrawing,
          onTap: () {
            setState(() {
              _isDrawing = !_isDrawing;
              _showTextInput = false;
              _selectedElement = null;
            });
          },
        ),
        const SizedBox(height: 12),

        // رنگ
        if (_isDrawing)
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _drawingColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.3)
              : Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _saveStory,
          icon: const Icon(Icons.check),
          label: const Text('ادامه'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextElement(StoryElement element) {
    final isSelected = _selectedElement == element;

    return Positioned(
      left: element.x,
      top: element.y,
      child: GestureDetector(
        onTap: () => setState(() => _selectedElement = element),
        onDoubleTap: () {
          // حذف المان با دوبار تپ
          setState(() {
            _elements.remove(element);
            _selectedElement = null;
          });
        },
        onScaleStart: (details) {
          setState(() => _selectedElement = element);
        },
        onScaleUpdate: (details) {
          setState(() {
            // حرکت
            element.x += details.focalPointDelta.dx;
            element.y += details.focalPointDelta.dy;
            // تغییر سایز
            element.scale *= details.scale;
            element.scale = element.scale.clamp(0.3, 5.0);
            // چرخش
            element.rotation += details.rotation;
          });
        },
        child: Transform.rotate(
          angle: element.rotation,
          child: Transform.scale(
            scale: element.scale,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Text(
                element.text,
                style: element.fontFamily == 'Vazir'
                    ? TextStyle(
                        fontFamily: element.fontFamily,
                        fontSize: element.fontSize,
                        color: element.color,
                      )
                    : GoogleFonts.getFont(
                        element.fontFamily,
                        fontSize: element.fontSize,
                        color: element.color,
                      ),
                textAlign: element.textAlign,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputOverlay() {
    final TextEditingController controller = TextEditingController();

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            // هدر
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showTextInput = false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  // رنگ متن
                  GestureDetector(
                    onTap: () => _showTextColorPicker(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        _addTextElement(controller.text);
                        setState(() => _showTextInput = false);
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                  ),
                ],
              ),
            ),

            // ورودی متن
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    textAlign: _textAlign,
                    style: _fontFamily == 'Vazir'
                        ? TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: _fontSize,
                            color: _textColor,
                          )
                        : GoogleFonts.getFont(
                            _fontFamily,
                            fontSize: _fontSize,
                            color: _textColor,
                          ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'متن خود را بنویسید...',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    maxLines: null,
                  ),
                ),
              ),
            ),

            // تنظیمات
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // سایز فونت
                  IconButton(
                    onPressed: () => setState(
                        () => _fontSize = (_fontSize - 4).clamp(16, 60)),
                    icon: const Icon(Icons.text_decrease, color: Colors.white),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 16,
                    max: 60,
                    activeColor: Colors.white,
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _fontSize = (_fontSize + 4).clamp(16, 60)),
                    icon: const Icon(Icons.text_increase, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTextElement(String text) {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _elements.add(StoryElement(
        text: text,
        x: screenSize.width / 2 - 50,
        y: screenSize.height / 2 - 20,
        color: _textColor,
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        textAlign: _textAlign,
      ));
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب رنگ'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _drawingColor,
            onColorChanged: (color) {
              setState(() => _drawingColor = color);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _showTextColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب رنگ متن'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _textColor,
            onColorChanged: (color) {
              setState(() => _textColor = color);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _onDrawStart(DragStartDetails details) {
    setState(() {
      _currentPath = DrawingPath(
        color: _drawingColor,
        strokeWidth: _brushSize,
        points: [details.localPosition],
      );
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath?.points.add(details.localPosition);
    });
  }

  void _onDrawEnd(DragEndDetails details) {
    if (_currentPath != null) {
      setState(() {
        _drawingPaths.add(_currentPath!);
        _currentPath = null;
      });
    }
  }

  void _undo() {
    setState(() {
      if (_drawingPaths.isNotEmpty) {
        _drawingPaths.removeLast();
      } else if (_elements.isNotEmpty) {
        _elements.removeLast();
      }
    });
  }

  Future<void> _saveStory() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _selectedElement = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('خطا در تبدیل تصویر');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context, pngBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// نمایش Bottom Sheet استیکرها
  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StoryStickerSheet(
        onStickerSelected: (content) {
          setState(() {
            _elements.add(StoryElement(
              text: content,
              x: MediaQuery.of(context).size.width / 2 - 30,
              y: MediaQuery.of(context).size.height / 2 - 30,
              rotation: 0,
              scale: 2.0, // سایز بزرگتر برای استیکر
              color: Colors.white,
              fontSize: 48.0, // سایز بزرگ برای استیکر
              fontFamily: 'Vazir',
            ));
          });
          // Navigator.pop(context) is handled in StoryStickerSheet logic?
          // No, usually onStickerSelected calls pop inside the sheet or we do it here.
          // Based on my previous implementation of StoryStickerSheet, it does NOT pop automatically in all cases (like emojis),
          // only Interactive stickers popped. Wait, looking at StoryStickerSheet source:
          // Emoji onTap calls widget.onStickerSelected(...) then Navigator.pop(context).
          // Interactive onTap calls Navigator.pop(context) first.
          // So the sheet handles popping!
        },
      ),
    );
  }
}
