import 'package:dio/dio.dart';

import 'package:Vista/utils/env_config.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import '../models/nearby_models.dart';

/// Thrown for expected, user-facing nearby errors so the UI can branch on them.
class NearbyException implements Exception {
  final String code; // e.g. location_required, feature_disabled, daily_like_limit
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
    final ready = await SessionManagerServiceV2.instance.ensureValidAuthSession();
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

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await _dio.post('/location', data: {'lat': lat, 'lng': lng}, options: await _authOptions());
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<void> disable() async {
    await _dio.delete('/location', options: await _authOptions());
  }

  Future<NearbyPreferences> getPreferences() async {
    final resp = await _dio.get('/preferences', options: await _authOptions());
    return NearbyPreferences.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<NearbyPreferences> updatePreferences(NearbyPreferences prefs) async {
    final resp = await _dio.put('/preferences', data: prefs.toJson(), options: await _authOptions());
    return NearbyPreferences.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<NearbyCandidate>> discover({int limit = 20}) async {
    try {
      final resp = await _dio.get('/discover',
          queryParameters: {'limit': limit}, options: await _authOptions());
      final list = (resp.data as Map<String, dynamic>)['candidates'] as List<dynamic>? ?? [];
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
      final list = (resp.data as Map<String, dynamic>)['candidates'] as List<dynamic>? ?? [];
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
          data: {'target_id': targetId, 'action': action}, options: await _authOptions());
      return NearbyLikeResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NearbyException(_codeOf(e));
    }
  }

  Future<List<NearbyMatch>> matches() async {
    final resp = await _dio.get('/matches', options: await _authOptions());
    final list = (resp.data as Map<String, dynamic>)['matches'] as List<dynamic>? ?? [];
    return list.map((e) => NearbyMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> unmatch(String matchId) async {
    await _dio.delete('/matches/$matchId', options: await _authOptions());
  }

  /// Ensures a conversation with a matched user; returns its conversation id.
  Future<String> openChat(String matchId) async {
    final resp = await _dio.post('/matches/$matchId/chat', options: await _authOptions());
    return (resp.data as Map<String, dynamic>)['conversation_id'] as String? ?? '';
  }
}
