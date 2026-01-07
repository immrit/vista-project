import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/story_enums.dart' hide StoryInteractionType;
import '../../domain/entities/story_editor_models.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/story_sticker_sheet.dart';
import '../widgets/sticker_factory.dart';
import '../widgets/glass_layer.dart';
import '../../../../provider/provider.dart';
import '../../../../model/UserModel.dart';
import '../../../../utils/premium_features_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ویرایشگر استوری
class StoryEditorScreen extends ConsumerStatefulWidget {
  final File mediaFile;
  final StoryMediaType mediaType;

  const StoryEditorScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<StoryElement> _elements = [];
  StoryElement? _selectedElement;

  // Drawing & Text State
  bool _isDrawing = false;
  bool _showTextInput = false;
  bool _isSaving = false;

  // Drawing Tools
  Color _drawingColor = Colors.white;
  final double _brushSize = 4.0;
  final List<DrawingPath> _drawingPaths = [];
  DrawingPath? _currentPath;

  // Text Settings
  Color _textColor = Colors.white;
  double _fontSize = 28;
  final String _fontFamily = 'Vazir';
  final TextAlign _textAlign = TextAlign.center;

  // Text Re-editing: Element currently being edited (null = new text)
  StoryElement? _editingElement;
  final TextEditingController _textController = TextEditingController();

  late ui.Image? _backgroundImage;
  bool _imageLoaded = false;
  double _dragStartY = 0;

  // Gesture State
  bool _isDragging = false;
  bool _isOverTrash = false;
  bool _showVerticalGuide = false;
  bool _showHorizontalGuide = false;

  // Story Duration
  StoryDuration _storyDuration = StoryDuration.hours24;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final data = await widget.mediaFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
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
    return PopScope(
        canPop: _elements.isEmpty && _drawingPaths.isEmpty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          // Show discard changes dialog
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'تغییرات ذخیره نشده',
                style: TextStyle(color: Colors.white, fontFamily: 'Vazir'),
              ),
              content: const Text(
                'آیا از انصراف مطمئن هستید؟ تغییرات شما از بین خواهد رفت.',
                style: TextStyle(color: Colors.grey, fontFamily: 'Vazir'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ادامه ویرایش'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (shouldDiscard == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
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
              if (!_isDrawing &&
                  (!_isDragging) &&
                  (details.primaryVelocity ?? 0) < -300) {
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
                      if (!_isDrawing) {
                        setState(() => _selectedElement = null);
                      }
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
                        ..._elements.map((element) => _buildElement(element)),
                      ],
                    ),
                  ),
                ),

                // Alignment Guides
                if (_isDragging) _buildAlignmentGuides(),

                // هدر
                if (!_isDragging)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    child: _buildHeader(),
                  ),

                // تولبار
                if (!_isDragging)
                  Positioned(
                    right: 16,
                    top: MediaQuery.of(context).padding.top + 60,
                    child: _buildToolbar(),
                  ),

                // دکمه تایید
                if (!_isDragging && !_showTextInput)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 16,
                    right: 16,
                    child: _buildBottomActions(),
                  ),

                // Trash Can Area
                if (_isDragging) _buildTrashCan(),

                // فلش راهنما برای استیکرها
                if (!_isDragging && !_showTextInput)
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
        ));
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
        const SizedBox(height: 12),

        // مدت زمان استوری
        _buildToolButton(
          icon: _storyDuration == StoryDuration.hours48
              ? Icons.timelapse
              : Icons.timer_outlined,
          isActive: _storyDuration == StoryDuration.hours48,
          customColor: _storyDuration == StoryDuration.hours48
              ? const Color(0xFFFFD700)
              : null,
          onTap: _toggleStoryDuration,
          label: _storyDuration == StoryDuration.hours48 ? '48h' : '24h',
          badge: _storyDuration == StoryDuration.hours48
              ? Icons.verified
              : null, // Gold tick if premium selected
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? customColor,
    String? label,
    IconData? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassLayer(
        borderRadius: BorderRadius.circular(30),
        blur: 10,
        opacity: isActive ? 0.4 : 0.2,
        baseColor: isActive ? Colors.blue : Colors.black,
        border: Border.all(
          color: isActive ? Colors.blueAccent : Colors.white24,
          width: 1,
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: customColor ?? Colors.white, size: 24),
                  if (label != null)
                    Text(
                      label,
                      style: TextStyle(
                        color: customColor ?? Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(badge, size: 12, color: customColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleStoryDuration() {
    final isCurrently48 = _storyDuration == StoryDuration.hours48;

    if (isCurrently48) {
      // Switch back to 24h
      setState(() => _storyDuration = StoryDuration.hours24);
    } else {
      // Check premium to switch to 48h
      final profileData = ref.read(profileProvider).value;
      if (profileData == null) return;

      final user = UserModel.fromMap(profileData);

      if (PremiumFeaturesHelper.canPostLongDurationStory(user)) {
        setState(() => _storyDuration = StoryDuration.hours48);
      } else {
        PremiumFeaturesHelper.showPremiumPromptDialog(
          context,
          feature: 'استوری ۴۸ ساعته',
        );
      }
    }
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

  void _undo() {
    setState(() {
      if (_drawingPaths.isNotEmpty) {
        _drawingPaths.removeLast();
      } else if (_elements.isNotEmpty) {
        _elements.removeLast();
      }
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

  Future<void> _saveStory() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _selectedElement = null;
    });

    try {
      // Small delay to ensure UI updates (selection cleared)
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

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(pngBytes);

      if (mounted) {
        // Return Map as expected by StoryCreationScreen
        Navigator.pop(context, {
          'media': tempFile,
          'caption': null,
          'elements': _elements,
          'duration': _storyDuration,
        });
      }
    } catch (e) {
      debugPrint('Story Save Error: $e');
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

  Widget _buildAlignmentGuides() {
    return Stack(
      children: [
        if (_showVerticalGuide)
          Center(
            child: Container(
              width: 1.5,
              height: double.infinity,
              color: Colors.blueAccent,
            ),
          ),
        if (_showHorizontalGuide)
          Center(
            child: Container(
              height: 1.5,
              width: double.infinity,
              color: Colors.blueAccent,
            ),
          ),
      ],
    );
  }

  Widget _buildTrashCan() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedScale(
          scale: _isOverTrash ? 1.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  _isOverTrash ? Colors.red.withOpacity(0.8) : Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _isOverTrash ? Colors.red : Colors.white24, width: 2),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElement(StoryElement element) {
    final isSelected = _selectedElement == element;

    // If over trash, shrink the element to indicate deletion
    final double displayScale =
        (_isOverTrash && isSelected) ? 0.0 : element.scale;
    final double opacity = (_isOverTrash && isSelected) ? 0.5 : 1.0;

    return Positioned(
      left: element.x,
      top: element.y,
      child: GestureDetector(
        onTap: () {
          setState(() {
            // Text Re-editing: If it's a plain text element, open for editing
            if (element.interactionType == StoryInteractionType.none) {
              // Open text input with this element's text
              _editingElement = element;
              _textController.text = element.text;
              _textColor = element.color;
              _fontSize = element.fontSize;
              _showTextInput = true;
            } else {
              // Interactive sticker: toggle style
              element.styleIndex++;
            }
            _selectedElement = element;
          });
        },
        onScaleStart: (details) {
          setState(() {
            _selectedElement = element;
            _isDragging = true;

            // Smart Layering: Bring touched element to front (end of list)
            if (_elements.contains(element)) {
              _elements.remove(element);
              _elements.add(element);
            }
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            final screenSize = MediaQuery.of(context).size;
            final centerX = screenSize.width / 2;
            final centerY = screenSize.height / 2;

            // 1. Move
            double newX = element.x + details.focalPointDelta.dx;
            double newY = element.y + details.focalPointDelta.dy;

            // 2. Magnetic Snapping Logic
            // Calculate element's visual center (approximate)
            // Note: element.x/y is top-left in Stack logic usually,
            // but we might need to adjust based on widget size.
            // Assuming x/y is roughly center or we snap the anchor.
            // Let's assume we snap based on the touch focal point or raw Coordinates

            // Vertical Snap (Center X)
            // We compare newX (left position) + width/2 approx
            // Simpler approach: check if newX is close to center-offset
            // Assuming element is centered at x,y? No, Positioned uses top/left.
            // Let's use simple threshold on the delta for now.

            // Adjust threshold for snapping
            const double snapThreshold = 10.0;
            // const double centerOffset = 0; // Removed as unused

            // Check distance to center X
            // We need to know element width to center it perfectly,
            // but as a heuristic we can snap 'near' the center.
            // Or better: Snap if the *gesture* passes through center

            if ((newX - (centerX - 50)).abs() < snapThreshold) {
              // 50 is approx half width
              newX = centerX - 50;
              if (!_showVerticalGuide) {
                ui.window.onSemanticsEnabledChanged; // Just a dummy access? No.
                // HapticFeedback.lightImpact(); // Needs 'package:flutter/services.dart'
              }
              _showVerticalGuide = true;
            } else {
              _showVerticalGuide = false;
            }

            // Horizontal Snap (Center Y)
            if ((newY - centerY).abs() < snapThreshold) {
              newY = centerY;
              _showHorizontalGuide = true;
            } else {
              _showHorizontalGuide = false;
            }

            // Boundary Constraints: Keep at least 20px visible on screen
            const double minVisible = 20.0;
            const double elementApproxSize = 100.0; // Approximate element size
            newX = newX.clamp(
              -elementApproxSize + minVisible,
              screenSize.width - minVisible,
            );
            newY = newY.clamp(
              -elementApproxSize + minVisible,
              screenSize.height - minVisible,
            );

            element.x = newX;
            element.y = newY;

            // 3. Rotation & Scale
            element.scale *= details.scale;
            element.scale = element.scale.clamp(0.3, 5.0);

            // Rotation Snapping (0, 90, 180, 270)
            double newRotation = element.rotation + details.rotation;

            // Normalize current rotation to nearest 90 deg step
            // element.rotation is in radians. 90 deg = pi/2 = 1.57 rad
            const double pi = 3.14159265;
            const double step = pi / 2;

            double gridRotation = (newRotation / step).round() * step;
            double diff = (newRotation - gridRotation).abs();

            // Threshold in radians (approx 5 degrees = 0.08 rad)
            if (diff < 0.1) {
              if ((element.rotation - gridRotation).abs() > 0.001) {
                // Only if we haven't already snapped to this value
                // HapticFeedback.selectionClick(); // Soft heavy click
              }
              newRotation = gridRotation;
            }

            element.rotation = newRotation;

            // 4. Trash Detection
            // Check distance to bottom center
            final trashY = screenSize.height - 80;
            final trashX = screenSize.width / 2;

            // Simple distance check from element (top-left) to trash
            // Better to use touch position (details.focalPoint)
            final dist = (details.focalPoint - Offset(trashX, trashY)).distance;

            if (dist < 100) {
              if (!_isOverTrash) {
                // HapticFeedback.mediumImpact();
              }
              _isOverTrash = true;
            } else {
              _isOverTrash = false;
            }
          });
        },
        onScaleEnd: (details) {
          if (_isOverTrash) {
            // Delete
            setState(() {
              _elements.remove(element);
              _selectedElement = null;
            });
            // HapticFeedback.heavyImpact();
          }

          setState(() {
            _isDragging = false;
            _isOverTrash = false;
            _showVerticalGuide = false;
            _showHorizontalGuide = false;
          });
        },
        child: Transform.rotate(
          angle: element.rotation,
          child: Transform.scale(
            scale: displayScale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: StickerFactory.buildSticker(element),
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
      if (_editingElement != null) {
        // Text Re-editing: Update existing element
        _editingElement!.text = text;
        _editingElement!.color = _textColor;
        _editingElement!.fontSize = _fontSize;
        _editingElement = null; // Clear editing state
      } else {
        // Add new text element
        _elements.add(StoryElement(
          text: text,
          x: screenSize.width / 2 - 50,
          y: screenSize.height / 2 - 20,
          color: _textColor,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          textAlign: _textAlign,
        ));
      }
      _textController.clear();
    });
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

  /// نمایش Bottom Sheet استیکرها
  void _showStickerSheet() {
    // Capture screen size BEFORE showing the modal to avoid context issues
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2 - 60;
    final centerY = screenSize.height / 2 - 30;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StoryStickerSheet(
        onStickerSelected: (content) {
          setState(() {
            _elements.add(StoryElement(
              text: content,
              x: centerX + 30, // Adjust for emoji centering
              y: centerY,
              rotation: 0,
              scale: 2.0, // سایز بزرگتر برای استیکر
              color: Colors.white,
              fontSize: 48.0, // سایز بزرگ برای استیکر
              fontFamily: 'Vazir',
            ));
          });
        },
        onInteractiveStickerSelected: (type, data) {
          if (!mounted) return;
          setState(() {
            _elements.add(StoryElement(
              text: '', // Text not relevant for interactive widgets
              x: centerX,
              y: centerY,
              rotation: 0,
              scale: 1.0,
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Vazir',
              interactionType: type,
              interactionData: data,
            ));
          });
        },
      ),
    );
  }
}
