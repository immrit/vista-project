import '../security/logging_utility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات وویس پیام‌ها
class VoiceSettings {
  final bool autoDownloadEnabled;
  final String autoDownloadMode; // 'always', 'wifi', 'never'
  final bool cacheEnabled;
  final int maxCacheSizeMB;
  final int cacheExpirationDays;

  const VoiceSettings({
    this.autoDownloadEnabled = true,
    this.autoDownloadMode = 'wifi',
    this.cacheEnabled = true,
    this.maxCacheSizeMB = 100,
    this.cacheExpirationDays = 7,
  });

  VoiceSettings copyWith({
    bool? autoDownloadEnabled,
    String? autoDownloadMode,
    bool? cacheEnabled,
    int? maxCacheSizeMB,
    int? cacheExpirationDays,
  }) {
    return VoiceSettings(
      autoDownloadEnabled: autoDownloadEnabled ?? this.autoDownloadEnabled,
      autoDownloadMode: autoDownloadMode ?? this.autoDownloadMode,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      maxCacheSizeMB: maxCacheSizeMB ?? this.maxCacheSizeMB,
      cacheExpirationDays: cacheExpirationDays ?? this.cacheExpirationDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoDownloadEnabled': autoDownloadEnabled,
      'autoDownloadMode': autoDownloadMode,
      'cacheEnabled': cacheEnabled,
      'maxCacheSizeMB': maxCacheSizeMB,
      'cacheExpirationDays': cacheExpirationDays,
    };
  }

  factory VoiceSettings.fromMap(Map<String, dynamic> map) {
    return VoiceSettings(
      autoDownloadEnabled: map['autoDownloadEnabled'] ?? true,
      autoDownloadMode: map['autoDownloadMode'] ?? 'wifi',
      cacheEnabled: map['cacheEnabled'] ?? true,
      maxCacheSizeMB: map['maxCacheSizeMB'] ?? 100,
      cacheExpirationDays: map['cacheExpirationDays'] ?? 7,
    );
  }

  String get autoDownloadLabel {
    switch (autoDownloadMode) {
      case 'always':
        return 'همیشه';
      case 'wifi':
        return 'فقط Wi-Fi';
      case 'never':
        return 'هرگز';
      default:
        return 'نامشخص';
    }
  }

  /// بررسی اینکه آیا باید وویس خودکار دانلود شود یا نه
  bool shouldAutoDownload({bool isWifi = false}) {
    if (!autoDownloadEnabled) return false;

    switch (autoDownloadMode) {
      case 'always':
        return true;
      case 'wifi':
        return isWifi;
      case 'never':
        return false;
      default:
        return false;
    }
  }
}

/// Provider برای مدیریت تنظیمات وویس
class VoiceSettingsNotifier extends StateNotifier<VoiceSettings> {
  static const String _key = 'voice_settings';

  VoiceSettingsNotifier() : super(const VoiceSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_key);

      if (settingsJson != null) {
        final settingsMap =
            Map<String, dynamic>.from(Uri.splitQueryString(settingsJson));
        state = VoiceSettings.fromMap(settingsMap);
      }
    } catch (e) {
      logInfo('❌ خطا در بارگذاری تنظیمات وویس: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsMap = state.toMap();
      final settingsJson = Uri(
          queryParameters: settingsMap
              .map((key, value) => MapEntry(key, value.toString()))).query;

      await prefs.setString(_key, settingsJson);
    } catch (e) {
      logInfo('❌ خطا در ذخیره تنظیمات وویس: $e');
    }
  }

  Future<void> setAutoDownloadEnabled(bool enabled) async {
    state = state.copyWith(autoDownloadEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setAutoDownloadMode(String mode) async {
    state = state.copyWith(autoDownloadMode: mode);
    await _saveSettings();
  }

  Future<void> setCacheEnabled(bool enabled) async {
    state = state.copyWith(cacheEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setMaxCacheSize(int sizeMB) async {
    state = state.copyWith(maxCacheSizeMB: sizeMB);
    await _saveSettings();
  }

  Future<void> setCacheExpirationDays(int days) async {
    state = state.copyWith(cacheExpirationDays: days);
    await _saveSettings();
  }
}

/// Provider اصلی برای تنظیمات وویس
final voiceSettingsProvider =
    StateNotifierProvider<VoiceSettingsNotifier, VoiceSettings>((ref) {
  return VoiceSettingsNotifier();
});

/// Provider برای بررسی وضعیت اتصال شبکه
final networkStatusProvider = StateProvider<bool>((ref) {
  return true; // به صورت پیش‌فرض Wi-Fi فرض می‌شود
});

/// Provider برای بررسی اینکه آیا باید وویس خودکار دانلود شود
final shouldAutoDownloadVoiceProvider = Provider<bool>((ref) {
  final voiceSettings = ref.watch(voiceSettingsProvider);
  final isWifi = ref.watch(networkStatusProvider);

  return voiceSettings.shouldAutoDownload(isWifi: isWifi);
});
