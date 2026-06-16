import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Telegram X photo bubble sizing.
///
/// Mirrors [MosaicWrapper] singular-item layout from Telegram X:
/// - [ChatMediaFitMode.fitWidth]: MODE_FIT_WIDTH (width anchored, height scaled)
/// - [ChatMediaFitMode.fitAsIs]: MODE_FIT_AS_IS (fit inside bounds, keep ratio)
class ChatMediaBubbleLayout {
  ChatMediaBubbleLayout._();

  /// Telegram X: MosaicWrapper.MIN_LAYOUT_WIDTH
  static const double minLayoutWidth = 160.0;

  /// Telegram X: MosaicWrapper.MIN_LAYOUT_HEIGHT
  static const double minLayoutHeight = 120.0;

  /// Telegram X: TGMessageMedia.MAX_RATIO
  static const double maxHeightRatioFitWidth = 1.5;

  /// Telegram X: getSmallestMaxContentHeight factor
  static const double maxHeightRatioFitAsIs = 1.24;

  /// Default portrait ratio when intrinsic dimensions are unknown.
  static const double fallbackPortraitRatio = 9 / 16;

  static Size computeDisplaySize({
    required double maxLayoutWidth,
    required double maxLayoutHeight,
    int? imageWidth,
    int? imageHeight,
    ChatMediaFitMode fitMode = ChatMediaFitMode.fitWidth,
  }) {
    final intrinsicWidth = imageWidth ?? 0;
    final intrinsicHeight = imageHeight ?? 0;

    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
      return _fallbackSize(
        maxLayoutWidth: maxLayoutWidth,
        maxLayoutHeight: maxLayoutHeight,
        fitMode: fitMode,
      );
    }

    var width = intrinsicWidth.toDouble();
    var height = intrinsicHeight.toDouble();

    switch (fitMode) {
      case ChatMediaFitMode.fitWidth:
        final scale = maxLayoutWidth / width;
        width = maxLayoutWidth;
        height = math.min(maxLayoutHeight, height * scale);
        break;
      case ChatMediaFitMode.fitAsIs:
        var scale = math.min(maxLayoutWidth / width, maxLayoutHeight / height);
        width *= scale;
        height *= scale;

        if (width < minLayoutWidth) {
          scale = minLayoutWidth / width;
          width = minLayoutWidth;
          height = math.min(maxLayoutHeight, height * scale);
        } else if (height < minLayoutHeight) {
          scale = minLayoutHeight / height;
          height = minLayoutHeight;
          width = math.min(maxLayoutWidth, width * scale);
        }
        break;
    }

    return Size(
      width.clamp(1.0, maxLayoutWidth),
      height.clamp(1.0, maxLayoutHeight),
    );
  }

  static Size computeBubblePhotoSize({
    required double screenWidth,
    required double screenHeight,
    int? imageWidth,
    int? imageHeight,
    double? bubbleMaxWidth,
    bool useFullWidth = true,
  }) {
    final layoutWidth = bubbleMaxWidth ??
        (math.min(screenWidth, screenHeight) * 0.75).clamp(minLayoutWidth, screenWidth);

    if (useFullWidth) {
      var layoutHeight = layoutWidth * maxHeightRatioFitWidth;
      if (imageWidth != null &&
          imageHeight != null &&
          imageWidth > 0 &&
          imageHeight > 0) {
        final scaledHeight =
            imageHeight * (layoutWidth / imageWidth);
        layoutHeight = math.min(layoutHeight, scaledHeight);
      }
      return computeDisplaySize(
        maxLayoutWidth: layoutWidth,
        maxLayoutHeight: layoutHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        fitMode: ChatMediaFitMode.fitWidth,
      );
    }

    final layoutHeight = layoutWidth * maxHeightRatioFitAsIs;
    return computeDisplaySize(
      maxLayoutWidth: layoutWidth,
      maxLayoutHeight: layoutHeight,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      fitMode: ChatMediaFitMode.fitAsIs,
    );
  }

  static Size _fallbackSize({
    required double maxLayoutWidth,
    required double maxLayoutHeight,
    required ChatMediaFitMode fitMode,
  }) {
    final fallbackHeight = fitMode == ChatMediaFitMode.fitWidth
        ? math.min(maxLayoutHeight, maxLayoutWidth / fallbackPortraitRatio)
        : math.min(
            maxLayoutHeight,
            math.max(minLayoutHeight, maxLayoutWidth / fallbackPortraitRatio),
          );

    return Size(
      maxLayoutWidth,
      fallbackHeight.clamp(minLayoutHeight, maxLayoutHeight),
    );
  }
}

enum ChatMediaFitMode {
  fitWidth,
  fitAsIs,
}
