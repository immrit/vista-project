import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import 'advanced_cache_manager.dart';
import 'smart_message_cache.dart';

/// Real-time cache manager for handling live message updates
class RealtimeCacheManager {
  static final RealtimeCacheManager _instance =
      RealtimeCacheManager._internal();
  factory RealtimeCacheManager() => _instance;
  RealtimeCacheManager._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();
  final SmartMessageCache _smartCache = SmartMessageCache();

  // Real-time subscriptions
  final Map<String, StreamSubscription> _conversationSubscriptions = {};
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  // Pending updates queue
  final Map<String, List<MessageModel>> _pendingUpdates = {};
  final Map<String, List<ConversationModel>> _pendingConversationUpdates = {};

  // Real-time configuration
  static const Duration _updateBatchDelay = Duration(milliseconds: 500);
  static const int _maxPendingUpdates = 50;

  bool _isInitialized = false;

  /// Initialize real-time cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _cacheManager.initialize();
    await _smartCache.initialize();

    _startBatchProcessor();
    _isInitialized = true;

    print('✅ Real-time Cache Manager initialized');
  }

  /// Subscribe to real-time updates for a conversation
  Future<void> subscribeToConversation(
      String conversationId, String userId) async {
    if (_conversationSubscriptions.containsKey(conversationId)) {
      return; // Already subscribed
    }

    try {
      // Create real-time subscription (would integrate with Supabase real-time)
      final subscription =
          _createConversationSubscription(conversationId, userId);

      _conversationSubscriptions[conversationId] = subscription;

      // Also subscribe to message updates
      await subscribeToMessages(conversationId, userId);

      print(
          '📡 Subscribed to real-time updates for conversation: $conversationId');
    } catch (e) {
      print('❌ Error subscribing to conversation $conversationId: $e');
    }
  }

  /// Subscribe to message updates for a conversation
  Future<void> subscribeToMessages(String conversationId, String userId) async {
    if (_messageSubscriptions.containsKey(conversationId)) {
      return; // Already subscribed
    }

    try {
      final subscription = _createMessageSubscription(conversationId, userId);
      _messageSubscriptions[conversationId] = subscription;

      print(
          '💬 Subscribed to message updates for conversation: $conversationId');
    } catch (e) {
      print('❌ Error subscribing to messages for $conversationId: $e');
    }
  }

  /// Unsubscribe from conversation updates
  Future<void> unsubscribeFromConversation(String conversationId) async {
    final convSubscription = _conversationSubscriptions.remove(conversationId);
    final msgSubscription = _messageSubscriptions.remove(conversationId);

    await convSubscription?.cancel();
    await msgSubscription?.cancel();

    // Clear pending updates
    _pendingUpdates.remove(conversationId);
    _pendingConversationUpdates.remove(conversationId);

    print('🔇 Unsubscribed from conversation: $conversationId');
  }

  /// Handle incoming message update
  Future<void> handleMessageUpdate(MessageModel message) async {
    final conversationId = message.conversationId;

    // Add to pending updates queue
    if (!_pendingUpdates.containsKey(conversationId)) {
      _pendingUpdates[conversationId] = [];
    }

    _pendingUpdates[conversationId]!.add(message);

    // Limit pending updates
    if (_pendingUpdates[conversationId]!.length > _maxPendingUpdates) {
      _pendingUpdates[conversationId] = _pendingUpdates[conversationId]!
          .sublist(
              _pendingUpdates[conversationId]!.length - _maxPendingUpdates);
    }

    print('📨 Queued message update for ${message.id}');
  }

  /// Handle incoming conversation update
  Future<void> handleConversationUpdate(ConversationModel conversation) async {
    final conversationId = conversation.id;

    if (!_pendingConversationUpdates.containsKey(conversationId)) {
      _pendingConversationUpdates[conversationId] = [];
    }

    _pendingConversationUpdates[conversationId]!.add(conversation);

    print('🏷️ Queued conversation update for $conversationId');
  }

  /// Process pending updates in batches
  Future<void> _processPendingUpdates() async {
    // Process message updates
    for (final entry in _pendingUpdates.entries) {
      final conversationId = entry.key;
      final messages = entry.value;

      if (messages.isNotEmpty) {
        try {
          // Cache messages in batch
          await _smartCache.cacheMessages(messages, conversationId);

          // Update conversation metadata
          await _updateConversationMetadata(conversationId, messages.last);

          // Clear processed messages
          _pendingUpdates[conversationId] = [];

          print(
              '✅ Processed ${messages.length} message updates for $conversationId');
        } catch (e) {
          print('❌ Error processing message updates for $conversationId: $e');
        }
      }
    }

    // Process conversation updates
    for (final entry in _pendingConversationUpdates.entries) {
      final conversationId = entry.key;
      final conversations = entry.value;

      if (conversations.isNotEmpty) {
        try {
          // Cache the latest conversation update
          final latestConversation = conversations.last;
          await _cacheManager.cacheConversation(latestConversation);

          // Clear processed conversations
          _pendingConversationUpdates[conversationId] = [];

          print('✅ Processed conversation update for $conversationId');
        } catch (e) {
          print(
              '❌ Error processing conversation update for $conversationId: $e');
        }
      }
    }
  }

  /// Update conversation metadata based on new messages
  Future<void> _updateConversationMetadata(
      String conversationId, MessageModel latestMessage) async {
    try {
      final conversation = await _cacheManager.getConversation(conversationId);
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: latestMessage.content,
          lastMessageTime: latestMessage.createdAt,
          unreadCount:
              conversation.unreadCount + 1, // This would be calculated properly
        );

        await _cacheManager.cacheConversation(updatedConversation);
      }
    } catch (e) {
      print('❌ Error updating conversation metadata: $e');
    }
  }

  /// Get real-time message stream for a conversation
  Stream<List<MessageModel>> getRealtimeMessageStream(String conversationId) {
    // Return cached messages initially, then stream updates
    final controller = StreamController<List<MessageModel>>();

    // Send initial cached messages
    _cacheManager.getConversationMessages(conversationId).then((messages) {
      if (!controller.isClosed) {
        controller.add(messages);
      }
    });

    // Listen to pending updates
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      final pendingMessages = _pendingUpdates[conversationId] ?? [];
      if (pendingMessages.isNotEmpty) {
        _cacheManager.getConversationMessages(conversationId).then((messages) {
          if (!controller.isClosed) {
            controller.add(messages);
          }
        });
      }
    });

    return controller.stream;
  }

  /// Create conversation subscription (placeholder for Supabase integration)
  StreamSubscription _createConversationSubscription(
      String conversationId, String userId) {
    // This would be replaced with actual Supabase real-time subscription
    return Stream.empty().listen((_) {});
  }

  /// Create message subscription (placeholder for Supabase integration)
  StreamSubscription _createMessageSubscription(
      String conversationId, String userId) {
    // This would be replaced with actual Supabase real-time subscription
    return Stream.empty().listen((_) {});
  }

  /// Start batch processor for pending updates
  void _startBatchProcessor() {
    Timer.periodic(_updateBatchDelay, (timer) {
      _processPendingUpdates();
    });
  }

  /// Get real-time cache statistics
  Map<String, dynamic> getRealtimeStatistics() {
    return {
      'active_subscriptions':
          _conversationSubscriptions.length + _messageSubscriptions.length,
      'pending_message_updates':
          _pendingUpdates.values.fold(0, (sum, list) => sum + list.length),
      'pending_conversation_updates': _pendingConversationUpdates.values
          .fold(0, (sum, list) => sum + list.length),
      'subscribed_conversations': _conversationSubscriptions.keys.toList(),
    };
  }

  /// Force sync all pending updates
  Future<void> forceSync() async {
    await _processPendingUpdates();
    print('🔄 Forced sync of all pending updates');
  }

  /// Clear all subscriptions and pending updates
  Future<void> clearAll() async {
    // Cancel all subscriptions
    for (final subscription in _conversationSubscriptions.values) {
      await subscription.cancel();
    }
    for (final subscription in _messageSubscriptions.values) {
      await subscription.cancel();
    }

    _conversationSubscriptions.clear();
    _messageSubscriptions.clear();
    _pendingUpdates.clear();
    _pendingConversationUpdates.clear();

    print('🧹 Cleared all real-time cache data');
  }

  /// Dispose resources
  void dispose() {
    clearAll();
  }
}

/// Real-time cache event types
enum RealtimeEventType {
  messageInsert,
  messageUpdate,
  messageDelete,
  conversationUpdate,
  userPresence,
}

/// Real-time cache event
class RealtimeCacheEvent {
  final RealtimeEventType type;
  final dynamic data;
  final DateTime timestamp;

  RealtimeCacheEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
