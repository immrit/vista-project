import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/story_enums.dart' hide StoryInteractionType;
import '../../domain/entities/story_editor_models.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/story_sticker_sheet.dart';
import '../widgets/sticker_factory.dart';
import '../widgets/glass_layer.dart';
import '../widgets/editable_story_item.dart';
import '../../../../provider/provider.dart';
import '../../../../model/UserModel.dart';
import '../../../../utils/premium_features_helper.dart';
import '../../../../utils/user_friendly_error_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ویرایشگر استوری - نسخه بازنویسی شده بدون باگ هلیکوپتری
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
  static const double _minTextFontSize = 16;
  static const double _maxTextFontSize = 96;

  final GlobalKey _canvasKey = GlobalKey();

  // آیتم‌های جدید (استفاده از مدل بهبود یافته)
  final List<StoryItem> _items = [];
  String? _selectedItemId;

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
  int _textStyleIndex = 0;
  TextAnimationType _textAnimationType = TextAnimationType.none;

  // Text Re-editing
  String? _editingItemId;
  final TextEditingController _textController = TextEditingController();

  late ui.Image? _backgroundImage;
  bool _imageLoaded = false;
  double _dragStartY = 0;

  // Gesture State
  bool _isDragging = false;
  bool _isOverTrash = false;
  bool _showVerticalGuide = false;
  bool _showHorizontalGuide = false;
  bool _wasVerticallyAligned = false;
  bool _wasHorizontallyAligned = false;

  // Story Duration
  StoryDuration _storyDuration = StoryDuration.hours24;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  void _selectItem(String? itemId) {
    setState(() {
      _selectedItemId = itemId;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedItemId = null;
    });
  }

  void _updateItem(StoryItem updatedItem) {
    setState(() {
      final index = _items.lastIndexWhere((item) => item.id == updatedItem.id);
      if (index == -1) return;

      StoryItem effectiveItem = updatedItem;

      // Snap gently to canvas center for better precision (Social-like feel).
      final canvasSize = _resolveCanvasSize();
      final centerX = canvasSize.width / 2;
      final centerY = canvasSize.height / 2;
      const snapThreshold = 12.0;

      var isNearVerticalCenter = false;
      var isNearHorizontalCenter = false;
      if (_isDragging) {
        isNearVerticalCenter =
            (effectiveItem.x - centerX).abs() < snapThreshold;
        isNearHorizontalCenter =
            (effectiveItem.y - centerY).abs() < snapThreshold;

        if (isNearVerticalCenter && !_wasVerticallyAligned) {
          HapticFeedback.selectionClick();
        }
        if (isNearHorizontalCenter && !_wasHorizontallyAligned) {
          HapticFeedback.selectionClick();
        }

        _wasVerticallyAligned = isNearVerticalCenter;
        _wasHorizontallyAligned = isNearHorizontalCenter;

        _showVerticalGuide = isNearVerticalCenter;
        _showHorizontalGuide = isNearHorizontalCenter;

        if (isNearVerticalCenter || isNearHorizontalCenter) {
          effectiveItem = effectiveItem.copyWith(
            x: isNearVerticalCenter ? centerX : effectiveItem.x,
            y: isNearHorizontalCenter ? centerY : effectiveItem.y,
          );
        }
      } else {
        _wasVerticallyAligned = false;
        _wasHorizontallyAligned = false;
        _showVerticalGuide = false;
        _showHorizontalGuide = false;
      }
      _items[index] = effectiveItem;
      _dedupeItemsById();

      // Check for trash proximity
      final trashY = canvasSize.height - 80;
      final trashX = canvasSize.width / 2;

      final dist =
          (Offset(effectiveItem.x, effectiveItem.y) - Offset(trashX, trashY))
              .distance;

      final wasOverTrash = _isOverTrash;
      _isOverTrash = dist < 120;

      if (_isOverTrash && !wasOverTrash) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _dedupeItemsById() {
    final seenIds = <String>{};
    for (int i = _items.length - 1; i >= 0; i--) {
      final id = _items[i].id;
      if (seenIds.contains(id)) {
        _items.removeAt(i);
        continue;
      }
      seenIds.add(id);
    }
  }

  void _bringItemToFront(String itemId) {
    final index = _items.lastIndexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final currentItem = _items.removeAt(index);
    _items.add(currentItem);
    _dedupeItemsById();
  }

  void _deleteItem(String itemId) {
    setState(() {
      _items.removeWhere((item) => item.id == itemId);
      if (_selectedItemId == itemId) {
        _selectedItemId = null;
      }
    });
    HapticFeedback.heavyImpact();
  }

  void _addTextItem(String text) {
    if (text.trim().isEmpty) return;

    final screenSize = MediaQuery.of(context).size;

    final newItem = TextStoryItem(
      x: screenSize.width / 2,
      y: screenSize.height / 2,
      text: text,
      color: _textColor,
      fontSize: _fontSize,
      fontFamily: _fontFamily,
      textAlign: _textAlign,
      styleIndex: _textStyleIndex,
      animationType: _textAnimationType,
    );

    setState(() {
      _items.add(newItem);
      _selectedItemId = newItem.id;
      _showTextInput = false;
    });
  }

  void _updateTextItem(String itemId, String newText) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final item = _items[index];
    if (item is TextStoryItem) {
      setState(() {
        _items[index] = item.copyWith(
          text: newText,
          color: _textColor,
          fontSize: _fontSize,
          styleIndex: _textStyleIndex,
          animationType: _textAnimationType,
        );
        _showTextInput = false;
        _editingItemId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOpenStickerSheetWithSwipe = !_isDrawing &&
        !_isDragging &&
        !_showTextInput &&
        _selectedItemId == null &&
        _items.isEmpty;

    return PopScope(
      canPop: _items.isEmpty && _drawingPaths.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          onVerticalDragStart: canOpenStickerSheetWithSwipe
              ? (details) {
                  _dragStartY = details.globalPosition.dy;
                }
              : null,
          onVerticalDragEnd: canOpenStickerSheetWithSwipe
              ? (details) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final startedFromBottomZone =
                      _dragStartY > screenHeight * 0.55;
                  if (!startedFromBottomZone) return;
                  if ((details.primaryVelocity ?? 0) < -450) {
                    _showStickerSheet();
                  }
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. کانواس اصلی
              RepaintBoundary(
                key: _canvasKey,
                child: GestureDetector(
                  onPanStart: _isDrawing ? _onDrawStart : null,
                  onPanUpdate: _isDrawing ? _onDrawUpdate : null,
                  onPanEnd: _isDrawing ? _onDrawEnd : null,
                  onTap: _deselectAll,
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

                      // 2. آیتم‌ها با ویجت جدید
                      ..._items.map((item) => Positioned(
                            key: ValueKey('story_item_${item.id}'),
                            left: 0,
                            top: 0,
                            child: _buildEditableItem(item),
                          )),
                    ],
                  ),
                ),
              ),

              // 3. خطوط راهنما
              if (_isDragging)
                AlignmentGuides(
                  showVertical: _showVerticalGuide,
                  showHorizontal: _showHorizontalGuide,
                ),

              // 4. هدر (فقط وقتی درگ نیست)
              if (!_isDragging)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  child: _buildHeader(),
                ),

              // 5. تولبار
              if (!_isDragging)
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 60,
                  child: _buildToolbar(),
                ),

              // 6. دکمه تایید
              if (!_isDragging && !_showTextInput)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 16,
                  right: 16,
                  child: _buildBottomActions(),
                ),

              // 7. سطل زباله
              if (_isDragging)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: StoryTrashBin(
                      isActive: _isDragging,
                      isHovering: _isOverTrash,
                    ),
                  ),
                ),

              // 8. راهنمای استیکر
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
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 24,
                        ),
                        Text(
                          'استیکرها',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 9. ورودی متن
              if (_showTextInput) _buildTextInputOverlay(),

              // 10. لودینگ
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
      ),
    );
  }

  /// Cycles the `style` field in a StickerStoryItem's interactionData.
  void _cycleStickerStyle(StickerStoryItem item) {
    final data = Map<String, dynamic>.from(item.interactionData ?? {});
    final current = (data['style'] as num?)?.toInt() ?? 0;
    data['style'] = current + 1; // Each widget wraps via % numStyles
    final updated = item.copyWith(interactionData: data);
    setState(() {
      final idx = _items.lastIndexWhere((e) => e.id == item.id);
      if (idx != -1) _items[idx] = updated;
    });
    HapticFeedback.selectionClick();
  }

  /// ساخت آیتم قابل ویرایش با gesture engine جدید
  Widget _buildEditableItem(StoryItem item) {
    final isSelected = item.id == _selectedItemId;

    return EditableStoryItem(
      item: item,
      isSelected: isSelected,
      isDraggingOverTrash: _isOverTrash && isSelected,
      onUpdate: _updateItem,
      onSelect: () {
        // Tap on already-selected sticker → cycle its style.
        if (item.id == _selectedItemId && item is StickerStoryItem) {
          _cycleStickerStyle(item);
        } else {
          _selectItem(item.id);
        }
      },
      onDragStart: () {
        setState(() {
          _isDragging = true;
          _wasVerticallyAligned = false;
          _wasHorizontallyAligned = false;
          _bringItemToFront(item.id);
        });
      },
      onDragEnd: () {
        if (_isOverTrash) {
          _deleteItem(item.id);
        }
        setState(() {
          _isDragging = false;
          _isOverTrash = false;
          _showVerticalGuide = false;
          _showHorizontalGuide = false;
          _wasVerticallyAligned = false;
          _wasHorizontallyAligned = false;
        });
      },
      onDoubleTap: () {
        // ویرایش مجدد متن
        if (item is TextStoryItem) {
          setState(() {
            _editingItemId = item.id;
            _textController.text = item.text;
            _textColor = item.color;
            _fontSize = item.fontSize;
            _textStyleIndex = item.styleIndex;
            _textAnimationType = item.animationType;
            _showTextInput = true;
          });
        }
      },
      child: _buildItemContent(item),
    );
  }

  /// ساخت محتوای آیتم
  Widget _buildItemContent(StoryItem item) {
    if (item is TextStoryItem) {
      return _buildTextContent(item);
    } else if (item is StickerStoryItem) {
      return _buildStickerContent(item);
    } else if (item is ImageStoryItem) {
      return _buildImageContent(item);
    }
    return const SizedBox();
  }

  Widget _buildTextContent(TextStoryItem item) {
    // 0: Standard (Shadow)
    // 1: Filled Black
    // 2: Filled White
    // 3: Outlined
    // 4: Neon (New)
    // 5: Gradient (New)

    final isNeon = item.styleIndex % 6 == 4;
    final isGradient = item.styleIndex % 6 == 5;

    TextStyle baseStyle = TextStyle(
      fontSize: item.fontSize,
      fontFamily: item.fontFamily,
      fontWeight: FontWeight.bold,
      color: item.color,
    );

    if (item.styleIndex % 6 == 0) {
      // Standard with shadow
      return Text(
        item.text,
        textAlign: item.textAlign,
        style: baseStyle.copyWith(
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      );
    } else if (item.styleIndex % 6 == 1) {
      // Filled Black
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          item.text,
          textAlign: item.textAlign,
          style: baseStyle.copyWith(color: Colors.white),
        ),
      );
    } else if (item.styleIndex % 6 == 2) {
      // Filled White
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          item.text,
          textAlign: item.textAlign,
          style: baseStyle.copyWith(color: Colors.black),
        ),
      );
    } else if (item.styleIndex % 6 == 3) {
      // Outlined
      return Stack(
        children: [
          Text(
            item.text,
            textAlign: item.textAlign,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.black,
            ),
          ),
          Text(
            item.text,
            textAlign: item.textAlign,
            style: baseStyle,
          ),
        ],
      );
    } else if (isNeon) {
      // Neon Style
      return Text(
        item.text,
        textAlign: item.textAlign,
        style: baseStyle.copyWith(
          shadows: [
            Shadow(
                color: item.color, blurRadius: 15, offset: const Offset(0, 0)),
            Shadow(
                color: item.color, blurRadius: 30, offset: const Offset(0, 0)),
            Shadow(
                color: item.color, blurRadius: 5, offset: const Offset(0, 0)),
            const Shadow(
                color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
          ],
          color:
              Colors.white, // Text itself is white, glow is the selected color
        ),
      );
    } else if (isGradient) {
      // Gradient Background
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              item.color.withValues(alpha: 0.8),
              item.color.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Text(
          item.text,
          textAlign: item.textAlign,
          style: baseStyle.copyWith(color: Colors.white, shadows: const [
            Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
          ]),
        ),
      );
    }

    return Text(item.text, style: baseStyle, textAlign: item.textAlign);
  }

  Widget _buildStickerContent(StickerStoryItem item) {
    final styleRaw = item.interactionData?['style'];
    final style = styleRaw is num
        ? styleRaw.toInt()
        : int.tryParse(styleRaw?.toString() ?? '') ?? 0;

    // تبدیل موقت به StoryElement برای سازگاری با StickerFactory
    final legacyElement = StoryElement(
      elementId: item.id,
      text: '',
      x: item.x,
      y: item.y,
      rotation: item.rotation,
      scale: item.scale,
      color: Colors.white,
      fontSize: 20,
      interactionType: item.interactionType,
      interactionData: item.interactionData,
      styleIndex: style,
      width: item.width,
      height: item.height,
    );

    return StickerFactory.buildSticker(legacyElement);
  }

  Widget _buildImageContent(ImageStoryItem item) {
    return Image.file(
      File(item.imagePath),
      width: item.width,
      height: item.height,
      fit: BoxFit.cover,
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
        if (_drawingPaths.isNotEmpty || _items.isNotEmpty)
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    final selectedTextItem = _selectedTextItem;
    return Column(
      children: [
        _buildToolButton(
          icon: Icons.text_fields,
          isActive: _showTextInput,
          onTap: () {
            setState(() {
              _isDrawing = false;
              _editingItemId = null;
              _textController.clear();
              _showTextInput = true;
            });
          },
        ),
        const SizedBox(height: 12),
        if (!_showTextInput && selectedTextItem != null) ...[
          _buildToolButton(
            icon: Icons.text_decrease,
            isActive: false,
            onTap: () => _changeSelectedTextSize(-4),
          ),
          const SizedBox(height: 12),
          _buildToolButton(
            icon: Icons.text_increase,
            isActive: false,
            onTap: () => _changeSelectedTextSize(4),
          ),
          const SizedBox(height: 12),
        ],
        _buildToolButton(
          icon: Icons.emoji_emotions,
          isActive: false,
          onTap: _showStickerSheet,
        ),
        const SizedBox(height: 12),
        _buildToolButton(
          icon: Icons.brush,
          isActive: _isDrawing,
          onTap: () {
            setState(() {
              _isDrawing = !_isDrawing;
              _showTextInput = false;
              _selectedItemId = null;
            });
          },
        ),
        const SizedBox(height: 12),
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
          badge:
              _storyDuration == StoryDuration.hours48 ? Icons.verified : null,
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
      setState(() => _storyDuration = StoryDuration.hours24);
    } else {
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close Friends Button
        Expanded(
          child: GestureDetector(
            onTap: () => _saveStory(privacy: StoryPrivacyType.closeFriends),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'دوستان نزدیک',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Vazir',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Your Story Button
        Expanded(
          child: GestureDetector(
            onTap: () => _saveStory(privacy: StoryPrivacyType.everyone),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'استوری شما',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
                ],
              ),
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
      } else if (_items.isNotEmpty) {
        _items.removeLast();
      }
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('انتخاب رنگ', style: TextStyle(color: Colors.white)),
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

  Future<void> _saveStory(
      {StoryPrivacyType privacy = StoryPrivacyType.everyone}) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _selectedItemId = null;
    });

    // نمایش loading overlay
    _showLoadingOverlay();

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

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(pngBytes);

      final caption =
          _items.whereType<TextStoryItem>().map((e) => e.text).join('\n');
      final canvasSize = _resolveCanvasSize();
      final elements = _serializeStoryItems(canvasSize);

      // Return result to StoryCreationScreen
      if (mounted) {
        // Hide loading before popping
        _hideLoadingOverlay();
        Navigator.pop(context, {
          'media': tempFile,
          'caption': caption.isEmpty ? null : caption,
          'duration': _storyDuration,
          'privacy': privacy,
          'elements': elements,
        });
      }
    } catch (e) {
      _hideLoadingOverlay();
      debugPrint('Story Save Error: $e');
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Size _resolveCanvasSize() {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.of(context).size;
  }

  double? _normalizedCoordinate(double value, double maxValue) {
    if (!maxValue.isFinite || maxValue <= 0) return null;
    final normalized = value / maxValue;
    if (!normalized.isFinite) return null;
    return normalized.clamp(0.0, 1.0);
  }

  int _safeStyle(dynamic rawStyle) {
    if (rawStyle is int) return rawStyle;
    if (rawStyle is num) return rawStyle.toInt();
    return int.tryParse(rawStyle?.toString() ?? '') ?? 0;
  }

  double _safeDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<StoryElement> _serializeStoryItems(Size canvasSize) {
    return _items.map((item) {
      final xNorm = _normalizedCoordinate(item.x, canvasSize.width);
      final yNorm = _normalizedCoordinate(item.y, canvasSize.height);

      if (item is TextStoryItem) {
        return StoryElement(
          elementId: item.id,
          text: item.text,
          x: item.x,
          y: item.y,
          xNorm: xNorm,
          yNorm: yNorm,
          color: item.color,
          fontSize: item.fontSize,
          scale: item.scale,
          rotation: item.rotation,
          fontFamily: item.fontFamily,
          textAlign: item.textAlign,
          styleIndex: item.styleIndex,
          interactionType: StoryInteractionType.none,
        );
      }

      if (item is StickerStoryItem) {
        final data = Map<String, dynamic>.from(item.interactionData ?? {});
        final style = _safeStyle(data['style']);
        data['style'] = style;

        return StoryElement(
          elementId: item.id,
          text: '',
          x: item.x,
          y: item.y,
          xNorm: xNorm,
          yNorm: yNorm,
          rotation: item.rotation,
          scale: item.scale,
          color: Colors.white,
          fontSize: 20,
          interactionType: item.interactionType,
          interactionData: data,
          styleIndex: style,
          width: item.width,
          height: item.height,
        );
      }

      if (item is ImageStoryItem) {
        return StoryElement(
          elementId: item.id,
          text: '',
          x: item.x,
          y: item.y,
          xNorm: xNorm,
          yNorm: yNorm,
          rotation: item.rotation,
          scale: item.scale,
          color: Colors.white,
          fontSize: 16,
          interactionType: StoryInteractionType.photo,
          interactionData: {
            'imagePath': item.imagePath,
            'style': 0,
          },
          styleIndex: 0,
          width: item.width,
          height: item.height,
        );
      }

      return StoryElement(
        elementId: item.id,
        text: '',
        x: item.x,
        y: item.y,
        xNorm: xNorm,
        yNorm: yNorm,
        color: Colors.white,
        fontSize: 16,
      );
    }).toList();
  }

  OverlayEntry? _loadingOverlay;

  void _showLoadingOverlay() {
    _loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'در حال ارسال...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  TextStoryItem? get _selectedTextItem {
    if (_selectedItemId == null) return null;
    for (final item in _items) {
      if (item.id == _selectedItemId && item is TextStoryItem) {
        return item;
      }
    }
    return null;
  }

  void _changeSelectedTextSize(double delta) {
    final selected = _selectedTextItem;
    if (selected == null) return;

    final updatedFontSize =
        (selected.fontSize + delta).clamp(_minTextFontSize, _maxTextFontSize);

    _updateItem(
      selected.copyWith(fontSize: updatedFontSize.toDouble()),
    );
  }

  Widget _buildTextInputOverlay() {
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
                    onPressed: () {
                      setState(() {
                        _showTextInput = false;
                        _editingItemId = null;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  // تغییر استایل
                  GestureDetector(
                    onTap: () {
                      setState(
                          () => _textStyleIndex = (_textStyleIndex + 1) % 6);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'استایل',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // انیمیشن
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final currentIndex = TextAnimationType.values
                            .indexOf(_textAnimationType);
                        final nextIndex = (currentIndex + 1) %
                            TextAnimationType.values.length;
                        _textAnimationType =
                            TextAnimationType.values[nextIndex];
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _textAnimationType == TextAnimationType.none
                            ? Colors.transparent
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.animation,
                        size: 16,
                        color: _textAnimationType == TextAnimationType.none
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // تغییر رنگ
                  GestureDetector(
                    onTap: _showTextColorPicker,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // تایید
                  IconButton(
                    onPressed: () {
                      final text = _textController.text;
                      if (_editingItemId != null) {
                        _updateTextItem(_editingItemId!, text);
                      } else {
                        _addTextItem(text);
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
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    maxLines: null,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'متن خود را بنویسید...',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),

            // اسلایدر سایز فونت
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.text_decrease, color: Colors.white54),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: _minTextFontSize,
                      max: _maxTextFontSize,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() => _fontSize = value);
                      },
                    ),
                  ),
                  const Icon(Icons.text_increase, color: Colors.white54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رنگ متن', style: TextStyle(color: Colors.white)),
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

  // Drawing handlers
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

  void _showStickerSheet() {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryStickerSheet(
        onStickerSelected: (emojiContent) {
          final screenSize = MediaQuery.of(parentContext).size;

          // ایموجی ساده → تبدیل به TextStoryItem
          final newItem = TextStoryItem(
            x: screenSize.width / 2,
            y: screenSize.height / 2,
            text: emojiContent,
            fontSize: 48,
            color: Colors.white,
          );

          setState(() {
            _items.add(newItem);
            _selectedItemId = newItem.id;
          });
        },
        onInteractiveStickerSelected: (type, data) {
          final screenSize = MediaQuery.of(parentContext).size;
          if (type == StoryInteractionType.photo) {
            final imagePath = data['imagePath']?.toString() ?? '';
            if (imagePath.trim().isEmpty) return;
            final imageWidth = _safeDouble(data['width'], fallback: 160);
            final imageHeight = _safeDouble(data['height'], fallback: 160);

            final imageItem = ImageStoryItem(
              x: screenSize.width / 2,
              y: screenSize.height / 2,
              imagePath: imagePath,
              width: imageWidth,
              height: imageHeight,
            );

            setState(() {
              _items.add(imageItem);
              _selectedItemId = imageItem.id;
            });
            return;
          }

          // استیکر تعاملی → تبدیل به StickerStoryItem
          final newItem = StickerStoryItem(
            x: screenSize.width / 2,
            y: screenSize.height / 2,
            stickerPath: '',
            interactionType: type,
            interactionData: Map<String, dynamic>.from(data),
            width: _safeDouble(data['width'], fallback: 100),
            height: _safeDouble(data['height'], fallback: 100),
          );

          setState(() {
            _items.add(newItem);
            _selectedItemId = newItem.id;
          });
        },
      ),
    );
  }
}
