import 'package:flutter/material.dart';

/// تم‌های قابل انتخاب برای قالب اشتراک‌گذاری استوری
enum VistaStoryShareTheme {
  dark,
  light,
  vista,
}

extension VistaStoryShareThemeX on VistaStoryShareTheme {
  String get label => switch (this) {
        VistaStoryShareTheme.dark => 'تیره',
        VistaStoryShareTheme.light => 'روشن',
        VistaStoryShareTheme.vista => 'ویستا',
      };

  List<Color> get previewGradient => switch (this) {
        VistaStoryShareTheme.dark => const [
            Color(0xFF050505),
            Color(0xFF1A1A1A),
          ],
        VistaStoryShareTheme.light => const [
            Color(0xFFF7F2EC),
            Color(0xFFE4DDD6),
          ],
        VistaStoryShareTheme.vista => const [
            Color(0xFFFFFFFF),
            Color(0xFFF0F0F0),
          ],
      };
}
