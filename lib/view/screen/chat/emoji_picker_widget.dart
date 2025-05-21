import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

class EmojiPickerWidget extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback onBackspacePressed;

  const EmojiPickerWidget({
    Key? key,
    required this.onEmojiSelected,
    required this.onBackspacePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) => onEmojiSelected(emoji.emoji),
        onBackspacePressed: onBackspacePressed,
        config: Config(
          height: 250,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 *
                (foundation.defaultTargetPlatform ==
                        foundation.TargetPlatform.iOS
                    ? 1.2
                    : 1.0),
            backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
            iconColorSelected: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabIndicatorAnimDuration: const Duration(milliseconds: 150),
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
            buttonColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
