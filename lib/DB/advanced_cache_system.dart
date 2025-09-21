import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import '../main.dart';
import 'performance_cache_optimizer.dart';

/// سیستم کش پیشرفته مشابه تلگرام
/// ویژگی‌ها:
/// - Multi-layer caching (Memory + Disk + Network)
/// - Real-time synchronization
/// - Intelligent preloading
/// - Conflict resolution
/// - Offline-first approach
class AdvancedCacheSystem {
  static final AdvancedCacheSystem _instance = AdvancedCacheSystem._internal();
  factory AdvancedCacheSystem() => _instance;
  AdvancedCacheSystem._internal();

  // Memory Cache Layer (سریع‌ترین)
  final Map<String, ConversationModel> _conversationMemoryCache = {};
  final Map<String, List<MessageModel>> _messageMemoryCache = {};
  final Map<String, DateTime> _lastFetch = {};

  // Stream Controllers for real-time updates
  final Map<String, StreamController<List<MessageModel>>> _messageStreams = {};
  final StreamController<List<ConversationModel>> _conversationStream =
      StreamController<List<ConversationModel>>.broadcast();

  // Performance optimizer
  final PerformanceCacheOptimizer _performanceOptimizer =
      PerformanceCacheOptimizer();

  // Configuration
  static const int maxMemoryCacheSize = 50; // Maximum conversations in memory
  static const int maxMessagesPerConversation = 100;
  static const Duration cacheValidityDuration = Duration(minutes: 5);

  // Sync status
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  Set<String> _pendingUploads = <String>{};

  /// Initialize the advanced cache system
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Advanced Cache System already initialized');
      return;
    }

    print('🚀 Initializing Advanced Cache System...');

    try {
      // Load from persistent storage
      await _loadFromDisk();

      // Start performance optimizer
      _performanceOptimizer.initialize();

      // Start real-time sync
      _startRealtimeSync();

      // Start periodic background sync
      _startPeriodicSync();

      _isInitialized = true;
      print('✅ Advanced Cache System initialized successfully');

      // Initial sync
      _performInitialSync();
    } catch (e) {
      print('❌ Failed to initialize Advanced Cache System: $e');
      rethrow;
    }
  }

  /// Load cached data from disk
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load conversations
      final conversationsJson = prefs.getString('cached_conversations');
      if (conversationsJson != null) {
        final List<dynamic> conversationsList = jsonDecode(conversationsJson);
        for (final convJson in conversationsList) {
          final conversation = ConversationModel.fromJson(convJson);
          _conversationMemoryCache[conversation.id] = conversation;
        }
        print(
            '📥 Loaded ${_conversationMemoryCache.length} conversations from disk');
      }

      // Load recent messages for each conversation
      for (final conversationId in _conversationMemoryCache.keys) {
        final messagesJson = prefs.getString('cached_messages_$conversationId');
        if (messagesJson != null) {
          final List<dynamic> messagesList = jsonDecode(messagesJson);
          final messages = messagesList
              .map((json) => MessageModel.fromJson(json,
                  currentUserId: supabase.auth.currentUser?.id ?? ''))
              .toList();
          _messageMemoryCache[conversationId] = messages;
        }
      }

      print(
          '📥 Loaded messages for ${_messageMemoryCache.length} conversations from disk');
    } catch (e) {
      print('⚠️ Error loading from disk: $e');
    }
  }

  /// Save data to persistent storage
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save conversations
      final conversationsList = _conversationMemoryCache.values.toList();
      final conversationsJson =
          jsonEncode(conversationsList.map((c) => c.toJson()).toList());
      await prefs.setString('cached_conversations', conversationsJson);

      // Save messages (only recent ones to save space)
      for (final entry in _messageMemoryCache.entries) {
        final conversationId = entry.key;
        final messages =
            entry.value.take(50).toList(); // Only save latest 50 messages
        final messagesJson =
            jsonEncode(messages.map((m) => m.toJson()).toList());
        await prefs.setString('cached_messages_$conversationId', messagesJson);
      }

      print('💾 Cache saved to disk');
    } catch (e) {
      print('⚠️ Error saving to disk: $e');
    }
  }

  /// Start real-time synchronization with server
  void _startRealtimeSync() {
    if (supabase.auth.currentUser == null) return;

    // Listen to conversation changes with error handling
    try {
      supabase.from('conversations').stream(primaryKey: ['id']).listen(
        (data) async {
          // Pass raw data; enrichment handled elsewhere to avoid FK join issues
          _handleConversationUpdates(List<Map<String, dynamic>>.from(data));
        },
        onError: (error) {
          print('⚠️ Realtime conversation stream error: $error');
          // Don't crash the app, just log the error
        },
      );
    } catch (e) {
      print('⚠️ Failed to setup conversation realtime stream: $e');
    }

    // Listen to message changes for active conversations
    for (final conversationId in _conversationMemoryCache.keys) {
      _setupMessageListener(conversationId);
    }
  }

  /// Setup message listener for specific conversation
  void _setupMessageListener(String conversationId) {
    try {
      supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .listen(
            (data) {
              _handleMessageUpdates(conversationId, data);
            },
            onError: (error) {
              print(
                  '⚠️ Realtime message stream error for $conversationId: $error');
              // Don't crash the app, just log the error
            },
          );
    } catch (e) {
      print('⚠️ Failed to setup message listener for $conversationId: $e');
    }
  }

  /// Handle conversation updates from real-time
  void _handleConversationUpdates(List<Map<String, dynamic>> data) {
    bool hasChanges = false;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    for (final convData in data) {
      final conversation =
          ConversationModel.fromJson(convData, currentUserId: userId);

      // Only process conversations for current user
      // ConversationModel doesn't have userOneId/userTwoId, check participants instead
      final isUserParticipant =
          conversation.participants.any((p) => p.userId == userId);
      if (!isUserParticipant) {
        continue;
      }

      final existingConv = _conversationMemoryCache[conversation.id];
      if (existingConv == null ||
          existingConv.updatedAt.isBefore(conversation.updatedAt)) {
        _conversationMemoryCache[conversation.id] = conversation;
        hasChanges = true;

        // Setup message listener for new conversations
        if (existingConv == null) {
          _setupMessageListener(conversation.id);
        }
      }
    }

    if (hasChanges) {
      _broadcastConversationUpdates();
      _saveToDisk();
    }
  }

  /// Handle message updates from real-time
  void _handleMessageUpdates(
      String conversationId, List<Map<String, dynamic>> data) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final messages = data
        .map((json) => MessageModel.fromJson(json, currentUserId: userId))
        .where((msg) =>
            !msg.id.startsWith('temp_')) // Filter out temporary messages
        .toList();

    // Sort by creation time (newest first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Update memory cache
    _messageMemoryCache[conversationId] = messages;

    // Update conversation's last message
    if (messages.isNotEmpty) {
      final latestMessage = messages.first;
      final conversation = _conversationMemoryCache[conversationId];
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: latestMessage.content,
          lastMessageTime: latestMessage.createdAt,
          updatedAt: latestMessage.createdAt,
        );
        _conversationMemoryCache[conversationId] = updatedConversation;
        _broadcastConversationUpdates();
      }
    }

    // Broadcast message updates
    _broadcastMessageUpdates(conversationId, messages);
    _saveToDisk();
  }

  /// Start periodic background sync
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isSyncing) {
        _performBackgroundSync();
      }
    });
  }

  /// Perform initial sync on startup
  Future<void> _performInitialSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncConversations();

      // Sync messages for active conversations
      final activeConversations = _conversationMemoryCache.values
          .where((c) => _isRecentlyActive(c))
          .take(10) // Only sync top 10 most recent
          .toList();

      for (final conversation in activeConversations) {
        await _syncMessages(conversation.id);
      }
    } catch (e) {
      print('⚠️ Initial sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    _isSyncing = true;

    try {
      // Upload pending messages
      await _uploadPendingMessages();

      // Sync conversations
      await _syncConversations();

      // Sync messages for recently active conversations
      final recentConversations = _conversationMemoryCache.values
          .where((c) => _isRecentlyActive(c))
          .take(5)
          .toList();

      for (final conversation in recentConversations) {
        await _syncMessages(conversation.id, limit: 20);
      }
    } catch (e) {
      print('⚠️ Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Check if conversation is recently active
  bool _isRecentlyActive(ConversationModel conversation) {
    final lastActivity = conversation.lastMessageTime ?? conversation.updatedAt;
    final timeDifference = DateTime.now().difference(lastActivity);
    return timeDifference.inDays <= 7; // Active within last week
  }

  /// Sync conversations from server
  Future<void> _syncConversations() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('conversations')
          .select('*')
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 30)); // Add timeout

      bool hasChanges = false;
      for (final convData in response) {
        final conversation =
            ConversationModel.fromJson(convData, currentUserId: userId);

        // Check if user is participant
        final isUserParticipant =
            conversation.participants.any((p) => p.userId == userId);
        if (!isUserParticipant) continue;

        final existing = _conversationMemoryCache[conversation.id];

        if (existing == null ||
            existing.updatedAt.isBefore(conversation.updatedAt)) {
          _conversationMemoryCache[conversation.id] = conversation;
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _broadcastConversationUpdates();
        _saveToDisk();
      }

      _lastFetch['conversations'] = DateTime.now();
    } catch (e) {
      print('⚠️ Failed to sync conversations: $e');
    }
  }

  /// Sync messages for specific conversation
  Future<void> _syncMessages(String conversationId, {int limit = 50}) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 30)); // Add timeout

      final messages = response
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      // Merge with existing messages (avoid duplicates)
      final existingMessages = _messageMemoryCache[conversationId] ?? [];
      final mergedMessages = _mergeMessages(existingMessages, messages);

      _messageMemoryCache[conversationId] = mergedMessages;
      _broadcastMessageUpdates(conversationId, mergedMessages);

      _lastFetch['messages_$conversationId'] = DateTime.now();
    } catch (e) {
      print('⚠️ Failed to sync messages for $conversationId: $e');
    }
  }

  /// Merge message lists avoiding duplicates
  List<MessageModel> _mergeMessages(
      List<MessageModel> existing, List<MessageModel> newMessages) {
    final messageMap = <String, MessageModel>{};

    // Add existing messages
    for (final message in existing) {
      messageMap[message.id] = message;
    }

    // Add new messages (overwrites if newer)
    for (final message in newMessages) {
      final existingMessage = messageMap[message.id];
      if (existingMessage == null ||
          message.createdAt.isAfter(existingMessage.createdAt)) {
        messageMap[message.id] = message;
      }
    }

    // Convert back to list and sort
    final merged = messageMap.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Limit to max size
    return merged.take(maxMessagesPerConversation).toList();
  }

  /// Upload pending messages to server
  Future<void> _uploadPendingMessages() async {
    final pendingIds = Set<String>.from(_pendingUploads);

    for (final messageId in pendingIds) {
      try {
        // Find the message in cache
        MessageModel? pendingMessage;
        String? conversationId;

        for (final entry in _messageMemoryCache.entries) {
          final message = entry.value.firstWhere(
            (m) => m.id == messageId,
            orElse: () => MessageModel.empty(),
          );
          if (message.id == messageId && message.id.isNotEmpty) {
            pendingMessage = message;
            conversationId = entry.key;
            break;
          }
        }

        if (pendingMessage != null && conversationId != null) {
          // Create real message data for server
          final messageData = {
            'conversation_id': pendingMessage.conversationId,
            'sender_id': pendingMessage.senderId,
            'content': pendingMessage.content,
            'attachment_url': pendingMessage.attachmentUrl,
            'attachment_type': pendingMessage.attachmentType,
            'created_at': pendingMessage.createdAt.toIso8601String(),
          };

          // Upload to server
          final response = await supabase
              .from('messages')
              .insert(messageData)
              .select()
              .single();

          // Replace temporary message with real one
          final realMessage = MessageModel.fromJson(
            response,
            currentUserId: supabase.auth.currentUser?.id ?? '',
          );

          // Update cache with real message
          final messages = _messageMemoryCache[conversationId] ?? [];
          final tempIndex = messages.indexWhere((m) => m.id == messageId);
          if (tempIndex != -1) {
            messages[tempIndex] = realMessage;
            _broadcastMessageUpdates(conversationId, messages);
          }

          _pendingUploads.remove(messageId);
          print(
              '✅ Uploaded and replaced message: $messageId -> ${realMessage.id}');
        }
      } catch (e) {
        print('⚠️ Failed to upload message $messageId: $e');
        // Keep in pending uploads for retry
      }
    }
  }

  /// Broadcast conversation updates to UI
  void _broadcastConversationUpdates() {
    final conversations = _conversationMemoryCache.values.toList();
    conversations.sort((a, b) {
      // Sort by last activity
      final aTime = a.lastMessageTime ?? a.updatedAt;
      final bTime = b.lastMessageTime ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    if (!_conversationStream.isClosed) {
      _conversationStream.add(conversations);
    }
  }

  /// Broadcast message updates to UI
  void _broadcastMessageUpdates(
      String conversationId, List<MessageModel> messages) {
    final controller = _messageStreams[conversationId];
    if (controller != null && !controller.isClosed) {
      controller.add(messages);
    }
  }

  /// Get conversations stream
  Stream<List<ConversationModel>> watchConversations() {
    // Initial emit
    if (_conversationMemoryCache.isNotEmpty) {
      Timer.run(() => _broadcastConversationUpdates());
    }

    return _conversationStream.stream;
  }

  /// Get messages stream for conversation
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    if (!_messageStreams.containsKey(conversationId)) {
      _messageStreams[conversationId] =
          StreamController<List<MessageModel>>.broadcast();

      // Start loading messages if not in cache
      if (!_messageMemoryCache.containsKey(conversationId)) {
        _syncMessages(conversationId);
      } else {
        // Emit cached messages immediately
        Timer.run(() => _broadcastMessageUpdates(
            conversationId, _messageMemoryCache[conversationId] ?? []));
      }
    }

    return _messageStreams[conversationId]!.stream;
  }

  /// Cache new message (for sent messages)
  Future<void> cacheMessage(MessageModel message) async {
    final conversationId = message.conversationId;

    // Add to memory cache
    if (!_messageMemoryCache.containsKey(conversationId)) {
      _messageMemoryCache[conversationId] = [];
    }

    final messages = _messageMemoryCache[conversationId]!;

    // Remove any existing message with same temp ID
    messages.removeWhere((m) =>
        m.id == message.id ||
        (message.id.startsWith('temp_') && m.localId == message.id));

    // Add new message at the beginning
    messages.insert(0, message);

    // Limit cache size
    if (messages.length > maxMessagesPerConversation) {
      messages.removeRange(maxMessagesPerConversation, messages.length);
    }

    // Mark for upload if it's a temporary message
    if (message.id.startsWith('temp_')) {
      _pendingUploads.add(message.id);
    }

    // Update conversation
    final conversation = _conversationMemoryCache[conversationId];
    if (conversation != null) {
      final updatedConversation = conversation.copyWith(
        lastMessage: message.content,
        lastMessageTime: message.createdAt,
        updatedAt: message.createdAt,
      );
      _conversationMemoryCache[conversationId] = updatedConversation;
      _broadcastConversationUpdates();
    }

    // Broadcast update
    _broadcastMessageUpdates(conversationId, messages);

    // Save to disk
    _saveToDisk();
  }

  /// Get cached conversations
  List<ConversationModel> getCachedConversations() {
    return _conversationMemoryCache.values.toList();
  }

  /// Get cached messages for conversation
  List<MessageModel> getCachedMessages(String conversationId) {
    // Try performance cache first
    final optimizedResult = _performanceOptimizer.getMessages(conversationId);
    if (optimizedResult != null) {
      return optimizedResult;
    }

    // Fallback to memory cache
    final memoryResult = _messageMemoryCache[conversationId] ?? [];
    if (memoryResult.isNotEmpty) {
      // Cache in performance optimizer for next time
      _performanceOptimizer.cacheMessages(conversationId, memoryResult);
    }

    return memoryResult;
  }

  /// Clean up resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    _conversationStream.close();
    _performanceOptimizer.dispose();

    for (final controller in _messageStreams.values) {
      controller.close();
    }
    _messageStreams.clear();

    print('🧹 Advanced Cache System disposed');
  }
}
