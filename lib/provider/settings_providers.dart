import '../security/logging_utility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../DB/settings_cache_service.dart';
import '../main.dart';

/// Provider برای تنظیمات کاربر با قابلیت آفلاین
final userSettingsProvider = StateNotifierProvider.family<UserSettingsNotifier,
    AsyncValue<Map<String, dynamic>?>, String>((ref, userId) {
  return UserSettingsNotifier(userId);
});

/// Provider برای تنظیمات اپلیکیشن با قابلیت آفلاین
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier,
    AsyncValue<Map<String, dynamic>>>((ref) {
  return AppSettingsNotifier();
});

/// Provider برای تنظیمات حریم خصوصی با قابلیت آفلاین
final privacySettingsProvider = StateNotifierProvider.family<
    PrivacySettingsNotifier,
    AsyncValue<Map<String, dynamic>?>,
    String>((ref, userId) {
  return PrivacySettingsNotifier(userId);
});

/// Provider برای تنظیمات اعلان‌ها با قابلیت آفلاین
final notificationSettingsProvider = StateNotifierProvider.family<
    NotificationSettingsNotifier,
    AsyncValue<Map<String, dynamic>?>,
    String>((ref, userId) {
  return NotificationSettingsNotifier(userId);
});

/// Provider برای تنظیمات کاربر خاص (برای استفاده در ProfileScreen)
final userSettingsByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final settingsNotifier = ref.read(userSettingsProvider(userId).notifier);
  return await settingsNotifier.getSettings();
});

/// Notifier برای مدیریت تنظیمات کاربر
class UserSettingsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final String userId;
  final SettingsCacheService _settingsCache = SettingsCacheService();

  UserSettingsNotifier(this.userId) : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _settingsCache.getUserSettings(userId);
      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      return await _settingsCache.getUserSettings(userId);
    } catch (e) {
      logInfo('⚠️ Failed to get user settings: $e');
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsCache.updateUserSettings(userId, settings);

      // به‌روزرسانی در سرور (اگر اتصال وجود دارد)
      try {
        await supabase.from('user_settings').upsert({
          'user_id': userId,
          ...settings,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        logInfo('⚠️ Failed to sync settings to server: $e');
        // در صورت خطا، تنظیمات در کش باقی می‌ماند
      }

      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }
}

/// Notifier برای مدیریت تنظیمات اپلیکیشن
class AppSettingsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final SettingsCacheService _settingsCache = SettingsCacheService();

  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _settingsCache.getAppSettings();
      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      return await _settingsCache.getAppSettings();
    } catch (e) {
      logInfo('⚠️ Failed to get app settings: $e');
      return {};
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsCache.updateAppSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }
}

/// Notifier برای مدیریت تنظیمات حریم خصوصی
class PrivacySettingsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final String userId;
  final SettingsCacheService _settingsCache = SettingsCacheService();

  PrivacySettingsNotifier(this.userId) : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _settingsCache.getPrivacySettings(userId);
      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      return await _settingsCache.getPrivacySettings(userId);
    } catch (e) {
      logInfo('⚠️ Failed to get privacy settings: $e');
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsCache.updatePrivacySettings(userId, settings);

      // به‌روزرسانی در سرور (اگر اتصال وجود دارد)
      try {
        await supabase.from('privacy_settings').upsert({
          'user_id': userId,
          ...settings,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        logInfo('⚠️ Failed to sync privacy settings to server: $e');
        // در صورت خطا، تنظیمات در کش باقی می‌ماند
      }

      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }
}

/// Notifier برای مدیریت تنظیمات اعلان‌ها
class NotificationSettingsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final String userId;
  final SettingsCacheService _settingsCache = SettingsCacheService();

  NotificationSettingsNotifier(this.userId)
      : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _settingsCache.getNotificationSettings(userId);
      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      return await _settingsCache.getNotificationSettings(userId);
    } catch (e) {
      logInfo('⚠️ Failed to get notification settings: $e');
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsCache.updateNotificationSettings(userId, settings);

      // به‌روزرسانی در سرور (اگر اتصال وجود دارد)
      try {
        await supabase.from('notification_settings').upsert({
          'user_id': userId,
          ...settings,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        logInfo('⚠️ Failed to sync notification settings to server: $e');
        // در صورت خطا، تنظیمات در کش باقی می‌ماند
      }

      state = AsyncValue.data(settings);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }
}

/// Provider برای آمار کش تنظیمات
final settingsCacheStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final settingsCache = SettingsCacheService();
  return settingsCache.getCacheStats();
});

/// Provider برای پاک کردن کش تنظیمات
final clearSettingsCacheProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final settingsCache = SettingsCacheService();
  await settingsCache.clearUserCache(userId);
});

/// Provider برای مقداردهی اولیه کش تنظیمات
final initializeSettingsCacheProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final settingsCache = SettingsCacheService();
  await settingsCache.initializeUserCache(userId);
});




