import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Single-pass replacement for `IntrinsicWidth` on plain-text bubbles.
///
/// The old text bubble was `IntrinsicWidth(Column(stretch)[text, footerRow])`,
/// which lays the message paragraph out twice per build (once to measure the
/// intrinsic width, once for real) — a real UI-thread cost while flinging a
/// text-heavy chat.
///
/// This lays [text] and [footer] out exactly once each, sizes itself to
/// `max(text.width, footer.width)` (clamped to the incoming max width), stacks
/// them vertically with [gap], and pins the footer to the *end* of the reading
/// direction (RTL → left edge, LTR → right edge). That reproduces the previous
/// `Column(crossAxisAlignment: stretch)[text, Row(max, spaceBetween)[_, time]]`
/// layout pixel-for-pixel, without the second paragraph layout pass.
class ChatTextBubbleLayout extends MultiChildRenderObjectWidget {
  ChatTextBubbleLayout({
    super.key,
    required this.textDirection,
    required this.isMe,
    required this.gap,
    required Widget text,
    required Widget footer,
  }) : super(children: [text, footer]);

  /// Reading direction of the message content. Drives which edge the footer
  /// (timestamp + tick) is pinned to.
  final TextDirection textDirection;

  /// Whether the message is sent by the current user.
  final bool isMe;

  /// Vertical gap between the text block and the footer (was a `SizedBox`).
  final double gap;

  @override
  RenderChatTextBubbleLayout createRenderObject(BuildContext context) {
    return RenderChatTextBubbleLayout(
      textDirection: textDirection,
      isMe: isMe,
      gap: gap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderChatTextBubbleLayout renderObject,
  ) {
    renderObject
      ..textDirection = textDirection
      ..isMe = isMe
      ..gap = gap;
  }
}

class _BubbleParentData extends ContainerBoxParentData<RenderBox> {}

class RenderChatTextBubbleLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BubbleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BubbleParentData> {
  RenderChatTextBubbleLayout({
    required TextDirection textDirection,
    required bool isMe,
    required double gap,
  })  : _textDirection = textDirection,
        _isMe = isMe,
        _gap = gap;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  bool _isMe;
  set isMe(bool value) {
    if (_isMe == value) return;
    _isMe = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BubbleParentData) {
      child.parentData = _BubbleParentData();
    }
  }

  @override
  void performLayout() {
    final RenderBox text = firstChild!;
    final RenderBox footer = lastChild!;

    final double maxWidth = constraints.maxWidth;
    final BoxConstraints childConstraints = BoxConstraints(
      maxWidth: maxWidth.isFinite ? maxWidth : double.infinity,
    );

    text.layout(childConstraints, parentUsesSize: true);
    footer.layout(childConstraints, parentUsesSize: true);

    double width = math.max(text.size.width, footer.size.width);
    if (maxWidth.isFinite) width = math.min(width, maxWidth);
    width = constraints.constrainWidth(width);

    final double height = constraints.constrainHeight(
      text.size.height + _gap + footer.size.height,
    );

    final bool isRtl = _textDirection == TextDirection.rtl;
    final _BubbleParentData textPd = text.parentData! as _BubbleParentData;
    final _BubbleParentData footerPd = footer.parentData! as _BubbleParentData;

    textPd.offset = Offset(
      isRtl ? width - text.size.width : 0.0,
      0.0,
    );
    
    // Pin footer to the edge of the screen (outer edge of the bubble).
    // isMe (Sent): right edge in both LTR/RTL, so width - footer.size.width
    // !isMe (Received): left edge in both LTR/RTL, so 0.0
    footerPd.offset = Offset(
      _isMe ? width - footer.size.width : 0.0,
      text.size.height + _gap,
    );

    size = Size(width, height);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox text = firstChild!;
    final RenderBox footer = lastChild!;
    final BoxConstraints childConstraints = BoxConstraints(
      maxWidth: constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : double.infinity,
    );
    final Size textSize = text.getDryLayout(childConstraints);
    final Size footerSize = footer.getDryLayout(childConstraints);
    double width = math.max(textSize.width, footerSize.width);
    if (constraints.maxWidth.isFinite) {
      width = math.min(width, constraints.maxWidth);
    }
    return constraints.constrain(
      Size(width, textSize.height + _gap + footerSize.height),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
        firstChild!.getMinIntrinsicWidth(double.infinity),
        lastChild!.getMinIntrinsicWidth(double.infinity),
      );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
        firstChild!.getMaxIntrinsicWidth(double.infinity),
        lastChild!.getMaxIntrinsicWidth(double.infinity),
      );

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild!.getMinIntrinsicHeight(width) +
      _gap +
      lastChild!.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      firstChild!.getMaxIntrinsicHeight(width) +
      _gap +
      lastChild!.getMaxIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
