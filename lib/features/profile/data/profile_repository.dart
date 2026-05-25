import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../../security/logging_utility.dart';
import '../../../model/ProfileModel.dart';
import '../../auth/providers/auth_controller.dart';

class ProfileRepository {
  static String get _backendUrl => EnvConfig.apiBaseUrl;
  static Future<Map<String, dynamic>?>? _inflightSelfProfile;
  static final Map<String, Future<Map<String, dynamic>>> _inflightByUserId = {};

  late final Dio _dio;

  ProfileRepository() {
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
      throw 'User is not logged in';
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Options?> _optionalAuthOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
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
      if (!isSelf && (statusCode == 401 || statusCode == 403 || statusCode == 404)) {
        logInfo('⚠️ Falling back to default profile for user $userId (Status: $statusCode)');
        return {
          'id': userId,
          'username': 'کاربر ناشناس',
          'full_name': 'کاربر ناشناس',
          'avatar_url': null,
          'is_blocked': false,
        };
      }

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw data['message'] as String;
      }
      if (statusCode == 429) {
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
    final response = await _dio.get(
      '/profiles/search',
      queryParameters: {'q': query, 'limit': limit, 'offset': offset},
      options: await _optionalAuthOptions(),
    );
    return _parseProfileList(response.data);
  }

  Map<String, dynamic> _normalizeProfileMap(
    Map<String, dynamic> data, {
    required String fallbackUserId,
  }) {
    data['id'] = data['id'] ?? data['user_id'] ?? fallbackUserId;
    data['followers_count'] =
        data['followers_count'] ?? data['follower_count'] ?? 0;
    data['following_count'] = data['following_count'] ?? 0;
    data['posts_count'] = data['posts_count'] ?? data['post_count'] ?? 0;
    data['username'] = data['username'] ?? data['full_name'] ?? 'user';
    data['is_followed'] = data['is_followed'] ??
        (data['follow_status']?.toString().toLowerCase() == 'following');
    data['follow_status'] ??= 'none';
    data['email'] ??= '';
    data['phone_number'] ??= '';
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

      final data = Map<String, dynamic>.from(response.data as Map);
      data['id'] = data['user_id'] ?? userId;
      return data;
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
    final map = Map<String, dynamic>.from(data as Map);
    final profiles = map['profiles'] as List? ?? const [];
    return profiles
        .whereType<Map>()
        .map((item) => ProfileModel.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
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
}
