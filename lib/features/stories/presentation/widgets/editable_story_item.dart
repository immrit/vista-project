import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
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

  // child param is ignored but kept for basic compatibility if needed,
  // though we prefer internal build.
  // If we want to strictly follow user's "replace content" logic we shouldn't have it,
  // but to fix the build quickly we might accept it and ignore it?
  // Better: Don't add child, let's fix the call site.
  // But we DO need to add isDraggingOverTrash and onDoubleTap.

  const EditableStoryItem({
    Key? key,
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
  }) : super(key: key);

  @override
  State<EditableStoryItem> createState() => _EditableStoryItemState();
}

class _EditableStoryItemState extends State<EditableStoryItem> {
  late Matrix4 _initialMatrix;
  Offset? _initialFocalPoint;

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

    // Wrap content with border and delete button when selected
    Widget framedContent = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // The main content with an optional border when selected
        Container(
          decoration: widget.isSelected
              ? BoxDecoration(
                  border: Border.all(
                      color: widget.isDraggingOverTrash
                          ? Colors.red
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
          // FittedBox ensures the container shrinks to fit the content tightly
          child: FittedBox(
            fit: BoxFit.contain,
            child: content,
          ),
        ),
        // Delete button (top-left corner) - Only visible when selected
        if (widget.isSelected)
          Positioned(
            top: -12,
            left: -12,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onDelete?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.black, size: 18),
              ),
            ),
          ),
      ],
    );

    // Apply transformations and handle gestures
    return Transform(
      transform: widget.item.transformMatrix,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          widget.onSelect();
          HapticFeedback.selectionClick();
        },
        onDoubleTap: widget.onDoubleTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Container(
          color: Colors.transparent,
          child: framedContent,
        ),
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.onSelect();
    widget.onDragStart();

    _initialMatrix = widget.item.transformMatrix;
    _initialFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_initialFocalPoint == null) return;

    final translationDelta = details.focalPoint - _initialFocalPoint!;
    final scaleDelta = details.scale;
    final rotationDelta = details.rotation;

    final translationMatrix = Matrix4.identity()
      ..translate(translationDelta.dx, translationDelta.dy);

    final rotationMatrix = Matrix4.identity()..rotateZ(rotationDelta);

    final scaleMatrix = Matrix4.identity()..scale(scaleDelta);

    Matrix4 newMatrix = Matrix4.identity();
    newMatrix.multiply(translationMatrix);
    newMatrix.multiply(_initialMatrix);
    newMatrix.multiply(rotationMatrix);
    newMatrix.multiply(scaleMatrix);

    final vm.Vector3 translation = newMatrix.getTranslation();

    // Extract rotation
    final double rotation =
        math.atan2(newMatrix.storage[1], newMatrix.storage[0]);

    // Extract scale
    final double scale = math.sqrt(newMatrix.storage[0] * newMatrix.storage[0] +
        newMatrix.storage[1] * newMatrix.storage[1]);

    final updatedItem = widget.item.copyWith(
      x: translation.x,
      y: translation.y,
      scale: scale,
      rotation: rotation,
    );

    widget.onUpdate(updatedItem);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    widget.onDragEnd();
    _initialFocalPoint = null;
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
