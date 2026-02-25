import 'package:flutter/material.dart';

/// باتم‌شیت انتخاب نوع محتوا (استوری یا وضعیت)
class ContentTypePickerSheet extends StatelessWidget {
  /// Callback وقتی استوری انتخاب شد
  final VoidCallback onStorySelected;

  /// Callback وقتی وضعیت انتخاب شد
  final VoidCallback onNoteSelected;

  const ContentTypePickerSheet({
    super.key,
    required this.onStorySelected,
    required this.onNoteSelected,
  });

  /// نمایش باتم‌شیت
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onStorySelected,
    required VoidCallback onNoteSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ContentTypePickerSheet(
        onStorySelected: onStorySelected,
        onNoteSelected: onNoteSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'چه چیزی می‌خواهید اضافه کنید؟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Story Option
            _OptionTile(
              icon: Icons.camera_alt_rounded,
              iconColor: Colors.purple,
              title: 'استوری',
              subtitle: 'عکس یا ویدیو ۲۴ ساعته',
              textColor: textColor,
              subtitleColor: subtitleColor!,
              onTap: () {
                Navigator.pop(context);
                onStorySelected();
              },
            ),

            // Divider
            Divider(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              height: 1,
              indent: 72,
            ),

            // Note Option
            _OptionTile(
              icon: Icons.chat_bubble_rounded,
              iconColor: Colors.blue,
              title: 'وضعیت',
              subtitle: 'یک متن کوتاه ۲۴ ساعته',
              textColor: textColor,
              subtitleColor: subtitleColor,
              onTap: () {
                Navigator.pop(context);
                onNoteSelected();
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// آیتم گزینه در باتم‌شیت
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: subtitleColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
