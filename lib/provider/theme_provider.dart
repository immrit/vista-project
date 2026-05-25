import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/utils/themes.dart';

import 'package:Vista/DB/advanced_settings_service.dart';

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';
export '../features/profile/providers/profile_controller.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initialThemeMode());

  static ThemeMode _initialThemeMode() {
    try {
      final appearance = AdvancedSettingsService().getAdvancedAppSettings()['appearance'] as Map<String, dynamic>?;
      final themeStr = appearance?['theme'] as String?;
      if (themeStr == 'light') return ThemeMode.light;
      if (themeStr == 'dark') return ThemeMode.dark;
    } catch (_) {}
    return ThemeMode.system;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = mode;
    final service = AdvancedSettingsService();
    final currentSettings = service.getAdvancedAppSettings();
    final appearance = Map<String, dynamic>.from(currentSettings['appearance'] as Map? ?? {});
    
    appearance['theme'] = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
    currentSettings['appearance'] = appearance;
    
    await service.updateAdvancedAppSettings(currentSettings);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// For backward compatibility if anything else needs it
final brightnessProvider = Provider<Brightness>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == ThemeMode.light) return Brightness.light;
  if (mode == ThemeMode.dark) return Brightness.dark;
  return PlatformDispatcher.instance.platformBrightness;
});

final dynamicThemeProvider = StateProvider<ThemeData>((ref) {
  final brightness = ref.watch(brightnessProvider);
  return brightness == Brightness.dark
      ? VistaThemes.darkTheme
      : VistaThemes.lightTheme;
});
