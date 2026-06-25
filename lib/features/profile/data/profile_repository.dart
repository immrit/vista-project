import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../../services/http_client_factory.dart';
import '../../../security/logging_utility.dart';
import '../../../model/ProfileModel.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../services/session_manager_service_v2.dart';

class ProfileRepository {
  static String get _backendUrl => EnvConfig.apiBaseUrl;
  static Future<Map<String, dynamic>?>? _inflightSelfProfile;
  static final Map<String, Future<Map<String, dynamic>>> _inflightByUserId = {};
  static int _selfRateLimitedUntilMs = 0;
  static final Map<String, int> _rateLimitedUntilByUserId = {};

  late final Dio _dio;

  ProfileRepository() {
    // P3: shared pinned client (cert pinning + god-mode interceptors).
    _dio = createApiV1Dio(baseUrl: _backendUrl);
  }

  Future<Options> _authOptions() async {
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!sessionReady) {
      throw 'User is not logged in';
    }
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw 'User is not logged in';
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Options?> _optionalAuthOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!sessionReady) return null;
    final freshToken = await TokenStorage.getAccessToken();
    if (freshToken == null || freshToken.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $freshToken'});
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _selfRateLimitedUntilMs) {
      throw 'خطا در دریافت اطلاعات پروفایل';
    }
    final inflight = _inflightSelfProfile;
    if (inflight != null) return inflight;

    final future = _fetchProfileInternal(userId);
    _inflightSelfProfile = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightSelfProfile, future)) {
        _inflightSelfProfile = null;
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileInternal(String userId) async {
    try {
      final response = await _dio.get(
        '/me/profile',
        options: await _authOptions(),
      );

      return _normalizeProfileMap(
        Map<String, dynamic>.from(response.data as Map),
        fallbackUserId: userId,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter =
            _retryAfterSeconds(e.response?.headers.value('retry-after'));
        _selfRateLimitedUntilMs = DateTime.now()
            .add(Duration(seconds: retryAfter))
            .millisecondsSinceEpoch;
        logInfo('⚠️ Profile fetch rate-limited (429) for /me/profile');
        throw 'خطا در دریافت اطلاعات پروفایل';
      }
      logError('Fetch Profile Error', error: e);
      throw 'خطا در دریافت اطلاعات پروفایل';
    } catch (e) {
      logError('Fetch Profile Error', error: e);
      throw 'خطا در دریافت اطلاعات پروفایل';
    }
  }

  Future<Map<String, dynamic>> fetchProfileById(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw 'شناسه کاربر نامعتبر است';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownUntil = _rateLimitedUntilByUserId[normalizedUserId] ?? 0;
    if (now < cooldownUntil) {
      throw 'خطا در دریافت اطلاعات پروفایل';
    }

    final inflight = _inflightByUserId[normalizedUserId];
    if (inflight != null) return inflight;

    final future = _fetchProfileByIdInternal(normalizedUserId);
    _inflightByUserId[normalizedUserId] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightByUserId[normalizedUserId], future)) {
        _inflightByUserId.remove(normalizedUserId);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProfileByIdInternal(String userId) async {
    bool isSelf = false;
    try {
      final storedUserId = await TokenStorage.getUserId();
      isSelf = storedUserId == userId;
      final response = isSelf
          ? await _dio.get('/me/profile', options: await _authOptions())
          : await _dio.get('/profiles/$userId',
              options: await _optionalAuthOptions());

      return _normalizeProfileMap(
        Map<String, dynamic>.from(response.data as Map),
        fallbackUserId: userId,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      // If fetching another user's profile and they are not found or we don't have access,
      // return a default fallback profile instead of breaking the UI or session.
      if (!isSelf &&
          (statusCode == 401 || statusCode == 403 || statusCode == 404)) {
        logInfo(
            '⚠️ Falling back to default profile for user $userId (Status: $statusCode)');
        return {
          'id': userId,
          'username': 'کاربر حذف شده',
          'full_name': 'کاربر حذف شده',
          'avatar_url': null,
          'is_blocked': false,
        };
      }

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw data['message'] as String;
      }
      if (statusCode == 429) {
        final retryAfter =
            _retryAfterSeconds(e.response?.headers.value('retry-after'));
        final until = DateTime.now()
            .add(Duration(seconds: retryAfter))
            .millisecondsSinceEpoch;
        _rateLimitedUntilByUserId[userId] = until;
        if (isSelf) {
          _selfRateLimitedUntilMs = until;
        }
        logInfo('⚠️ Profile fetch rate-limited (429) for user $userId');
        throw 'خطا در دریافت اطلاعات پروفایل';
      }
      logError('Fetch Profile By Id Error', error: e);
      throw 'خطا در دریافت اطلاعات پروفایل';
    } catch (e) {
      logError('Fetch Profile By Id Error', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchProfileByUsername(String username) async {
    try {
      final encodedUsername = Uri.encodeComponent(username);
      final response = await _dio.get(
        '/profiles/by-username/$encodedUsername',
        options: await _optionalAuthOptions(),
      );
      return _normalizeProfileMap(
        Map<String, dynamic>.from(response.data as Map),
        fallbackUserId: '',
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw data['message'] as String;
      }
      logError('Fetch Profile By Username Error', error: e);
      throw 'Ø®Ø·Ø§ Ø¯Ø± Ø¯Ø±ÛŒØ§ÙØª Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ù¾Ø±ÙˆÙØ§ÛŒÙ„';
    } catch (e) {
      logError('Fetch Profile By Username Error', error: e);
      rethrow;
    }
  }

  Future<List<ProfileModel>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedQuery = query.trim().replaceFirst(RegExp(r'^@+'), '');
    final exactProfile = offset == 0 &&
            normalizedQuery.isNotEmpty &&
            _looksLikeUsername(normalizedQuery)
        ? await _fetchExactUsernameProfile(normalizedQuery)
        : null;

    List<ProfileModel> profiles;
    try {
      final response = await _dio.get(
        '/profiles/search',
        queryParameters: {
          'q': normalizedQuery,
          'limit': limit,
          'offset': offset
        },
        options: await _optionalAuthOptions(),
      );
      profiles = _parseProfileList(response.data);
    } on DioException catch (e) {
      final shouldRetryAsPrefix = e.response?.statusCode == 500 &&
          normalizedQuery.isNotEmpty &&
          !normalizedQuery.endsWith('*');
      if (!shouldRetryAsPrefix) {
        profiles = const [];
      } else {
        try {
          final response = await _dio.get(
            '/profiles/search',
            queryParameters: {
              'q': '$normalizedQuery*',
              'limit': limit,
              'offset': offset,
            },
            options: await _optionalAuthOptions(),
          );
          profiles = _parseProfileList(response.data);
        } catch (_) {
          profiles = const [];
        }
      }
    } catch (_) {
      profiles = const [];
    }

    if (exactProfile == null) {
      return profiles;
    }

    final withoutDuplicate =
        profiles.where((profile) => profile.id != exactProfile.id).toList();
    return [exactProfile, ...withoutDuplicate];
  }

  Future<ProfileModel?> _fetchExactUsernameProfile(String username) async {
    try {
      final data = await fetchProfileByUsername(username.toLowerCase());
      return ProfileModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeUsername(String query) {
    return RegExp(r'^[A-Za-z0-9_.]{2,32}$').hasMatch(query);
  }

  static String _trimmed(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNonEmpty(
    Iterable<dynamic> values, {
    required String fallback,
  }) {
    for (final value in values) {
      final trimmed = _trimmed(value);
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  static bool _boolValue(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  Map<String, dynamic> _normalizeProfileMap(
    Map<String, dynamic> data, {
    required String fallbackUserId,
  }) {
    data['id'] = _firstNonEmpty(
      [data['id'], data['user_id'], fallbackUserId],
      fallback: fallbackUserId,
    );
    data['followers_count'] =
        data['followers_count'] ?? data['follower_count'] ?? 0;
    data['following_count'] = data['following_count'] ?? 0;
    data['posts_count'] = data['posts_count'] ?? data['post_count'] ?? 0;
    data['username'] = _firstNonEmpty(
      [data['username'], data['full_name']],
      fallback: 'user',
    );
    data['is_followed'] = data['is_followed'] ??
        (data['follow_status']?.toString().toLowerCase() == 'following');
    data['follow_status'] ??= 'none';
    data['email'] ??= '';
    data['phone_number'] ??= '';
    data['gender'] ??= '';
    data['marital_status'] ??= '';
    data['show_email'] = _boolValue(data['show_email']);
    data['show_birth_date'] = _boolValue(data['show_birth_date']);
    data['show_gender'] = _boolValue(data['show_gender']);
    data['show_marital_status'] = _boolValue(data['show_marital_status']);
    data['role'] ??= 'normal';
    return data;
  }

  Future<Map<String, dynamic>> updateProfile(
      String userId, Map<String, dynamic> updatedData) async {
    try {
      final sanitizedData = Map<String, dynamic>.from(updatedData);
      sanitizedData.removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return !['bio', 'email', 'avatar_url'].contains(key);
        }
        return false;
      });

      if (sanitizedData.isEmpty) {
        final current = await fetchProfile(userId);
        return current ?? <String, dynamic>{};
      }

      final response = await _dio.post(
        '/me/profile/update',
        data: sanitizedData,
        options: await _authOptions(),
      );

      return _normalizeProfileMap(
        Map<String, dynamic>.from(response.data as Map),
        fallbackUserId: userId,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw data['message'] as String;
      }
      logError('Update Profile Error', error: e);
      throw 'خطا در بروزرسانی پروفایل';
    } catch (e) {
      logError('Update Profile Error', error: e);
      rethrow;
    }
  }

  Future<String> follow(String targetUserId) async {
    final response = await _dio.post(
      '/me/follow',
      data: {'target_user_id': targetUserId},
      options: await _authOptions(),
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['status']?.toString() ?? 'none';
  }

  Future<void> unfollow(String targetUserId) async {
    await _dio.post(
      '/me/unfollow',
      data: {'target_user_id': targetUserId},
      options: await _authOptions(),
    );
  }

  Future<void> reportProfile({
    required String userId,
    required String reason,
    String? additionalDetails,
  }) async {
    await _dio.post(
      '/profiles/report',
      data: {
        'profile_id': userId,
        'reason': reason,
        if (additionalDetails != null && additionalDetails.isNotEmpty)
          'additional_details': additionalDetails,
      },
      options: await _authOptions(),
    );
  }

  Future<List<ProfileModel>> fetchFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/profiles/followers/$userId',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _optionalAuthOptions(),
    );
    return _parseProfileList(response.data);
  }

  Future<List<ProfileModel>> fetchFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/profiles/following/$userId',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _optionalAuthOptions(),
    );
    return _parseProfileList(response.data);
  }

  List<ProfileModel> _parseProfileList(dynamic data) {
    if (data is! Map) return const [];
    final map = Map<String, dynamic>.from(data);
    final profiles = map['profiles'] as List? ?? const [];
    final parsed = <ProfileModel>[];
    for (final item in profiles.whereType<Map>()) {
      try {
        parsed.add(
          ProfileModel.fromMap(
            _normalizeProfileMap(
              Map<String, dynamic>.from(item),
              fallbackUserId: '',
            ),
          ),
        );
      } catch (_) {
        // Skip malformed search entries so one bad profile cannot break search.
      }
    }
    return parsed;
  }

  Future<void> requestVerification({
    required String category,
    required String documentUrl,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '/me/verify',
        data: {
          'category': category,
          'document_url': documentUrl,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
        },
        options: await _authOptions(),
      );
    } catch (e) {
      logError('Request Verification Error', error: e);
      throw 'خطا در ثبت درخواست تایید هویت';
    }
  }

  int _retryAfterSeconds(String? retryAfterHeader) {
    final parsed = int.tryParse(retryAfterHeader ?? '');
    if (parsed == null || parsed <= 0) return 60;
    return parsed.clamp(10, 180);
  }
}
