import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef ChatInputDockEffectsBuilder = Widget Function(bool reduceEffects);
typedef ChatInputDockHaloBuilder = Widget Function(
  bool reduceEffects, {
  required double gapHeight,
  required bool keyboardVisible,
});

/// Layout flags for gap overrides (emoji, transitions). Live keyboard height
/// always comes from [MediaQuery.viewInsetsOf] inside this widget.
class ChatInputDockLayout {
  const ChatInputDockLayout({
    required this.showEmojiPanel,
    required this.lockEmojiPanel,
    required this.isKeyboardOpening,
    required this.isKeyboardRequested,
    required this.cachedKeyboardHeight,
    required this.safeBottom,
  });

  final bool showEmojiPanel;
  final bool lockEmojiPanel;
  final bool isKeyboardOpening;
  final bool isKeyboardRequested;
  final double cachedKeyboardHeight;
  final double safeBottom;

  static const keyboardVisibleThreshold = 80.0;

  static const initial = ChatInputDockLayout(
    showEmojiPanel: false,
    lockEmojiPanel: false,
    isKeyboardOpening: false,
    isKeyboardRequested: false,
    cachedKeyboardHeight: 300,
    safeBottom: 34,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatInputDockLayout &&
      other.showEmojiPanel == showEmojiPanel &&
      other.lockEmojiPanel == lockEmojiPanel &&
      other.isKeyboardOpening == isKeyboardOpening &&
      other.isKeyboardRequested == isKeyboardRequested &&
      other.cachedKeyboardHeight == cachedKeyboardHeight &&
      other.safeBottom == safeBottom;

  @override
  int get hashCode => Object.hash(
        showEmojiPanel,
        lockEmojiPanel,
        isKeyboardOpening,
        isKeyboardRequested,
        cachedKeyboardHeight,
        safeBottom,
      );
}

/// Input dock synced to the OS keyboard animation.
///
/// Must be placed **outside** [KeyboardStableMediaQuery] so
/// [MediaQuery.viewInsetsOf] updates on every IME frame — only this subtree
/// rebuilds, keeping the input glued to the keyboard top.
class ChatInputDock extends StatelessWidget {
  const ChatInputDock({
    super.key,
    required this.inputHeightListenable,
    required this.layoutListenable,
    required this.keyboardEffectsListenable,
    required this.isScrollingListenable,
    required this.showScrollToBottomListenable,
    required this.showInput,
    required this.inputAreaBuilder,
    required this.inputHaloBuilder,
    required this.emojiPanel,
    required this.onScrollToBottom,
    required this.themeBackgroundColor,
    required this.themeIconColor,
  });

  final ValueListenable<double> inputHeightListenable;
  final ValueListenable<ChatInputDockLayout> layoutListenable;
  final ValueListenable<bool> keyboardEffectsListenable;
  final ValueListenable<bool> isScrollingListenable;
  final ValueListenable<bool> showScrollToBottomListenable;
  final bool showInput;
  final ChatInputDockEffectsBuilder inputAreaBuilder;
  final ChatInputDockHaloBuilder inputHaloBuilder;
  final Widget emojiPanel;
  final VoidCallback onScrollToBottom;
  final Color themeBackgroundColor;
  final Color themeIconColor;

  static double resolveBottomGap(
    double liveInset,
    ChatInputDockLayout layout,
  ) {
    final keyboardVisible =
        liveInset > ChatInputDockLayout.keyboardVisibleThreshold;
    if (layout.showEmojiPanel ||
        layout.lockEmojiPanel ||
        layout.isKeyboardOpening) {
      return layout.cachedKeyboardHeight;
    }
    if (keyboardVisible) {
      return liveInset;
    }
    if (layout.isKeyboardRequested) {
      return layout.cachedKeyboardHeight;
    }
    return layout.safeBottom;
  }

  @override
  Widget build(BuildContext context) {
    // Frame-perfect IME tracking — rebuilds only this dock, not the message list.
    final liveInset = MediaQuery.viewInsetsOf(context).bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: keyboardEffectsListenable,
      builder: (context, keyboardEffects, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isScrollingListenable,
          builder: (context, isScrolling, _) {
            final reduceEffects = keyboardEffects || isScrolling;

            return ValueListenableBuilder<double>(
              valueListenable: inputHeightListenable,
              builder: (context, inputHeight, _) {
                return ValueListenableBuilder<ChatInputDockLayout>(
                  valueListenable: layoutListenable,
                  builder: (context, layout, _) {
                    final bottomGap = resolveBottomGap(liveInset, layout);
                    final keyboardVisible = liveInset >
                        ChatInputDockLayout.keyboardVisibleThreshold;
                    final dockBottomSpace = inputHeight + bottomGap;
                    final inputArea = inputAreaBuilder(reduceEffects);

                    return Stack(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: showScrollToBottomListenable,
                          builder: (context, showScrollToBottom, _) {
                            if (!showScrollToBottom) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              right: 16,
                              bottom: dockBottomSpace + 12,
                              child: FloatingActionButton.small(
                                heroTag: null,
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
                          Positioned.fill(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Halo must live in the full-screen stack so
                                // bottom: gapHeight anchors above the keyboard,
                                // not inside the ~70px input row.
                                inputHaloBuilder(
                                  reduceEffects,
                                  gapHeight: bottomGap,
                                  keyboardVisible: keyboardVisible,
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: RepaintBoundary(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        inputArea,
                                        SizedBox(
                                          height: bottomGap,
                                          child: layout.showEmojiPanel &&
                                                  !keyboardVisible
                                              ? emojiPanel
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
