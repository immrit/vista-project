import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReactionPickerSheet extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  // لیست ایموجی‌های محبوب (مثل تلگرام/واتساپ)
  static const List<String> popularEmojis = [
    '👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥',
    '😍', '🎉', '💯', '✨', '🤔', '😊', '👌', '💪',
    '😎', '🥰', '😘', '😉', '🤗', '🤩', '😋', '🤤',
  ];

  const ReactionPickerSheet({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // عنوان
          Text(
            'انتخاب واکنش',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          // Grid ایموجی‌ها
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: popularEmojis.length,
            itemBuilder: (context, index) {
              final emoji = popularEmojis[index];
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onEmojiSelected(emoji);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.grey.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required Function(String emoji) onEmojiSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReactionPickerSheet(
        onEmojiSelected: onEmojiSelected,
      ),
    );
  }
}











