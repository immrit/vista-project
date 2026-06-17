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
  double get dragStartDistanceMotionThreshold => 1.0;

  @override
  double get minFlingVelocity => 30.0;

  /// Cap momentum on 120Hz/144Hz displays to prevent unrealistically fast scroll.
  @override
  double carriedMomentum(double velocity) {
    const maxVelocity = 8000.0;
    return super.carriedMomentum(velocity).clamp(-maxVelocity, maxVelocity);
  }
}

ScrollPhysics chatListScrollPhysics(BuildContext context) {
  // Use BouncingScrollPhysics across all platforms for a smoother, iOS-like 
  // or Telegram-like feeling, eliminating the "dry" and sudden ClampingScrollPhysics.
  const ScrollPhysics platformPhysics = BouncingScrollPhysics(
    decelerationRate: ScrollDecelerationRate.normal,
  );
  return const ChatScrollPhysics(
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
