import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/story_editor_models.dart';

/// ویجت قابل ویرایش برای آیتم‌های استوری
/// با استفاده از FittedBox و Matrix4 برای حداکثر کارایی و حذف حاشیه‌های اضافی
class EditableStoryItem extends StatefulWidget {
  final StoryItem item;
  final ValueChanged<StoryItem> onUpdate;
  final VoidCallback onSelect;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final VoidCallback? onDelete;
  final VoidCallback? onDoubleTap;
  final bool isSelected;
  final bool isDraggingOverTrash;
  final Widget? child;

  const EditableStoryItem({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragEnd,
    required this.isSelected,
    this.onDelete,
    this.onDoubleTap,
    this.isDraggingOverTrash = false,
    this.child,
  });

  @override
  State<EditableStoryItem> createState() => _EditableStoryItemState();
}

class _EditableStoryItemState extends State<EditableStoryItem> {
  Offset? _initialFocalPoint;
  double _startItemX = 0.0;
  double _startItemY = 0.0;
  double _startItemScale = 1.0;
  double _startItemRotation = 0.0;

  static const double _minScale = 0.35;
  static const double _maxScale = 6.0;

  @override
  Widget build(BuildContext context) {
    // The core content widget (Text or Sticker)
    Widget content;

    if (widget.child != null) {
      content = widget.child!;
    } else if (widget.item is TextStoryItem) {
      final textItem = widget.item as TextStoryItem;
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: textItem.backgroundColor != null
            ? BoxDecoration(
                color: textItem.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Text(
          textItem.text,
          style: TextStyle(
            color: textItem.color,
            fontSize: textItem.fontSize,
            fontFamily: textItem.fontFamily,
          ),
          textAlign: textItem.textAlign,
        ),
      );
    } else if (widget.item is ImageStoryItem) {
      final imageItem = widget.item as ImageStoryItem;
      content = Image.file(
        File(imageItem.imagePath),
        width: imageItem.width,
        height: imageItem.height,
        fit: BoxFit.cover,
      );
    } else {
      content = Container(
        width: 100,
        height: 100,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }

    // Apply Animations if item is TextStoryItem
    if (widget.item is TextStoryItem) {
      final textItem = widget.item as TextStoryItem;
      switch (textItem.animationType) {
        case TextAnimationType.typewriter:
          content = content
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8));
          break;
        case TextAnimationType.fade:
          content = content
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then(delay: 200.ms)
              .fadeOut(duration: 800.ms);
          break;
        case TextAnimationType.scale:
          content = content
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 1000.ms);
          break;
        case TextAnimationType.slide:
          content = content
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .slideY(
                  begin: 0,
                  end: -0.1,
                  duration: 800.ms,
                  curve: Curves.easeInOut);
          break;
        case TextAnimationType.none:
          break;
      }
    }

    // Constraint max width to screen width
    content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 40,
      ),
      child: content,
    );

    // Wrap content with border when selected
    Widget framedContent = RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The main content with an optional border when selected
          Container(
            decoration: widget.isSelected
                ? BoxDecoration(
                    border: Border.all(
                        color: widget.isDraggingOverTrash
                            ? Colors
                                .transparent // Hide border when over trash for cleaner look
                            : Colors.white,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  )
                : null,
            child: content,
          ),
        ],
      ),
    );

    // Apply Drag-to-Delete visual feedback (Shrink & Fade)
    if (widget.isDraggingOverTrash) {
      framedContent = Opacity(
        opacity: 0.6,
        child: Transform.scale(
          scale: 0.7,
          child: framedContent,
        ),
      );
    }

    // Apply transformations and handle gestures
    return Transform(
      transform: widget.item.transformMatrix,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onTap: () {
          widget.onSelect();
          HapticFeedback.selectionClick();
        },
        onDoubleTap: widget.onDoubleTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            color: Colors.transparent,
            child: framedContent,
          ),
        ),
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.onSelect();
    widget.onDragStart();

    final item = widget.item;
    _initialFocalPoint = details.focalPoint;
    _startItemX = item.x;
    _startItemY = item.y;
    _startItemScale = item.scale;
    _startItemRotation = item.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_initialFocalPoint == null) return;
    final item = widget.item;
    final totalDelta = details.focalPoint - _initialFocalPoint!;

    var nextX = _startItemX + totalDelta.dx;
    var nextY = _startItemY + totalDelta.dy;
    var nextScale = _startItemScale;
    var nextRotation = _startItemRotation;

    // Two-finger gesture: absolute scale/rotation from gesture start.
    if (details.pointerCount > 1) {
      if (details.scale.isFinite && details.scale > 0) {
        nextScale =
            (_startItemScale * details.scale).clamp(_minScale, _maxScale);
      }

      if (details.rotation.isFinite) {
        nextRotation = _normalizeAngle(_startItemRotation + details.rotation);
      }
    }

    if (!nextX.isFinite) nextX = _startItemX;
    if (!nextY.isFinite) nextY = _startItemY;
    if (!nextScale.isFinite) nextScale = item.scale;
    if (!nextRotation.isFinite) nextRotation = item.rotation;

    widget.onUpdate(
      item.copyWith(
        x: nextX,
        y: nextY,
        scale: nextScale,
        rotation: nextRotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    widget.onDragEnd();
    _initialFocalPoint = null;
  }

  double _normalizeAngle(double angle) {
    const twoPi = math.pi * 2;
    var normalized = angle;

    while (normalized > math.pi) {
      normalized -= twoPi;
    }
    while (normalized < -math.pi) {
      normalized += twoPi;
    }

    // Snap softly to zero for easier straight alignment.
    if (normalized.abs() < 0.015) {
      return 0;
    }
    return normalized;
  }
}

/// ویجت سطل زباله برای حذف آیتم‌ها
class StoryTrashBin extends StatelessWidget {
  final bool isActive;
  final bool isHovering;

  const StoryTrashBin({
    super.key,
    this.isActive = false,
    this.isHovering = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(isHovering ? 20 : 16),
      decoration: BoxDecoration(
        color: isHovering
            ? Colors.red
            : (isActive ? Colors.red.withOpacity(0.3) : Colors.transparent),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.red : Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: isHovering ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          Icons.delete_outline,
          color: isActive || isHovering ? Colors.white : Colors.white54,
          size: isHovering ? 32 : 28,
        ),
      ),
    );
  }
}

/// خطوط راهنما برای تراز کردن
class AlignmentGuides extends StatelessWidget {
  final bool showVertical;
  final bool showHorizontal;

  const AlignmentGuides({
    super.key,
    this.showVertical = false,
    this.showHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          if (showVertical)
            Center(
              child: Container(
                width: 1,
                height: double.infinity,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          if (showHorizontal)
            Center(
              child: Container(
                width: double.infinity,
                height: 1,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }
}
