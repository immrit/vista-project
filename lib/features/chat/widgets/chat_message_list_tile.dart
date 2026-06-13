import 'package:flutter/material.dart';

/// Keeps heavy message tiles (media/voice) alive while scrolling.
/// Pure wrapper — child layout and visuals are unchanged.
class ChatMessageListTile extends StatefulWidget {
  const ChatMessageListTile({
    super.key,
    required this.keepAlive,
    required this.child,
  });

  final bool keepAlive;
  final Widget child;

  @override
  State<ChatMessageListTile> createState() => _ChatMessageListTileState();
}

class _ChatMessageListTileState extends State<ChatMessageListTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(ChatMessageListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
