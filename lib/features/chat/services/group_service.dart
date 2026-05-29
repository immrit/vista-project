import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../auth/providers/auth_controller.dart';
import '../models/group_member_item.dart';
import '../models/group_user_item.dart';
import '../../../services/http_client_factory.dart';

class GroupService {
  late final Dio _dio;

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  GroupService() {
    _dio = createPinnedDioClient(
      baseUrl: '$_backendUrl/v1',
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<GroupUserItem>> getInteractionUsers({int limit = 100}) async {
    final response = await _dio.get(
      '/chat/conversations',
      queryParameters: {'limit': limit},
      options: await _authOptions(),
    );
    final conversations = _asList(_asMap(response.data)['conversations']);
    final userIds = conversations
        .whereType<Map>()
        .map((row) => row['peer_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final profiles = await _loadProfiles(userIds);

    return conversations
        .whereType<Map>()
        .where(_isDirectConversation)
        .map((row) {
          final peerId = row['peer_id']?.toString() ?? '';
          final profile = profiles[peerId] ?? const <String, dynamic>{};
          return GroupUserItem(
            id: peerId,
            username: profile['username']?.toString() ?? '',
            fullName: profile['full_name']?.toString(),
            avatarUrl: profile['avatar_url']?.toString(),
            conversationId: row['id']?.toString(),
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<GroupUserItem>> searchUsers(String query,
      {int limit = 50, CancelToken? cancelToken}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final response = await _dio.get(
      '/profiles/search',
      queryParameters: {'q': q, 'limit': limit},
      options: await _authOptions(),
      cancelToken: cancelToken,
    );
    final profiles = _asList(_asMap(response.data)['profiles']);
    final currentUserId = await TokenStorage.getUserId();
    return profiles.whereType<Map>().map((row) {
      return GroupUserItem(
        id: row['user_id']?.toString() ?? '',
        username: row['username']?.toString() ?? '',
        fullName: row['full_name']?.toString(),
        avatarUrl: row['avatar_url']?.toString(),
      );
    }).where((item) {
      return item.id.isNotEmpty && item.id != currentUserId;
    }).toList(growable: false);
  }

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    String? imageUrl,
  }) async {
    final response = await _dio.post(
      '/chat/groups',
      data: {
        'name': name,
        'member_ids': memberIds,
        if (imageUrl != null) 'image_url': imageUrl,
      },
      options: await _authOptions(),
    );
    return _asMap(response.data)['id']?.toString() ?? '';
  }

  Future<Map<String, dynamic>?> fetchGroupInfo(String conversationId) async {
    final response = await _dio.get(
      '/chat/groups/$conversationId',
      options: await _authOptions(),
    );
    return _asMap(response.data);
  }

  Future<List<GroupMemberItem>> fetchGroupMembers(String conversationId) async {
    final response = await _dio.get(
      '/chat/groups/$conversationId/members',
      options: await _authOptions(),
    );
    final rows = _asList(_asMap(response.data)['members']);
    final userIds = rows
        .whereType<Map>()
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final profiles = await _loadProfiles(userIds);
    return rows.whereType<Map>().map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final profile = profiles[userId] ?? const <String, dynamic>{};
      return GroupMemberItem(
        userId: userId,
        username: profile['username']?.toString() ?? '',
        fullName: profile['full_name']?.toString(),
        avatarUrl: profile['avatar_url']?.toString(),
        isAdmin: row['is_admin'] == true,
        joinedAt: DateTime.tryParse(row['joined_at']?.toString() ?? ''),
      );
    }).where((item) {
      return item.userId.isNotEmpty;
    }).toList(growable: false);
  }

  Future<int> addMembers(String conversationId, List<String> memberIds) async {
    final response = await _dio.post(
      '/chat/groups/$conversationId/members',
      data: {'member_ids': memberIds},
      options: await _authOptions(),
    );
    return (_asMap(response.data)['added'] as num?)?.toInt() ?? 0;
  }

  bool _isDirectConversation(Map row) {
    final type = (row['conversation_type'] ?? row['type'] ?? '')
        .toString()
        .toLowerCase();
    return type == 'direct' ||
        type == 'private' ||
        type == 'secret' ||
        row['peer_id'] != null;
  }

  Future<void> removeMember(String conversationId, String memberId) async {
    await _dio.delete(
      '/chat/groups/$conversationId/members/$memberId',
      options: await _authOptions(),
    );
  }

  Future<void> leaveGroup(String conversationId) async {
    await _dio.post(
      '/chat/groups/$conversationId/leave',
      options: await _authOptions(),
    );
  }

  Future<void> setAdmin(
    String conversationId,
    String memberId, {
    required bool makeAdmin,
  }) async {
    await _dio.post(
      '/chat/groups/$conversationId/members/$memberId/admin',
      data: {'make_admin': makeAdmin},
      options: await _authOptions(),
    );
  }

  Future<void> updateGroupInfo(
    String conversationId, {
    String? name,
    String? imageUrl,
  }) async {
    await _dio.patch(
      '/chat/groups/$conversationId',
      data: {
        if (name != null) 'name': name,
        if (imageUrl != null) 'image_url': imageUrl,
      },
      options: await _authOptions(),
    );
  }

  Future<Map<String, dynamic>> getInvite(String conversationId) async {
    final response = await _dio.get(
      '/chat/groups/$conversationId/invite',
      options: await _authOptions(),
    );
    return _asMap(response.data);
  }

  Future<String> regenerateInvite(String conversationId) async {
    final response = await _dio.post(
      '/chat/groups/$conversationId/invite',
      data: const <String, dynamic>{},
      options: await _authOptions(),
    );
    return _asMap(response.data)['invite_code']?.toString() ?? '';
  }

  Future<void> setInviteEnabled(String conversationId, bool enabled) async {
    await _dio.post(
      '/chat/groups/$conversationId/invite',
      data: {'enabled': enabled},
      options: await _authOptions(),
    );
  }

  Future<String> joinByInvite(String code) async {
    final response = await _dio.post(
      '/chat/groups/join/$code',
      options: await _authOptions(),
    );
    return _asMap(response.data)['id']?.toString() ?? '';
  }

  Future<void> deleteGroup(String conversationId) async {
    await _dio.delete(
      '/chat/groups/$conversationId',
      options: await _authOptions(),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    final response = await _dio.post(
      '/profiles/batch',
      data: {'user_ids': userIds},
      options: await _authOptions(),
    );
    final rows = _asList(_asMap(response.data)['profiles']);
    return <String, Map<String, dynamic>>{
      for (final row in rows.whereType<Map>())
        if ((row['user_id']?.toString() ?? '').isNotEmpty)
          row['user_id'].toString(): row.cast<String, dynamic>(),
    };
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    return const [];
  }
}
