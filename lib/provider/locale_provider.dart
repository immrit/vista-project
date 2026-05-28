import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  Isar? _isar;

  // Default to Persian ('fa', 'IR')
  LocaleNotifier() : super(const Locale('fa', 'IR')) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadLocale();
    } catch (e) {
      debugPrint('Error initializing locale from Isar: $e');
    }
  }

  Future<void> _loadLocale() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null && settings.languageCode != null) {
        state = _localeFromCode(settings.languageCode!);
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }

  Future<void> setLocale(String languageCode) async {
    state = _localeFromCode(languageCode);
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..languageCode = languageCode;
        } else {
          settings.languageCode = languageCode;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  Locale _localeFromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en', 'US');
      case 'ar':
        return const Locale('ar', 'SA');
      case 'fa':
      default:
        return const Locale('fa', 'IR');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
