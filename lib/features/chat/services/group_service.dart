import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../auth/providers/auth_controller.dart';
import '../../../services/session_manager_service_v2.dart';
import '../models/group_member_item.dart';
import '../models/group_user_item.dart';
import '../../../services/http_client_factory.dart';
import '../../../services/system_status_service.dart';

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
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!sessionReady) {
      throw StateError('User not authenticated');
    }

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<GroupUserItem>> getInteractionUsers({int limit = 100}) async {
    final currentUserId = await _resolveCurrentUserId();
    dynamic responseData;
    try {
      final response = await _dio.get(
        '/chat/conversations',
        queryParameters: {'limit': limit},
        options: await _authOptions(),
      );
      responseData = response.data;
    } catch (_) {
      // If chat-conversations endpoint is unavailable for any reason,
      // still provide a usable selection list from follow graph.
      return _fallbackUsersFromFollowGraph(currentUserId: currentUserId);
    }
    final conversations = _asList(_asMap(responseData)['conversations']);
    final directRows = conversations
        .whereType<Map>()
        .where((row) => _isDirectConversation(row))
        .toList(growable: false);

    final userIds = directRows
        .map((row) => _peerIdFromRow(row))
        .where((id) =>
            id.isNotEmpty &&
            id != _nilUuid &&
            (currentUserId == null || id != currentUserId))
        .toSet()
        .toList(growable: false);

    if (userIds.isEmpty) {
      return _fallbackUsersFromFollowGraph(currentUserId: currentUserId);
    }

    final profiles = await _loadProfilesSafe(userIds);

    final bestByUser = <String, GroupUserItem>{};
    final scoreByUser = <String, double>{};

    for (final row in directRows) {
      final peerId = _peerIdFromRow(row);
      if (peerId.isEmpty ||
          peerId == _nilUuid ||
          (currentUserId != null && peerId == currentUserId)) {
        continue;
      }

      final score = _interactionScore(row);
      final existing = scoreByUser[peerId];
      if (existing != null && existing >= score) {
        continue;
      }

      final profile = profiles[peerId] ?? _profileFromConversationRow(row);
      bestByUser[peerId] = GroupUserItem(
        id: peerId,
        username: profile['username']?.toString() ?? '',
        fullName: profile['full_name']?.toString(),
        avatarUrl: profile['avatar_url']?.toString(),
        conversationId: row['id']?.toString(),
        messageCount: _interactionCount(row),
      );
      scoreByUser[peerId] = score;
    }

    final items = bestByUser.values.toList(growable: false)
      ..sort(
          (a, b) => (scoreByUser[b.id] ?? 0).compareTo(scoreByUser[a.id] ?? 0));

    if (items.isNotEmpty) {
      return items;
    }

    return _fallbackUsersFromFollowGraph(currentUserId: currentUserId);
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
    await SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.chat,
      forceRefresh: true,
    );
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
    final isDirectType = type == 'direct' ||
        type == 'private' ||
        type == 'secret' ||
        type == 'dm';
    if (isDirectType) return true;

    final peerId = _peerIdFromRow(row);
    return peerId.isNotEmpty && peerId != _nilUuid;
  }

  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

  String _peerIdFromRow(Map row) {
    return (row['peer_id'] ??
            row['peerId'] ??
            row['other_user_id'] ??
            row['otherUserId'] ??
            '')
        .toString()
        .trim();
  }

  int _interactionCount(Map row) {
    final raw = row['interaction_count'] ??
        row['message_count'] ??
        row['messages_count'] ??
        row['total_messages'] ??
        row['unread_count'] ??
        0;
    return _toInt(raw);
  }

  double _interactionScore(Map row) {
    final interactions = _interactionCount(row);
    final lastMessageAt = _parseDate(row['last_message_at'] ??
        row['lastMessageAt'] ??
        row['updated_at'] ??
        row['updatedAt']);
    if (lastMessageAt == null) {
      return interactions.toDouble();
    }

    final ageHours = DateTime.now().difference(lastMessageAt).inHours;
    final recencyBoost = (24 * 7 - ageHours).clamp(0, 24 * 7).toDouble();
    return interactions.toDouble() * 10 + recencyBoost;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<List<GroupUserItem>> _fallbackUsersFromFollowGraph({
    required String? currentUserId,
  }) async {
    if (currentUserId == null || currentUserId.isEmpty) return const [];

    final merged = <String, GroupUserItem>{};
    Future<void> load(String endpoint) async {
      try {
        final response = await _dio.get(
          endpoint,
          queryParameters: const {'limit': 50, 'offset': 0},
          options: await _authOptions(),
        );
        final rows = _asList(_asMap(response.data)['profiles']);
        for (final row in rows.whereType<Map>()) {
          final id = row['user_id']?.toString() ?? '';
          if (id.isEmpty || id == currentUserId || id == _nilUuid) continue;
          merged[id] = GroupUserItem(
            id: id,
            username: row['username']?.toString() ?? '',
            fullName: row['full_name']?.toString(),
            avatarUrl: row['avatar_url']?.toString(),
          );
        }
      } catch (_) {
        // Silent fallback: if follow graph fails, return whatever we already have.
      }
    }

    await load('/profiles/following/$currentUserId');
    await load('/profiles/followers/$currentUserId');
    return merged.values.toList(growable: false);
  }

  Future<String?> _resolveCurrentUserId() async {
    final cached = await TokenStorage.getUserId();
    if (cached != null && cached.isNotEmpty && cached != _nilUuid) {
      return cached;
    }

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = json.decode(payload);
      if (decoded is! Map) return null;
      final userId = decoded['sub']?.toString();
      if (userId == null || userId.isEmpty || userId == _nilUuid) return null;
      await TokenStorage.saveUserId(userId);
      return userId;
    } catch (_) {
      return null;
    }
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

  Future<Map<String, Map<String, dynamic>>> _loadProfilesSafe(
    List<String> userIds,
  ) async {
    try {
      return await _loadProfiles(userIds);
    } catch (_) {
      return const {};
    }
  }

  Map<String, dynamic> _profileFromConversationRow(Map row) {
    return <String, dynamic>{
      'username': (row['peer_username'] ??
              row['other_user_username'] ??
              row['username'] ??
              '')
          .toString(),
      'full_name': (row['peer_full_name'] ??
              row['other_user_full_name'] ??
              row['full_name'] ??
              row['name'] ??
              '')
          .toString(),
      'avatar_url': (row['peer_avatar_url'] ??
              row['other_user_avatar'] ??
              row['avatar_url'] ??
              row['image'])
          ?.toString(),
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
