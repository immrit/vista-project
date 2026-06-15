import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll physics tuned for chat lists: lower touch slop and platform-native feel.
class ChatScrollPhysics extends ScrollPhysics {
  const ChatScrollPhysics({super.parent});

  @override
  ChatScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ChatScrollPhysics(parent: buildParent(ancestor));
  }

  /// React to small finger movements instead of waiting for full touch slop.
  @override
  double get dragStartDistanceMotionThreshold {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 3.5,
      _ => 1.0,
    };
  }

  @override
  double get minFlingVelocity => 50.0;
}

ScrollPhysics chatListScrollPhysics(BuildContext context) {
  final platform = Theme.of(context).platform;
  final ScrollPhysics platformPhysics = switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(),
    _ => const ClampingScrollPhysics(),
  };
  return ChatScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(parent: platformPhysics),
  );
}

/// Applies chat scroll physics and enables trackpad/stylus dragging.
class ChatScrollBehavior extends MaterialScrollBehavior {
  const ChatScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return chatListScrollPhysics(context);
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
