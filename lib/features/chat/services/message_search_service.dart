import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/message_model.dart';
import '../../auth/providers/auth_controller.dart';

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

class TextMatch {
  final int start;
  final int end;

  const TextMatch(this.start, this.end);
}

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

class MessageSearchService {
  late final Dio _dio;
  Timer? _debounceTimer;

  MessageSearchService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${EnvConfig.apiBaseUrl ?? 'http://10.0.2.2:8080'}/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<List<SearchResult>> searchInConversation({
    required String conversationId,
    required String query,
    String? currentUserId,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];
    final userId = currentUserId ?? await TokenStorage.getUserId() ?? '';
    final response = await _dio.get(
      '/chat/conversations/$conversationId/search',
      queryParameters: {'q': query, 'limit': limit},
      options: await _authOptions(),
    );
    final messages = _asList(_asMap(response.data)['messages'])
        .whereType<Map>()
        .map(
          (json) => MessageModel.fromJson(
            json.cast<String, dynamic>(),
            currentUserId: userId,
          ),
        )
        .toList(growable: false);

    return messages
        .map(
          (message) => SearchResult(
            message: message,
            highlightedContent: message.content,
            matches: _findMatches(message.content, query),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SearchResult>> searchGlobal({
    required String query,
    String? currentUserId,
    int limit = 100,
  }) async {
    return const [];
  }

  List<TextMatch> _findMatches(String text, String query) {
    final matches = <TextMatch>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(TextMatch(index, index + query.length));
      start = index + 1;
    }
    return matches;
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
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

final messageSearchServiceProvider = Provider<MessageSearchService>((ref) {
  return MessageSearchService();
});

class SearchStateNotifier extends StateNotifier<SearchState> {
  final MessageSearchService _searchService;
  final String conversationId;
  Timer? _debounceTimer;

  SearchStateNotifier(this._searchService, this.conversationId)
      : super(const SearchState());

  void search(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    state = state.copyWith(query: query, isSearching: true);
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
        state = state.copyWith(isSearching: false, error: e.toString());
      }
    });
  }

  void nextResult() {
    if (state.canGoNext) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void previousResult() {
    if (state.canGoPrevious) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

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

final searchStateProvider =
    StateNotifierProvider.family<SearchStateNotifier, SearchState, String>(
        (ref, conversationId) {
  final searchService = ref.watch(messageSearchServiceProvider);
  return SearchStateNotifier(searchService, conversationId);
});
