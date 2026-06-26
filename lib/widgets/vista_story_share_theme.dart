import 'package:flutter/material.dart';
import 'package:Vista/core/theme/app_theme.dart';

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
            AppColors.darkSurface,
          ],
        VistaStoryShareTheme.light => const [
            Color(0xFFF7F2EC),
            Color(0xFFE4DDD6),
          ],
        VistaStoryShareTheme.vista => const [
            Colors.white,
            Color(0xFFF0F0F0),
          ],
      };
}
