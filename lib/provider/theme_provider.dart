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
  final highContrast = accessibility['high_contrast'] as bool? ?? false;
  final colorBlindMode =
      (accessibility['color_blind_mode'] as String? ?? 'none').toLowerCase();

  // Basic Theme
  ThemeData theme = brightness == Brightness.dark
      ? VistaThemes.darkTheme
      : VistaThemes.lightTheme;

  final fontScale = largeText ? 1.12 : 1.0;
  var textTheme = theme.textTheme.apply(fontSizeFactor: fontScale);
  if (boldText) {
    textTheme = _withBoldText(textTheme);
  }

  final colorScheme = highContrast
      ? _withHighContrastColors(theme.colorScheme, brightness)
      : theme.colorScheme;

  return theme.copyWith(
    colorScheme: colorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    dividerColor: highContrast
        ? (brightness == Brightness.dark ? Colors.white70 : Colors.black87)
        : theme.dividerColor,
    extensions: [
      ...theme.extensions.values,
      _ColorBlindThemeExtension(mode: colorBlindMode),
    ],
  );
});

final colorBlindModeProvider = Provider<String>((ref) {
  final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
  final accessibility =
      appSettingsAsync.value?['accessibility'] as Map<String, dynamic>? ?? {};
  return (accessibility['color_blind_mode'] as String? ?? 'none').toLowerCase();
});

final colorBlindMatrixProvider = Provider<List<double>?>((ref) {
  final mode = ref.watch(colorBlindModeProvider);
  return _matrixForColorBlindMode(mode);
});

TextTheme _withBoldText(TextTheme textTheme) {
  TextStyle? bold(TextStyle? style) =>
      style?.copyWith(fontWeight: FontWeight.w700);

  return textTheme.copyWith(
    displayLarge: bold(textTheme.displayLarge),
    displayMedium: bold(textTheme.displayMedium),
    displaySmall: bold(textTheme.displaySmall),
    headlineLarge: bold(textTheme.headlineLarge),
    headlineMedium: bold(textTheme.headlineMedium),
    headlineSmall: bold(textTheme.headlineSmall),
    titleLarge: bold(textTheme.titleLarge),
    titleMedium: bold(textTheme.titleMedium),
    titleSmall: bold(textTheme.titleSmall),
    bodyLarge: bold(textTheme.bodyLarge),
    bodyMedium: bold(textTheme.bodyMedium),
    bodySmall: bold(textTheme.bodySmall),
    labelLarge: bold(textTheme.labelLarge),
    labelMedium: bold(textTheme.labelMedium),
    labelSmall: bold(textTheme.labelSmall),
  );
}

ColorScheme _withHighContrastColors(ColorScheme scheme, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return scheme.copyWith(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Colors.white,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    );
  }

  return scheme.copyWith(
    primary: Colors.black,
    onPrimary: Colors.white,
    secondary: Colors.black,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
  );
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

class _ColorBlindThemeExtension
    extends ThemeExtension<_ColorBlindThemeExtension> {
  final String mode;

  const _ColorBlindThemeExtension({required this.mode});

  @override
  ThemeExtension<_ColorBlindThemeExtension> copyWith({String? mode}) {
    return _ColorBlindThemeExtension(mode: mode ?? this.mode);
  }

  @override
  ThemeExtension<_ColorBlindThemeExtension> lerp(
      covariant ThemeExtension<_ColorBlindThemeExtension>? other, double t) {
    if (other is! _ColorBlindThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

List<double>? _matrixForColorBlindMode(String mode) {
  switch (mode) {
    case 'protanopia':
      return const [
        0.567,
        0.433,
        0.0,
        0.0,
        0.0,
        0.558,
        0.442,
        0.0,
        0.0,
        0.0,
        0.0,
        0.242,
        0.758,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
    case 'deuteranopia':
      return const [
        0.625,
        0.375,
        0.0,
        0.0,
        0.0,
        0.7,
        0.3,
        0.0,
        0.0,
        0.0,
        0.0,
        0.3,
        0.7,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
    case 'tritanopia':
      return const [
        0.95,
        0.05,
        0.0,
        0.0,
        0.0,
        0.0,
        0.433,
        0.567,
        0.0,
        0.0,
        0.0,
        0.475,
        0.525,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
      ];
    default:
      return null;
  }
}

// Deprecated providers kept to prevent downstream breakages if any file imports them unexpectedly,
// though we aim to remove usages. For stricter cleanup, I'm removing selectedColorProvider.
// If something breaks, we will fix the consumer.
