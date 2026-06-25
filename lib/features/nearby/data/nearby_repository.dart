import 'package:dio/dio.dart';

import 'package:Vista/utils/env_config.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import '../models/nearby_models.dart';

/// Thrown for expected, user-facing nearby errors so the UI can branch on them.
class NearbyException implements Exception {
  final String
      code; // e.g. location_required, feature_disabled, daily_like_limit
  const NearbyException(this.code);
  @override
  String toString() => code;
}

class NearbyRepository {
  static String get _baseUrl => EnvConfig.apiBaseUrl;

  late final Dio _dio;

  NearbyRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_baseUrl/v1/nearby',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Options> _authOptions() async {
    final ready =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!ready) throw 'User is not logged in';
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) throw 'User is not logged in';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String _codeOf(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return 'network_error';
  }

  Future<void> updateLocation(
    double lat,
    double lng, {
    String? cityName,
    String? provinceName,
  }) async {
    try {
      final body = <String, dynamic>{'lat': lat, 'lng': lng};
      if (cityName != null && cityName.isNotEmpty) {
        body['city_name'] = cityName;
      }
      if (provinceName != null && provinceName.isNotEmpty) {
        body['province_name'] = provinceName;
      }
      await _dio.post('/location', data: body, options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<void> disable() async {
    try {
      await _dio.delete('/location', options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<NearbyPreferences> getPreferences() async {
    try {
      final resp =
          await _dio.get('/preferences', options: await _authOptions());
      return NearbyPreferences.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<NearbyPreferences> updatePreferences(NearbyPreferences prefs) async {
    try {
      final resp = await _dio.put('/preferences',
          data: prefs.toJson(), options: await _authOptions());
      return NearbyPreferences.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<List<NearbyCandidate>> discover({int limit = 20, int offset = 0}) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (offset > 0) params['offset'] = offset;
      final resp = await _dio.get('/discover',
          queryParameters: params, options: await _authOptions());
      final list =
          (resp.data as Map<String, dynamic>)['candidates'] as List<dynamic>? ??
              [];
      return list
          .map((e) => NearbyCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<List<NearbyCandidate>> discoverRandomOnline({int limit = 20}) async {
    try {
      final resp = await _dio.get('/random-online',
          queryParameters: {'limit': limit}, options: await _authOptions());
      final list =
          (resp.data as Map<String, dynamic>)['candidates'] as List<dynamic>? ??
              [];
      return list
          .map((e) => NearbyCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<NearbyLikeResult> like(String targetId, String action) async {
    try {
      final resp = await _dio.post('/like',
          data: {'target_id': targetId, 'action': action},
          options: await _authOptions());
      return NearbyLikeResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<List<NearbyMatch>> matches() async {
    try {
      final resp = await _dio.get('/matches', options: await _authOptions());
      final list =
          (resp.data as Map<String, dynamic>)['matches'] as List<dynamic>? ??
              [];
      return list
          .map((e) => NearbyMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<void> unmatch(String matchId) async {
    try {
      await _dio.delete('/matches/$matchId', options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  /// Ensures a conversation with a matched user; returns its conversation id.
  Future<String> openChat(String matchId) async {
    try {
      final resp = await _dio.post('/matches/$matchId/chat',
          options: await _authOptions());
      return (resp.data as Map<String, dynamic>)['conversation_id']
              as String? ??
          '';
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  /// Rewinds the last swipe toward [targetId] (removes like/pass + any match).
  Future<void> undoLike(String targetId) async {
    try {
      await _dio.post('/undo',
          data: {'target_id': targetId}, options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  /// Returns users who liked the viewer (and the pending count).
  Future<NearbyReceivedLikes> likesReceived({int limit = 50}) async {
    try {
      final resp = await _dio.get('/likes-received',
          queryParameters: {'limit': limit}, options: await _authOptions());
      final data = resp.data as Map<String, dynamic>;
      final list = data['likes'] as List<dynamic>? ?? [];
      return NearbyReceivedLikes(
        count: (data['count'] as num?)?.toInt() ?? list.length,
        likes: list
            .map((e) => NearbyReceivedLike.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  /// Reports a user (auto-passes them out of the deck).
  Future<void> report(String targetId, String reason) async {
    try {
      await _dio.post('/report',
          data: {'target_id': targetId, 'reason': reason},
          options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }
}
