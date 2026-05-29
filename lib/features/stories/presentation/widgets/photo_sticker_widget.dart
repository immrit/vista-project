import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/story_editor_models.dart';

class PhotoStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const PhotoStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? const {};
    final imagePath = data['imagePath']?.toString() ?? '';
    final width = _asDouble(data['width']) ?? element.width ?? 180;
    final height = _asDouble(data['height']) ?? element.height ?? 180;

    if (imagePath.trim().isEmpty) {
      // In viewer mode with no URL, nothing to render.
      if (!isEditable) return const SizedBox.shrink();
      return _fallback(width, height);
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return _frame(
        width,
        height,
        CachedNetworkImage(
          imageUrl: imagePath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _fallback(width, height),
        ),
      );
    }

    // Local file path — only accessible in the editor on the creator's device.
    if (!isEditable) {
      // Local path not available on viewer device.
      return const SizedBox.shrink();
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return _fallback(width, height);
    }

    return _frame(
      width,
      height,
      Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _frame(double width, double height, Widget child) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white30),
      ),
      child: child,
    );
  }

  Widget _fallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white70,
        size: 32,
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
