import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart' show Database, StoreRef;
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  Database? _database;
  final StoreRef<String, String> _store = StoreRef<String, String>.main();

  SelectedColorNotifier() : super(ThemeColor.white) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      String dbPath = 'settings.db';
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = '${appDir.path}/settings.db';
      }
      _database = await databaseFactoryIo.openDatabase(dbPath);
      _loadFromSembast();
    } catch (e) {
      debugPrint('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  void _loadFromSembast() async {
    if (_database == null) return;
    try {
      final colorName =
          await _store.record('selectedColor').get(_database!) ?? 'white';
      state = _parseThemeColor(colorName);
    } catch (e) {
      debugPrint('خطا در بارگذاری رنگ: $e');
    }
  }

  void updateColor(ThemeColor color) {
    state = color;
    _saveToSembast();
  }

  void _saveToSembast() async {
    if (_database == null) return;
    try {
      await _store
          .record('selectedColor')
          .put(_database!, _themeColorToString(state));
    } catch (e) {
      debugPrint('خطا در ذخیره رنگ: $e');
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
    }
  }
}

// Notifier برای مدیریت brightness
class BrightnessNotifier extends StateNotifier<Brightness> {
  Database? _database;
  final StoreRef<String, bool> _store = StoreRef<String, bool>.main();

  BrightnessNotifier() : super(Brightness.light) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      String dbPath = 'settings.db';
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = '${appDir.path}/settings.db';
      }
      _database = await databaseFactoryIo.openDatabase(dbPath);
      _loadFromSembast();
    } catch (e) {
      debugPrint('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  void _loadFromSembast() async {
    if (_database == null) return;
    try {
      final isDark = await _store.record('isDark').get(_database!) ?? false;
      state = isDark ? Brightness.dark : Brightness.light;
    } catch (e) {
      debugPrint('خطا در بارگذاری brightness: $e');
    }
  }

  void updateBrightness(Brightness brightness) {
    state = brightness;
    _saveToSembast();
  }

  void toggleBrightness() {
    state = state == Brightness.light ? Brightness.dark : Brightness.light;
    _saveToSembast();
  }

  void _saveToSembast() async {
    if (_database == null) return;
    try {
      await _store.record('isDark').put(_database!, state == Brightness.dark);
    } catch (e) {
      debugPrint('خطا در ذخیره brightness: $e');
    }
  }
}
