import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/services/http_client_factory.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import '../models/services_hub_model.dart';

class ServicesHubRepository {
  static String get _baseUrl => EnvConfig.apiBaseUrl;

  late final Dio _dio;

  ServicesHubRepository() {
    // P3: shared pinned client (cert pinning + god-mode interceptors).
    _dio = createApiV1Dio(baseUrl: _baseUrl);
  }

  Future<Options> _authOptions() async {
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!sessionReady) throw 'User is not logged in';
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) throw 'User is not logged in';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<ServicesHubData> getHub() async {
    final resp = await _dio.get('/services-hub');
    return ServicesHubData.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Requests a one-time game-SSO ticket for the current user. The ticket is
  /// handed to the web game section inside a webview, which exchanges it for a
  /// scoped (game-only) session. Returns the opaque ticket string.
  Future<String> createGameSsoTicket() async {
    final options = await _authOptions();
    final resp = await _dio.post('/game-sso/ticket', options: options);
    final data = resp.data as Map<String, dynamic>;
    final ticket = data['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) {
      throw 'Failed to create game session';
    }
    return ticket;
  }

  Future<List<ContactVistaUser>> findContacts(List<String> phones) async {
    final options = await _authOptions();
    final resp = await _dio.post(
      '/services-hub/contacts',
      data: {'phone_numbers': phones},
      options: options,
    );
    final data = resp.data as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>? ?? [];
    return users
        .map((e) => ContactVistaUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> getTopGroupsRaw() async {
    final resp = await _dio.get('/services-hub/top-groups');
    final data = resp.data as Map<String, dynamic>;
    return data['groups'] as List<dynamic>? ?? [];
  }
}
