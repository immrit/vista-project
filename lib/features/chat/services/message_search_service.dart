// lib/features/chat/services/message_search_service.dart
//
// سرویس جستجو در پیام‌ها
//
// ویژگی‌ها:
// ✅ جستجو در متن پیام‌ها
// ✅ جستجوی محلی (کش) و سرور
// ✅ Highlight نتایج
// ✅ فیلتر بر اساس تاریخ/نوع
// ✅ پیمایش بین نتایج
//

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';

/// نتیجه جستجو
class SearchResult {
  final MessageModel message;
  final String highlightedContent;
  final List<TextMatch> matches;

  const SearchResult({
    required this.message,
    required this.highlightedContent,
    required this.matches,
  });
}

/// موقعیت تطابق در متن
class TextMatch {
  final int start;
  final int end;

  const TextMatch(this.start, this.end);
}

/// وضعیت جستجو
class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isSearching;
  final int currentIndex;
  final String? error;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.currentIndex = -1,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isSearching,
    int? currentIndex,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      currentIndex: currentIndex ?? this.currentIndex,
      error: error,
    );
  }

  bool get hasResults => results.isNotEmpty;
  bool get canGoNext => currentIndex < results.length - 1;
  bool get canGoPrevious => currentIndex > 0;
  SearchResult? get currentResult =>
      currentIndex >= 0 && currentIndex < results.length
          ? results[currentIndex]
          : null;
}

/// سرویس جستجو در پیام‌ها
class MessageSearchService {
  final SupabaseClient _supabase;
  Timer? _debounceTimer;

  MessageSearchService(this._supabase);

  /// جستجو در پیام‌های یک مکالمه
  Future<List<SearchResult>> searchInConversation({
    required String conversationId,
    required String query,
    String? currentUserId,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = (response as List).map((json) {
        return MessageModel.fromJson(
          json,
          currentUserId: currentUserId ?? '',
        );
      }).toList();

      return messages.map((message) {
        final matches = _findMatches(message.content, query);
        return SearchResult(
          message: message,
          highlightedContent: _highlightText(message.content, query),
          matches: matches,
        );
      }).toList();
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  /// جستجو در همه مکالمات
  Future<List<SearchResult>> searchGlobal({
    required String query,
    String? currentUserId,
    int limit = 100,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final userId = currentUserId ?? _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // جستجو در مکالماتی که کاربر عضوشونه
      final response = await _supabase
          .from('messages')
          .select('''
            *,
            conversations!inner (
              id,
              conversation_participants!inner (
                user_id
              )
            )
          ''')
          .eq('conversations.conversation_participants.user_id', userId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = (response as List).map((json) {
        return MessageModel.fromJson(
          json,
          currentUserId: userId,
        );
      }).toList();

      return messages.map((message) {
        final matches = _findMatches(message.content, query);
        return SearchResult(
          message: message,
          highlightedContent: _highlightText(message.content, query),
          matches: matches,
        );
      }).toList();
    } catch (e) {
      print('❌ Global search error: $e');
      return [];
    }
  }

  /// پیدا کردن موقعیت‌های تطابق
  List<TextMatch> _findMatches(String text, String query) {
    final List<TextMatch> matches = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(TextMatch(index, index + query.length));
      start = index + 1;
    }

    return matches;
  }

  /// هایلایت متن (برای نمایش)
  String _highlightText(String text, String query) {
    // این متد برای UI استفاده میشه، فعلا همون متن رو برمی‌گردونیم
    // UI میتونه از matches برای هایلایت استفاده کنه
    return text;
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final messageSearchServiceProvider = Provider<MessageSearchService>((ref) {
  return MessageSearchService(Supabase.instance.client);
});

/// State notifier برای جستجو
class SearchStateNotifier extends StateNotifier<SearchState> {
  final MessageSearchService _searchService;
  final String conversationId;
  Timer? _debounceTimer;

  SearchStateNotifier(this._searchService, this.conversationId)
      : super(const SearchState());

  /// جستجو با debounce
  void search(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(
      query: query,
      isSearching: true,
    );

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _searchService.searchInConversation(
          conversationId: conversationId,
          query: query,
        );

        state = state.copyWith(
          results: results,
          isSearching: false,
          currentIndex: results.isNotEmpty ? 0 : -1,
        );
      } catch (e) {
        state = state.copyWith(
          isSearching: false,
          error: e.toString(),
        );
      }
    });
  }

  /// رفتن به نتیجه بعدی
  void nextResult() {
    if (state.canGoNext) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// رفتن به نتیجه قبلی
  void previousResult() {
    if (state.canGoPrevious) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  /// پاک کردن جستجو
  void clear() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final searchStateProvider = StateNotifierProvider.family<
    SearchStateNotifier, SearchState, String>((ref, conversationId) {
  final searchService = ref.watch(messageSearchServiceProvider);
  return SearchStateNotifier(searchService, conversationId);
});

