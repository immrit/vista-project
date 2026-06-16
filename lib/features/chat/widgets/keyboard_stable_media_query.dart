import 'package:flutter/material.dart';

/// Shields heavy chat subtrees from IME-driven [MediaQuery] churn.
///
/// While the keyboard animates, Flutter updates [MediaQueryData.viewInsets] and
/// often [MediaQueryData.padding] on every frame. Widgets that call
/// [MediaQuery.of] rebuild with each tick — including every message bubble.
///
/// Descendants of this widget see stable size/padding and zero viewInsets, so
/// they only rebuild when size, theme, text scale, etc. actually change.
class KeyboardStableMediaQuery extends StatelessWidget {
  const KeyboardStableMediaQuery({super.key, required this.child});

  final Widget child;

  static MediaQueryData stableData(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.copyWith(
      viewInsets: EdgeInsets.zero,
      padding: mq.viewPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: stableData(context),
      child: child,
    );
  }
}
