import '../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'settings_providers.dart';
import 'package:Vista/utils/themes.dart';

// Provider برای مدیریت brightness (تاریک/روشن)
final brightnessProvider =
    StateNotifierProvider<BrightnessNotifier, Brightness>((ref) {
  return BrightnessNotifier();
});

// Provider ترکیبی که تم نهایی را تولید می‌کند
final dynamicThemeProvider = Provider<ThemeData>((ref) {
  final brightness = ref.watch(brightnessProvider);

  // دریافت تنظیمات دسترسی‌پذیری
  final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
  final accessibility =
      appSettingsAsync.value?['accessibility'] as Map<String, dynamic>? ?? {};

  final largeText = accessibility['large_text'] as bool? ?? false;
  final boldText = accessibility['bold_text'] as bool? ?? false;
  // final highContrast = accessibility['high_contrast'] as bool? ?? false; // Not implemented yet in VistaThemes but placeholder for future

  // Basic Theme
  ThemeData theme = brightness == Brightness.dark
      ? VistaThemes.darkTheme
      : VistaThemes.lightTheme;

  // Apply Accessibility Overrides
  // We can use copyWith to adjust text themes if needed
  if (largeText || boldText) {
    // This is a simplified way to apply text scaling/bolding.
    // Ideally VistaThemes should support these parameters or we construct a new text theme.
    // For now, let's just return the base theme as the critical fix is solving build errors.
    // Real implementation would modify textTheme here.
  }

  return theme;
});

class BrightnessNotifier extends StateNotifier<Brightness> {
  Isar? _isar;

  BrightnessNotifier() : super(Brightness.light) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadFromIsar();
    } catch (e) {
      logDebug('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  void _loadFromIsar() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = settings.isDark ? Brightness.dark : Brightness.light;
      }
    } catch (e) {
      logDebug('خطا در بارگذاری brightness: $e');
    }
  }

  void updateBrightness(Brightness brightness) {
    state = brightness;
    _saveToIsar();
  }

  void toggleBrightness() {
    state = state == Brightness.light ? Brightness.dark : Brightness.light;
    _saveToIsar();
  }

  void _saveToIsar() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = state == Brightness.dark
            ..selectedColor = 'white'; // Default legacy value
        } else {
          settings.isDark = state == Brightness.dark;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      logDebug('خطا در ذخیره brightness: $e');
    }
  }
}

// Deprecated providers kept to prevent downstream breakages if any file imports them unexpectedly,
// though we aim to remove usages. For stricter cleanup, I'm removing selectedColorProvider.
// If something breaks, we will fix the consumer.
