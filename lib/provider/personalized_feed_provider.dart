import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/publicPostModel.dart';
import '../security/logging_utility.dart';
import '../services/vista_node_service.dart';

/// "For You" feed powered by the Node.js service (function-vista.chbk.dev).
///
/// Pagination model (v1):
/// - Each request returns up to `_limit` NEW items (server dedupes via user_feed_seen)
/// - Client simply asks for "more" and appends.
class PersonalizedFeedNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  PersonalizedFeedNotifier() : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  final int _limit = 15;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _useFallback = false;
  int _fallbackOffset = 0;
  String? _nextBefore; // keyset cursor for Node feed pagination

  bool hasMorePosts() => _hasMore;
  bool isLoading() => _isLoading;

  /// Update follow status for all posts by a specific author in the current feed.
  /// This is used for optimistic UI updates on the "Follow" button in the For You tab.
  void setAuthorFollowStatus(String authorId, String status) {
    final current = state.value;
    if (current == null || current.isEmpty) return;

    final updated = current
        .map((p) => p.userId == authorId
            ? p.copyWith(authorFollowStatus: status)
            : p)
        .toList();
    state = AsyncValue.data(updated);
  }

  Future<void> _loadInitial() async {
    state = const AsyncValue.loading();
    _hasMore = true;
    _isLoading = false;
    _useFallback = false;
    _fallbackOffset = 0;
    _nextBefore = null;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;

    try {
      // Guest mode (not logged in): show a simple public feed so the app isn't empty.
      if (_supabase.auth.currentUser == null) {
        final items = await _fetchGuestFallbackPosts(limit: _limit);
        _fallbackOffset += items.length;
        _hasMore = items.length == _limit;

        final current = state.value ?? const <PublicPostModel>[];
        state = AsyncValue.data([...current, ...items]);

        final sourceCounts = <String, int>{};
        for (final p in items) {
          final key = p.feedSource ?? 'guest_fallback';
          sourceCounts[key] = (sourceCounts[key] ?? 0) + 1;
        }
        logInfo(
          '[Feed] mode=guest_fallback items=${items.length} hasMore=$_hasMore offset=$_fallbackOffset sources=$sourceCounts',
        );
        return;
      }

      if (_useFallback) {
        final items = await _fetchFallbackPosts(limit: _limit);
        _fallbackOffset += items.length;
        _hasMore = items.length == _limit;

        final current = state.value ?? const <PublicPostModel>[];
        state = AsyncValue.data([...current, ...items]);

        final sourceCounts = <String, int>{};
        for (final p in items) {
          final key = p.feedSource ?? 'fallback';
          sourceCounts[key] = (sourceCounts[key] ?? 0) + 1;
        }
        logInfo(
          '[Feed] mode=fallback items=${items.length} hasMore=$_hasMore offset=$_fallbackOffset sources=$sourceCounts',
        );
        return;
      }

      final data = await VistaNodeService.fetchForYouFeed(
        limit: _limit,
        before: _nextBefore,
        debug: kDebugMode,
      );
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PublicPostModel.fromMap)
          .toList();

      _nextBefore = (data['nextBefore'] as String?) ?? _nextBefore;
      final hasMore =
          data['hasMore'] == true && items.isNotEmpty && _nextBefore != null;
      _hasMore = hasMore;

      final current = state.value ?? const <PublicPostModel>[];
      state = AsyncValue.data([...current, ...items]);

      final sourceCounts = <String, int>{};
      for (final p in items) {
        final key = p.feedSource ?? 'unknown';
        sourceCounts[key] = (sourceCounts[key] ?? 0) + 1;
      }

      if (kDebugMode && data['debug'] is Map) {
        final dbg = data['debug'] as Map;
        logInfo(
          '[Feed] mode=node items=${items.length} hasMore=$_hasMore nextBefore=$_nextBefore sources=$sourceCounts debugKeys=${dbg.keys.toList()}',
        );
        final topTags = dbg['topTags'];
        final candidateCounts = dbg['candidateCounts'];
        if (topTags != null) logDebug('[Feed] topTags=$topTags');
        if (candidateCounts != null) {
          logDebug('[Feed] candidateCounts=$candidateCounts');
        }
        if (items.isNotEmpty) {
          final sample = items.take(5).map((p) {
            final src = p.feedSource ?? 'unknown';
            final score = p.feedScore;
            return '${p.id} src=$src score=${score?.toStringAsFixed(3) ?? '-'} author=${p.userId}';
          }).toList();
          logDebug('[Feed] sample=${sample.join(' | ')}');
        }
      } else {
        logInfo(
          '[Feed] mode=node items=${items.length} hasMore=$_hasMore sources=$sourceCounts',
        );
      }
    } catch (e, st) {
      // If the Node service is temporarily down (e.g. 502 from gateway),
      // fall back to a simple time-based feed from Supabase so UX isn't blocked.
      final msg = e.toString();
      final isNodeDown = msg.contains('Feed error 502') ||
          msg.contains('Feed error 503') ||
          msg.contains('Feed error 504') ||
          msg.contains('Feed error 500') ||
          msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Connection closed') ||
          msg.contains('HandshakeException') ||
          e is TimeoutException;

      if (!_useFallback && isNodeDown) {
        _useFallback = true;
        _fallbackOffset = 0;
        logWarning('[Feed] mode=fallback reason=node_down err=$msg',
            error: e, stackTrace: st);
        try {
          final items = await _fetchFallbackPosts(limit: _limit);
          _fallbackOffset += items.length;
          _hasMore = items.length == _limit;
          state = AsyncValue.data(items);

          final sourceCounts = <String, int>{};
          for (final p in items) {
            final key = p.feedSource ?? 'fallback';
            sourceCounts[key] = (sourceCounts[key] ?? 0) + 1;
          }
          logInfo(
            '[Feed] fallback items=${items.length} hasMore=$_hasMore offset=$_fallbackOffset sources=$sourceCounts',
          );
        } catch (e2, st2) {
          state = AsyncValue.error(e2, st2);
        }
      } else {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshPosts() async {
    await _loadInitial();
  }

  Future<void> loadMorePosts() async {
    await _loadMore();
  }

  Future<List<PublicPostModel>> _fetchFallbackPosts({required int limit}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    // Following IDs (needed for private-profile visibility)
    Set<String> followingIds = {};
    try {
      final followingResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      followingIds = (followingResponse as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['following_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (_) {
      followingIds = {};
    }

    final windowStart =
        DateTime.now().subtract(const Duration(days: 14)).toIso8601String();

    final postsResponse = await _supabase
        .from('posts')
        .select('''
          *,
          profiles!posts_user_id_fkey (
            username,
            full_name,
            avatar_url,
            is_verified,
            verification_type
          ),
          likes!likes_post_id_fkey (user_id),
          comments!comments_post_id_fkey (id)
        ''')
        .eq('status', 'published')
        .gte('created_at', windowStart)
        .order('created_at', ascending: false)
        .range(_fallbackOffset, _fallbackOffset + limit - 1);

    final posts = List<Map<String, dynamic>>.from(postsResponse as List<dynamic>);
    if (posts.isEmpty) return const [];

    final userIds = posts
        .map((p) => p['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    // Follow requests (pending) for these authors (for Follow button status)
    final requestedIds = <String>{};
    try {
      final reqRes = await _supabase
          .from('follow_requests')
          .select('recipient_id, status')
          .eq('requester_id', userId)
          .inFilter('recipient_id', userIds);
      for (final row in (reqRes as List<dynamic>)) {
        final m = row as Map<String, dynamic>;
        if ((m['status'] as String?) == 'pending') {
          final rid = m['recipient_id'] as String?;
          if (rid != null) requestedIds.add(rid);
        }
      }
    } catch (_) {
      // If follow_requests doesn't exist / RLS blocks, we just won't show "requested".
    }

    // Privacy settings (if table exists)
    Map<String, bool> privacyMap = {};
    try {
      final settingsResponse = await _supabase
          .from('user_settings')
          .select('user_id, is_private')
          .inFilter('user_id', userIds);
      privacyMap = {
        for (final row in (settingsResponse as List<dynamic>))
          (row as Map<String, dynamic>)['user_id'] as String:
              (row['is_private'] as bool? ?? false)
      };
    } catch (_) {
      // If user_settings doesn't exist / RLS blocks, default to public.
      privacyMap = {};
    }

    final filtered = <PublicPostModel>[];
    for (final post in posts) {
      final postUserId = post['user_id'] as String?;
      if (postUserId == null || postUserId.isEmpty) continue;

      final isPrivate = privacyMap[postUserId] ?? false;
      final shouldShow = postUserId == userId ||
          followingIds.contains(postUserId) ||
          !isPrivate;
      if (!shouldShow) continue;

      final postLikes = post['likes'] as List? ?? [];
      final comments = post['comments'] as List? ?? [];
      final profile = (post['profiles'] as Map<String, dynamic>?) ?? const {};

      final authorFollowStatus = postUserId == userId
          ? 'following'
          : (followingIds.contains(postUserId)
              ? 'following'
              : (requestedIds.contains(postUserId) ? 'requested' : 'none'));

      filtered.add(PublicPostModel.fromMap({
        ...post,
        'like_count': postLikes.length,
        'is_liked': postLikes.any((l) => l['user_id'] == userId),
        'comment_count': comments.length,
        'username':
            profile['username'] ?? profile['full_name'] ?? 'Unknown',
        'avatar_url': profile['avatar_url'] ?? '',
        'is_verified': profile['is_verified'] ?? false,
        'verification_type': profile['verification_type'],
        'feed_source': 'fallback',
        'author_follow_status': authorFollowStatus,
      }));
    }

    return filtered;
  }

  Future<List<PublicPostModel>> _fetchGuestFallbackPosts(
      {required int limit}) async {
    final windowStart =
        DateTime.now().subtract(const Duration(days: 14)).toIso8601String();

    final postsResponse = await _supabase
        .from('posts')
        .select('''
          *,
          profiles!posts_user_id_fkey (
            username,
            full_name,
            avatar_url,
            is_verified,
            verification_type
          )
        ''')
        .eq('status', 'published')
        .gte('created_at', windowStart)
        .order('created_at', ascending: false)
        .range(_fallbackOffset, _fallbackOffset + limit - 1);

    final posts = List<Map<String, dynamic>>.from(postsResponse as List<dynamic>);
    if (posts.isEmpty) return const [];

    return posts.map((post) {
      return PublicPostModel.fromMap({
        ...post,
        'like_count': (post['likes_count'] as num?)?.toInt() ?? 0,
        'comment_count': (post['comments_count'] as num?)?.toInt() ?? 0,
        'is_liked': false,
        'feed_source': 'guest_fallback',
        'author_follow_status': 'none',
      });
    }).toList();
  }
}

final personalizedFeedProvider =
    StateNotifierProvider<PersonalizedFeedNotifier, AsyncValue<List<PublicPostModel>>>(
        (ref) {
  return PersonalizedFeedNotifier();
});
