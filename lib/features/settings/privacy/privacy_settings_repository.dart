import '../../../DB/settings_cache_service.dart';
import '../../../security/logging_utility.dart';
import '../../../utils/const.dart';

/// Canonical privacy/security settings are stored in `user_settings`.
/// For backward compatibility, some keys are also mirrored into `privacy_settings`.
class PrivacySettingsRepository {
  final SettingsCacheService _cache = SettingsCacheService();

  static const Set<String> _mirrorToPrivacySettingsKeys = {
    'is_private',
    'group_add_privacy',
  };

  Future<Map<String, dynamic>> getMergedPrivacySettings(String userId) async {
    final userSettings = await _cache.getUserSettings(userId) ?? {};
    final privacySettings = await _cache.getPrivacySettings(userId) ?? {};

    // `user_settings` is canonical, so it overrides any overlapping keys.
    return {
      ...privacySettings,
      ...userSettings,
    };
  }

  Future<void> updateSetting(String userId, String key, dynamic value) async {
    await updateSettings(userId, {key: value});
  }

  Future<void> updateSettings(String userId, Map<String, dynamic> patch) async {
    // Update cache first (offline-first UX).
    final currentUser = await _cache.getUserSettings(userId) ?? {};
    final nextUser = {...currentUser, ...patch};
    await _cache.updateUserSettings(userId, nextUser);

    // Mirror subset to privacy cache (for consumers still reading privacy_settings).
    final mirrorPatch = <String, dynamic>{};
    for (final entry in patch.entries) {
      if (_mirrorToPrivacySettingsKeys.contains(entry.key)) {
        mirrorPatch[entry.key] = entry.value;
      }
    }
    if (mirrorPatch.isNotEmpty) {
      final currentPrivacy = await _cache.getPrivacySettings(userId) ?? {};
      final nextPrivacy = {...currentPrivacy, ...mirrorPatch};
      await _cache.updatePrivacySettings(userId, nextPrivacy);
    }

    // Best-effort remote sync.
    try {
      await supabase.from('user_settings').upsert({
        'user_id': userId,
        ...patch,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      logInfo('⚠️ Failed syncing user_settings: $e');
    }

    if (mirrorPatch.isNotEmpty) {
      try {
        await supabase.from('privacy_settings').upsert({
          'user_id': userId,
          ...mirrorPatch,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        logInfo('⚠️ Failed syncing privacy_settings mirror: $e');
      }
    }
  }
}
