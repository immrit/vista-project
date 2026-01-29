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
import '../../../../utils/const.dart';
import '../../data/services/story_upload_service.dart';
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
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        _items[index] = updatedItem;
      }

      // Check for trash proximity
      final screenSize = MediaQuery.of(context).size;
      final trashY = screenSize.height - 80;
      final trashX = screenSize.width / 2;

      final dist =
          (Offset(updatedItem.x, updatedItem.y) - Offset(trashX, trashY))
              .distance;

      final wasOverTrash = _isOverTrash;
      _isOverTrash = dist < 120;

      if (_isOverTrash && !wasOverTrash) {
        HapticFeedback.mediumImpact();
      }

      // Check for alignment guides
      final centerX = screenSize.width / 2;
      final centerY = screenSize.height / 2;
      const snapThreshold = 15.0;

      _showVerticalGuide = (updatedItem.x - centerX).abs() < snapThreshold;
      _showHorizontalGuide = (updatedItem.y - centerY).abs() < snapThreshold;
    });
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
        );
        _showTextInput = false;
        _editingItemId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onVerticalDragStart: (details) {
            _dragStartY = details.globalPosition.dy;
          },
          onVerticalDragEnd: (details) {
            final screenHeight = MediaQuery.of(context).size.height;
            if (_dragStartY > screenHeight * 0.9) return;

            if (!_isDrawing &&
                !_isDragging &&
                (details.primaryVelocity ?? 0) < -300) {
              _showStickerSheet();
            }
          },
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
                      ..._items.map((item) => _buildEditableItem(item)),
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

  /// ساخت آیتم قابل ویرایش با gesture engine جدید
  Widget _buildEditableItem(StoryItem item) {
    final isSelected = item.id == _selectedItemId;

    return EditableStoryItem(
      item: item,
      isSelected: isSelected,
      isDraggingOverTrash: _isOverTrash && isSelected,
      onUpdate: _updateItem,
      onSelect: () => _selectItem(item.id),
      onDragStart: () {
        setState(() => _isDragging = true);
        // Bring to front
        _items.remove(item);
        _items.add(item);
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
    // استایل‌های مختلف متن
    Widget textWidget = Text(
      item.text,
      style: TextStyle(
        color: item.color,
        fontSize: item.fontSize,
        fontFamily: item.fontFamily,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
      textAlign: item.textAlign,
    );

    // اعمال استایل‌های مختلف
    switch (item.styleIndex % 4) {
      case 1:
        // پس‌زمینه مشکی
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: item.fontSize,
              fontFamily: item.fontFamily,
              fontWeight: FontWeight.bold,
            ),
            textAlign: item.textAlign,
          ),
        );
      case 2:
        // پس‌زمینه سفید
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.text,
            style: TextStyle(
              color: Colors.black,
              fontSize: item.fontSize,
              fontFamily: item.fontFamily,
              fontWeight: FontWeight.bold,
            ),
            textAlign: item.textAlign,
          ),
        );
      case 3:
        // متن با Outline
        return Stack(
          children: [
            // Stroke
            Text(
              item.text,
              style: TextStyle(
                fontSize: item.fontSize,
                fontFamily: item.fontFamily,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.black,
              ),
              textAlign: item.textAlign,
            ),
            // Fill
            Text(
              item.text,
              style: TextStyle(
                color: item.color,
                fontSize: item.fontSize,
                fontFamily: item.fontFamily,
                fontWeight: FontWeight.bold,
              ),
              textAlign: item.textAlign,
            ),
          ],
        );
      default:
        return textWidget;
    }
  }

  Widget _buildStickerContent(StickerStoryItem item) {
    // تبدیل موقت به StoryElement برای سازگاری با StickerFactory
    final legacyElement = StoryElement(
      text: '',
      x: item.x,
      y: item.y,
      rotation: item.rotation,
      scale: item.scale,
      color: Colors.white,
      fontSize: 20,
      interactionType: item.interactionType,
      interactionData: item.interactionData,
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
    return Column(
      children: [
        // متن
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
              _selectedItemId = null;
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

  Future<void> _saveStory() async {
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

      // آپلود به سرور
      final uploadResult = await StoryUploadService.uploadMedia(
        mediaFile: tempFile,
        type: StoryMediaType.image,
        onProgress: (progress) {
          debugPrint('Upload progress: ${(progress * 100).toInt()}%');
        },
      );

      if (uploadResult == null) {
        throw Exception('خطا در آپلود استوری');
      }

      // ایجاد استوری در دیتابیس
      final response = await supabase
          .from('stories')
          .insert({
            'user_id': supabase.auth.currentUser!.id,
            'media_url': uploadResult.url,
            'media_type': 'image',
            'duration_type':
                _storyDuration == StoryDuration.hours24 ? '24h' : '48h',
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now()
                .add(_storyDuration == StoryDuration.hours24
                    ? const Duration(hours: 24)
                    : const Duration(hours: 48))
                .toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Story created: ${response['id']}');

      // پاکسازی فایل موقت
      try {
        await tempFile.delete();
      } catch (_) {}

      // بستن loading
      _hideLoadingOverlay();

      if (mounted) {
        // نمایش پیام موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('استوری با موفقیت ارسال شد'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // بازگشت به صفحه اصلی
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _hideLoadingOverlay();
      debugPrint('Story Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('خطا: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
                          () => _textStyleIndex = (_textStyleIndex + 1) % 4);
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
                      min: 16,
                      max: 64,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryStickerSheet(
        onStickerSelected: (emojiContent) {
          Navigator.pop(context);

          final screenSize = MediaQuery.of(context).size;

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
          Navigator.pop(context);

          final screenSize = MediaQuery.of(context).size;

          // استیکر تعاملی → تبدیل به StickerStoryItem
          final newItem = StickerStoryItem(
            x: screenSize.width / 2,
            y: screenSize.height / 2,
            stickerPath: '',
            interactionType: type,
            interactionData: data,
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
