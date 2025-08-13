import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  return createTheme(color, brightness);
});

// Notifier برای مدیریت رنگ انتخاب شده
class SelectedColorNotifier extends StateNotifier<ThemeColor> {
  SelectedColorNotifier() : super(ThemeColor.blue) {
    _loadFromHive();
  }

  void _loadFromHive() async {
    final box = Hive.box('settings');
    final colorName = box.get('selectedColor', defaultValue: 'blue');
    state = _parseThemeColor(colorName);
  }

  void updateColor(ThemeColor color) {
    state = color;
    _saveToHive();
  }

  void _saveToHive() async {
    final box = Hive.box('settings');
    await box.put('selectedColor', _themeColorToString(state));
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
      default:
        return ThemeColor.blue;
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
    }
  }
}

// Notifier برای مدیریت brightness
class BrightnessNotifier extends StateNotifier<Brightness> {
  BrightnessNotifier() : super(Brightness.light) {
    _loadFromHive();
  }

  void _loadFromHive() async {
    final box = Hive.box('settings');
    final isDark = box.get('isDark', defaultValue: false);
    state = isDark ? Brightness.dark : Brightness.light;
  }

  void updateBrightness(Brightness brightness) {
    state = brightness;
    _saveToHive();
  }

  void toggleBrightness() {
    state = state == Brightness.light ? Brightness.dark : Brightness.light;
    _saveToHive();
  }

  void _saveToHive() async {
    final box = Hive.box('settings');
    await box.put('isDark', state == Brightness.dark);
  }
}
