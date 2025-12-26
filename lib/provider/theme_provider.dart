import '../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'settings_providers.dart';
import '../view/util/themes.dart';

// Provider برای مدیریت رنگ انتخاب شده
final selectedColorProvider =
    StateNotifierProvider<SelectedColorNotifier, ThemeColor>((ref) {
  return SelectedColorNotifier();
});

// Provider برای مدیریت brightness (تاریک/روشن)
final brightnessProvider =
    StateNotifierProvider<BrightnessNotifier, Brightness>((ref) {
  return BrightnessNotifier();
});

// Provider ترکیبی که تم نهایی را تولید می‌کند
final dynamicThemeProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(selectedColorProvider);
  final brightness = ref.watch(brightnessProvider);

  // دریافت تنظیمات دسترسی‌پذیری
  final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
  final accessibility =
      appSettingsAsync.value?['accessibility'] as Map<String, dynamic>? ?? {};

  final largeText = accessibility['large_text'] as bool? ?? false;
  final boldText = accessibility['bold_text'] as bool? ?? false;
  final highContrast = accessibility['high_contrast'] as bool? ?? false;
  final colorBlindMode = accessibility['color_blind_mode'] as String? ?? 'none';

  return createTheme(
    color,
    brightness,
    largeText: largeText,
    boldText: boldText,
    highContrast: highContrast,
    colorBlindMode: colorBlindMode,
  );
});

// Notifier برای مدیریت رنگ انتخاب شده
class SelectedColorNotifier extends StateNotifier<ThemeColor> {
  Isar? _isar;

  SelectedColorNotifier() : super(ThemeColor.white) {
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
        state = _parseThemeColor(settings.selectedColor);
      }
    } catch (e) {
      logDebug('خطا در بارگذاری رنگ: $e');
    }
  }

  void updateColor(ThemeColor color) {
    state = color;
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
            ..isDark = false // Default
            ..selectedColor = _themeColorToString(state);
        } else {
          settings.selectedColor = _themeColorToString(state);
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      logDebug('خطا در ذخیره رنگ: $e');
    }
  }

  ThemeColor _parseThemeColor(String colorName) {
    switch (colorName) {
      case 'red':
        return ThemeColor.red;
      case 'yellow':
        return ThemeColor.yellow;
      case 'teal':
        return ThemeColor.teal;
      case 'white':
        return ThemeColor.white;
      case 'blue':
        return ThemeColor.blue;
      default:
        return ThemeColor.white;
    }
  }

  String _themeColorToString(ThemeColor color) {
    switch (color) {
      case ThemeColor.red:
        return 'red';
      case ThemeColor.yellow:
        return 'yellow';
      case ThemeColor.teal:
        return 'teal';
      case ThemeColor.white:
        return 'white';
      case ThemeColor.blue:
        return 'blue';
      default:
        return 'white';
    }
  }
}

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
            ..selectedColor = 'white'; // Default
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
