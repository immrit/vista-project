import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import '../../../DB/settings_cache_service.dart';
import '../../../security/logging_utility.dart';
import '../../auth/providers/auth_controller.dart';

/// Canonical privacy/security settings are stored in `user_settings` on frontend.
/// Now synced to the Go backend `privacy_settings` via `/v1/me/privacy`.
class PrivacySettingsRepository {
  final SettingsCacheService _cache = SettingsCacheService();
  late final Dio _dio;

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl ?? 'http://10.0.2.2:8080';

  PrivacySettingsRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getMergedPrivacySettings(String userId) async {
    // Try to get from remote first if it's the current user
    try {
      final currentUserId = await TokenStorage.getUserId();
      if (userId == currentUserId) {
        final response = await _dio.get(
          '/me/privacy',
          options: await _authOptions(),
        );
        final remoteSettings =
            Map<String, dynamic>.from(response.data as Map? ?? {});
        // Cache the remote settings
        await _cache.updateUserSettings(userId, remoteSettings);
        return remoteSettings;
      }
    } catch (e) {
      logInfo(
          '⚠️ Failed fetching remote privacy settings, falling back to cache: $e');
    }

    // Fallback to cache
    final userSettings = await _cache.getUserSettings(userId) ?? {};
    final privacySettings = await _cache.getPrivacySettings(userId) ?? {};

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

    // Sync to backend
    try {
      await _dio.post(
        '/me/privacy',
        data: nextUser, // send the full updated settings
        options: await _authOptions(),
      );
    } catch (e) {
      logInfo('⚠️ Failed syncing privacy settings to Go backend: $e');
    }
  }
}
