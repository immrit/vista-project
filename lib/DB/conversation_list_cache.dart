import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../model/conversation_model.dart';
import 'advanced_cache_manager.dart';

/// Advanced conversation list cache with intelligent ordering and filtering
class ConversationListCache {
  static final ConversationListCache _instance =
      ConversationListCache._internal();
  factory ConversationListCache() => _instance;
  ConversationListCache._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();

  // Conversation ordering and filtering
  final SplayTreeMap<DateTime, ConversationModel> _orderedConversations =
      SplayTreeMap<DateTime, ConversationModel>();
  final Map<String, ConversationModel> _conversationMap = {};
  final Map<String, int> _unreadCounts = {};

  // Cache configuration
  static const Duration _conversationTTL = Duration(hours: 6);
  static const int _maxConversationsInMemory = 200;

  // Performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;

  bool _isInitialized = false;

  /// Initialize conversation list cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _cacheManager.initialize();
    _startPeriodicCleanup();

    _isInitialized = true;
    print('✅ Conversation List Cache initialized');
  }

  /// Cache conversation with intelligent ordering
  Future<void> cacheConversation(ConversationModel conversation) async {
    // Update memory cache
    _conversationMap[conversation.id] = conversation;
    _orderedConversations[conversation.lastMessageTime ?? DateTime.now()] =
        conversation;
    _unreadCounts[conversation.id] = conversation.unreadCount;

    // Maintain cache size
    _maintainCacheSize();

    // Cache in persistent storage
    await _cacheManager.cacheConversation(conversation);

    print('💬 Cached conversation: ${conversation.id}');
  }

  /// Cache multiple conversations efficiently
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return;

    final startTime = DateTime.now();

    // Update memory cache
    for (final conversation in conversations) {
      _conversationMap[conversation.id] = conversation;
      _orderedConversations[conversation.lastMessageTime ?? DateTime.now()] =
          conversation;
      _unreadCounts[conversation.id] = conversation.unreadCount;
    }

    // Maintain cache size
    _maintainCacheSize();

    // Batch cache in persistent storage
    for (final conversation in conversations) {
      await _cacheManager.cacheConversation(conversation);
    }

    final duration = DateTime.now().difference(startTime);
    print(
        '📦 Batched cached ${conversations.length} conversations in ${duration.inMilliseconds}ms');
  }

  /// Get cached conversation
  Future<ConversationModel?> getConversation(String conversationId) async {
    // Check memory cache first
    final conversation = _conversationMap[conversationId];
    if (conversation != null) {
      _cacheHits++;
      return conversation;
    }

    // Check persistent storage
    final cached = await _cacheManager.getConversation(conversationId);
    if (cached != null) {
      // Update memory cache
      _conversationMap[conversationId] = cached;
      _orderedConversations[cached.lastMessageTime ?? DateTime.now()] = cached;
      _unreadCounts[conversationId] = cached.unreadCount;

      _cacheHits++;
      return cached;
    }

    _cacheMisses++;

    return null;
  }

  /// Get ordered conversation list with filtering
  Future<List<ConversationModel>> getConversationList({
    ConversationFilter filter = ConversationFilter.all,
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final conversations = <ConversationModel>[];

    // Get from memory cache
    final memoryConversations = _orderedConversations.values.toList().reversed;

    // Apply filters
    for (final conversation in memoryConversations) {
      if (_matchesFilter(conversation, filter, searchQuery)) {
        conversations.add(conversation);
      }
    }

    // If not enough conversations in memory, load from persistent storage
    if (conversations.length < (limit ?? 50)) {
      final persistentConversations = await _loadConversationsFromPersistent(
        filter: filter,
        searchQuery: searchQuery,
        limit: limit,
        offset: offset,
      );

      // Add to memory cache
      for (final conversation in persistentConversations) {
        if (!_conversationMap.containsKey(conversation.id)) {
          _conversationMap[conversation.id] = conversation;
          _orderedConversations[
              conversation.lastMessageTime ?? DateTime.now()] = conversation;
          _unreadCounts[conversation.id] = conversation.unreadCount;
        }
      }

      conversations.addAll(persistentConversations);
    }

    // Apply pagination
    if (offset != null && limit != null) {
      final start = offset;
      final end = start + limit;
      return conversations.sublist(start, end.clamp(0, conversations.length));
    }

    return limit != null ? conversations.take(limit).toList() : conversations;
  }

  /// Update conversation with optimistic updates
  Future<void> updateConversation(ConversationModel updatedConversation) async {
    final conversationId = updatedConversation.id;

    // Optimistic update in memory
    _conversationMap[conversationId] = updatedConversation;
    _orderedConversations[updatedConversation.lastMessageTime ??
        DateTime.now()] = updatedConversation;
    _unreadCounts[conversationId] = updatedConversation.unreadCount;

    // Maintain ordering
    _maintainOrdering();

    // Update persistent storage
    await _cacheManager.cacheConversation(updatedConversation);

    print('🔄 Updated conversation: $conversationId');
  }

  /// Update unread count for conversation
  Future<void> updateUnreadCount(String conversationId, int unreadCount) async {
    _unreadCounts[conversationId] = unreadCount;

    final conversation = _conversationMap[conversationId];
    if (conversation != null) {
      final updatedConversation =
          conversation.copyWith(unreadCount: unreadCount);
      await updateConversation(updatedConversation);
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead(String conversationId) async {
    await updateUnreadCount(conversationId, 0);
  }

  /// Get total unread count across all conversations
  int getTotalUnreadCount() {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Get conversations with unread messages
  List<ConversationModel> getUnreadConversations() {
    return _conversationMap.values
        .where((conversation) => (_unreadCounts[conversation.id] ?? 0) > 0)
        .toList();
  }

  /// Search conversations
  Future<List<ConversationModel>> searchConversations(String query) async {
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    final results = <ConversationModel>[];

    // Search in memory cache
    for (final conversation in _conversationMap.values) {
      if (_matchesSearch(conversation, lowercaseQuery)) {
        results.add(conversation);
      }
    }

    // Sort by relevance (recent conversations first)
    results.sort((a, b) => (b.lastMessageTime ?? DateTime(1970))
        .compareTo(a.lastMessageTime ?? DateTime(1970)));

    return results;
  }

  /// Invalidate conversation cache
  Future<void> invalidateConversation(String conversationId) async {
    _conversationMap.remove(conversationId);
    _unreadCounts.remove(conversationId);

    // Remove from ordered map
    _orderedConversations
        .removeWhere((key, value) => value.id == conversationId);

    await _cacheManager.invalidateConversation(conversationId);

    print('🚫 Invalidated conversation cache: $conversationId');
  }

  /// Clear all cached conversations
  Future<void> clearAll() async {
    _conversationMap.clear();
    _orderedConversations.clear();
    _unreadCounts.clear();

    print('🧹 Cleared all conversation cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return {
      'memory_conversations': _conversationMap.length,
      'ordered_conversations': _orderedConversations.length,
      'unread_conversations': getUnreadConversations().length,
      'total_unread_count': getTotalUnreadCount(),
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'hit_rate': hitRate,
    };
  }

  /// Check if conversation matches filter
  bool _matchesFilter(ConversationModel conversation, ConversationFilter filter,
      String? searchQuery) {
    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      if (!_matchesSearch(conversation, searchQuery.toLowerCase())) {
        return false;
      }
    }

    // Apply conversation filter
    switch (filter) {
      case ConversationFilter.all:
        return true;
      case ConversationFilter.unread:
        return (_unreadCounts[conversation.id] ?? 0) > 0;
      case ConversationFilter.archived:
        return conversation.isArchived;
      case ConversationFilter.pinned:
        return conversation.isPinned;
    }
  }

  /// Check if conversation matches search query
  bool _matchesSearch(ConversationModel conversation, String query) {
    final searchableText =
        '${conversation.otherUserName} ${conversation.lastMessage ?? ''}'
            .toLowerCase();
    return searchableText.contains(query);
  }

  /// Maintain cache size
  void _maintainCacheSize() {
    if (_conversationMap.length > _maxConversationsInMemory) {
      // Remove oldest conversations
      final entries = _orderedConversations.entries.toList()
        ..sort((a, b) =>
            a.key.compareTo(b.key)); // Sort by timestamp (oldest first)

      final toRemove =
          entries.take(_conversationMap.length - _maxConversationsInMemory);
      for (final entry in toRemove) {
        final conversation = entry.value;
        _conversationMap.remove(conversation.id);
        _unreadCounts.remove(conversation.id);
        _orderedConversations.remove(entry.key);
      }
    }
  }

  /// Maintain ordering after updates
  void _maintainOrdering() {
    // Rebuild ordered map to maintain correct ordering
    final conversations = _conversationMap.values.toList();
    _orderedConversations.clear();

    for (final conversation in conversations) {
      _orderedConversations[conversation.lastMessageTime ?? DateTime.now()] =
          conversation;
    }
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 30), (timer) {
      _performCleanup();
    });
  }

  /// Perform periodic cleanup
  Future<void> _performCleanup() async {
    await _cacheManager.clearExpiredEntries();
    _maintainCacheSize();

    print('🧽 Performed conversation cache cleanup');
  }

  /// Load conversations from persistent storage (placeholder)
  Future<List<ConversationModel>> _loadConversationsFromPersistent({
    ConversationFilter filter = ConversationFilter.all,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    // This would integrate with the existing Sembast conversation cache
    return [];
  }
}

/// Conversation filter types
enum ConversationFilter {
  all,
  unread,
  archived,
  pinned,
}

/// Conversation sorting options
enum ConversationSort {
  lastMessageTime,
  unreadCount,
  alphabetical,
}
