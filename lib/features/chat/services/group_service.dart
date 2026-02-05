import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_user_item.dart';
import '../models/group_member_item.dart';
import '../../../security/logging_utility.dart';

class GroupService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Map<String, dynamic>? _extractProfile(dynamic profileRaw) {
    if (profileRaw is Map<String, dynamic>) {
      return profileRaw;
    }
    if (profileRaw is List && profileRaw.isNotEmpty) {
      final first = profileRaw.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }
    return null;
  }

  Future<List<GroupUserItem>> getInteractionUsers({int limit = 100}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final conversations = await _supabase
        .from('conversations')
        .select(
            'id, type, last_message_time, conversation_participants(user_id, profiles!user_id(username, full_name, avatar_url))')
        .eq('type', 'private')
        .order('last_message_time', ascending: false)
        .limit(limit);

    final convIds = <String>[];
    final items = <GroupUserItem>[];

    for (final raw in conversations as List) {
      final convId = raw['id'] as String?;
      final participants = (raw['conversation_participants'] as List?) ?? [];
      final other = participants.firstWhere(
        (p) => p['user_id'] != userId,
        orElse: () => null,
      );
      if (convId == null || other == null) continue;
      convIds.add(convId);
      final profile = _extractProfile(other['profiles']);
      items.add(
        GroupUserItem(
          id: other['user_id'] as String,
          username: profile?['username'] as String? ?? '',
          fullName: profile?['full_name'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
          messageCount: 0,
          conversationId: convId,
        ),
      );
    }

    if (convIds.isNotEmpty) {
      final stats = await _supabase
          .from('chat_statistics')
          .select('conversation_id, total_messages')
          .inFilter('conversation_id', convIds);
      final counts = <String, int>{};
      for (final row in stats as List) {
        final id = row['conversation_id'] as String?;
        if (id == null) continue;
        counts[id] = row['total_messages'] as int? ?? 0;
      }

      final updated = items
          .map((item) => GroupUserItem(
                id: item.id,
                username: item.username,
                fullName: item.fullName,
                avatarUrl: item.avatarUrl,
                messageCount: counts[item.conversationId] ?? 0,
                conversationId: item.conversationId,
              ))
          .toList();
      updated.sort((a, b) => b.messageCount.compareTo(a.messageCount));
      return updated;
    }

    return items;
  }

  Future<List<GroupUserItem>> searchUsers(String query,
      {int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
    final q = query.trim();
    if (q.isEmpty) return [];

    final response = await _supabase
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .or('username.ilike.%$q%,full_name.ilike.%$q%')
        .limit(limit);

    return (response as List)
        .where((row) => row['id'] != userId)
        .map((row) => GroupUserItem(
              id: row['id'] as String,
              username: row['username'] as String? ?? '',
              fullName: row['full_name'] as String?,
              avatarUrl: row['avatar_url'] as String?,
            ))
        .toList();
  }

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    String? imageUrl,
  }) async {
    try {
      final result = await _supabase.rpc(
        'create_group_conversation',
        params: {
          'group_name': name,
          'member_ids': memberIds,
          'group_image': imageUrl,
        },
      );
      return result.toString();
    } catch (e, stack) {
      logError('Create group RPC failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchGroupInfo(String conversationId) async {
    final response = await _supabase
        .from('conversations')
        .select(
            'id, name, image, invite_code, invite_enabled, created_by, max_members, type')
        .eq('id', conversationId)
        .maybeSingle();
    return response;
  }

  Future<List<GroupMemberItem>> fetchGroupMembers(String conversationId) async {
    final response = await _supabase
        .from('conversation_participants')
        .select(
            'user_id, is_admin, created_at, profiles!user_id(username, full_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List).map((row) {
      final profile = _extractProfile(row['profiles']);

      return GroupMemberItem(
        userId: row['user_id'] as String,
        username: profile?['username'] as String? ?? '',
        fullName: profile?['full_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        isAdmin: row['is_admin'] as bool? ?? false,
        joinedAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString())
            : null,
      );
    }).toList();
  }

  Future<int> addMembers(String conversationId, List<String> memberIds) async {
    final result = await _supabase.rpc(
      'add_group_members',
      params: {
        'conversation_id': conversationId,
        'member_ids': memberIds,
      },
    );
    return int.tryParse(result.toString()) ?? 0;
  }

  Future<void> removeMember(String conversationId, String memberId) async {
    await _supabase.rpc(
      'remove_group_member',
      params: {
        'conversation_id': conversationId,
        'member_id': memberId,
      },
    );
  }

  Future<void> leaveGroup(String conversationId) async {
    await _supabase.rpc(
      'leave_group',
      params: {'conversation_id': conversationId},
    );
  }

  Future<void> setAdmin(
    String conversationId,
    String memberId, {
    required bool makeAdmin,
  }) async {
    await _supabase.rpc(
      'set_group_admin',
      params: {
        'conversation_id': conversationId,
        'member_id': memberId,
        'make_admin': makeAdmin,
      },
    );
  }

  Future<void> updateGroupInfo(
    String conversationId, {
    String? name,
    String? imageUrl,
  }) async {
    await _supabase.rpc(
      'update_group_info',
      params: {
        'conversation_id': conversationId,
        'new_name': name,
        'new_image': imageUrl,
      },
    );
  }

  Future<Map<String, dynamic>> getInvite(String conversationId) async {
    final result = await _supabase.rpc(
      'get_group_invite',
      params: {'conversation_id': conversationId},
    );
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {'invite_code': null, 'invite_enabled': false};
  }

  Future<String> regenerateInvite(String conversationId) async {
    final result = await _supabase.rpc(
      'regenerate_group_invite',
      params: {'conversation_id': conversationId},
    );
    return result.toString();
  }

  Future<void> setInviteEnabled(String conversationId, bool enabled) async {
    await _supabase.rpc(
      'set_group_invite_enabled',
      params: {
        'conversation_id': conversationId,
        'enabled': enabled,
      },
    );
  }

  Future<String> joinByInvite(String code) async {
    final result = await _supabase.rpc(
      'join_group_by_invite',
      params: {'invite_code': code},
    );
    return result.toString();
  }

  Future<void> deleteGroup(String conversationId) async {
    await _supabase.rpc(
      'delete_group_conversation',
      params: {'conversation_id': conversationId},
    );
  }
}
