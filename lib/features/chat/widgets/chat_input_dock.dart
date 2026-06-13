import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef ChatInputDockEffectsBuilder = Widget Function(bool reduceEffects);

class ChatInputDock extends StatelessWidget {
  const ChatInputDock({
    super.key,
    required this.totalBottomSpace,
    required this.reservedHeight,
    required this.keyboardVisible,
    required this.reduceEffectsFromKeyboard,
    required this.isScrollingListenable,
    required this.showScrollToBottomListenable,
    required this.showInput,
    required this.showEmojiPanel,
    required this.inputAreaBuilder,
    required this.inputHaloBuilder,
    required this.emojiPanel,
    required this.onScrollToBottom,
    required this.themeBackgroundColor,
    required this.themeIconColor,
  });

  final double totalBottomSpace;
  final double reservedHeight;
  final bool keyboardVisible;
  final bool reduceEffectsFromKeyboard;
  final ValueListenable<bool> isScrollingListenable;
  final ValueListenable<bool> showScrollToBottomListenable;
  final bool showInput;
  final bool showEmojiPanel;
  final ChatInputDockEffectsBuilder inputAreaBuilder;
  final ChatInputDockEffectsBuilder inputHaloBuilder;
  final Widget emojiPanel;
  final VoidCallback onScrollToBottom;
  final Color themeBackgroundColor;
  final Color themeIconColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isScrollingListenable,
      builder: (context, isScrolling, _) {
        final reduceEffects = reduceEffectsFromKeyboard || isScrolling;
        return Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showScrollToBottomListenable,
                  builder: (context, showScrollToBottom, _) {
                    if (!showScrollToBottom) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      right: 16,
                      bottom: totalBottomSpace + 12,
                      child: FloatingActionButton.small(
                        onPressed: onScrollToBottom,
                        backgroundColor: themeBackgroundColor,
                        foregroundColor: themeIconColor,
                        elevation: 4,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                        ),
                      ),
                    );
                  },
                ),
                if (showInput)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        inputHaloBuilder(reduceEffects),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            inputAreaBuilder(reduceEffects),
                            SizedBox(
                              height: reservedHeight,
                              child: showEmojiPanel && !keyboardVisible
                                  ? emojiPanel
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
