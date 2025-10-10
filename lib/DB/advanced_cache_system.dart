import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:collection';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import '../main.dart';
import '../services/profile_cache_manager.dart';
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
  // Video thumbnails cache (in-memory + persisted)
  final Map<String, Uint8List> _videoThumbMemoryCache = {};
  final ListQueue<String> _videoThumbOrder = ListQueue<String>();
  static const int maxVideoThumbs = 200;

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
  static const Duration cacheValidityDuration =
      Duration(minutes: 10); // Increased cache validity
  static const Duration backgroundSyncInterval =
      Duration(minutes: 10); // Reduced sync frequency

  // Sync status
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  final Set<String> _pendingUploads = <String>{};

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

      // Start periodic background sync (only once)
      _startPeriodicSync();

      _isInitialized = true;
      print('✅ Advanced Cache System initialized successfully');

      // Initial sync (only if cache is empty)
      if (_conversationMemoryCache.isEmpty) {
        _performInitialSync();
      } else {
        print('📦 Using existing cache, skipping initial sync');
      }
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

      // Load video thumbnails
      final thumbsJson = prefs.getString('cached_video_thumbs');
      if (thumbsJson != null) {
        final List<dynamic> list = jsonDecode(thumbsJson);
        for (final item in list) {
          final url = item['u'] as String?;
          final dataB64 = item['d'] as String?;
          if (url != null && dataB64 != null) {
            try {
              final bytes = base64Decode(dataB64);
              _setVideoThumbInMemory(url, bytes);
            } catch (_) {}
          }
        }
      }
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

      // Save video thumbnails (limit to latest maxVideoThumbs)
      final List<Map<String, String>> thumbList = [];
      for (final url in _videoThumbOrder) {
        final bytes = _videoThumbMemoryCache[url];
        if (bytes != null) {
          thumbList.add({'u': url, 'd': base64Encode(bytes)});
        }
      }
      final toPersist = thumbList.take(maxVideoThumbs).toList();
      await prefs.setString('cached_video_thumbs', jsonEncode(toPersist));
    } catch (e) {
      print('⚠️ Error saving to disk: $e');
    }
  }

  /// Start real-time synchronization with server
  // Stream subscriptions for cleanup
  StreamSubscription? _conversationStreamSubscription;
  StreamSubscription? _profileStreamSubscription;
  final Map<String, StreamSubscription> _messageStreamSubscriptions = {};

  void _startRealtimeSync() {
    if (supabase.auth.currentUser == null) return;

    // Cancel existing streams first
    _conversationStreamSubscription?.cancel();
    _profileStreamSubscription?.cancel();
    for (final subscription in _messageStreamSubscriptions.values) {
      subscription.cancel();
    }
    _messageStreamSubscriptions.clear();

    // Listen to conversation changes with error handling
    try {
      _conversationStreamSubscription =
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

    // Listen to profile changes for real-time updates
    try {
      _profileStreamSubscription =
          supabase.from('profiles').stream(primaryKey: ['id']).listen(
        (data) {
          _handleProfileUpdates(List<Map<String, dynamic>>.from(data));
        },
        onError: (error) {
          print('⚠️ Realtime profile stream error: $error');
        },
      );
    } catch (e) {
      print('⚠️ Failed to setup profile realtime stream: $e');
    }

    // Listen to message changes for active conversations
    for (final conversationId in _conversationMemoryCache.keys) {
      _setupMessageListener(conversationId);
    }
  }

  /// Handle profile updates from real-time
  void _handleProfileUpdates(List<Map<String, dynamic>> data) {
    for (final profileData in data) {
      final userId = profileData['id'] as String?;
      if (userId != null) {
        // Update profile cache manager
        final profileCacheManager = ProfileCacheManager();
        profileCacheManager.updateProfileFromRealtime(userId, profileData);
      }
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
  void _handleConversationUpdates(List<Map<String, dynamic>> data) async {
    bool hasChanges = false;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    for (final convData in data) {
      try {
        // Fetch full conversation data with participants (without profiles join)
        final fullConvData = await supabase.from('conversations').select('''
              *,
              conversation_participants (
                id,
                conversation_id,
                user_id,
                created_at,
                last_read_time,
                is_muted
              )
            ''').eq('id', convData['id']).single();

        final conversation =
            ConversationModel.fromJson(fullConvData, currentUserId: userId);

        // Only process conversations for current user
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
      } catch (e) {
        print(
            '⚠️ Error fetching full conversation data for ${convData['id']}: $e');
        // Fallback to basic conversation data if full fetch fails
        final conversation =
            ConversationModel.fromJson(convData, currentUserId: userId);

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

          if (existingConv == null) {
            _setupMessageListener(conversation.id);
          }
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

    // Sort by creation time (newest first for reverse list)
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
    // Cancel existing timer if any
    _periodicSyncTimer?.cancel();

    _periodicSyncTimer = Timer.periodic(backgroundSyncInterval, (timer) {
      if (!_isSyncing) {
        _performBackgroundSync();
      }
    });
    print(
        '⏰ Periodic sync started (every ${backgroundSyncInterval.inMinutes} minutes)');
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
      // Upload pending messages first
      await _uploadPendingMessages();

      // Only sync conversations if last fetch was more than 5 minutes ago
      final lastFetch = _lastFetch['conversations'];
      if (lastFetch == null ||
          DateTime.now().difference(lastFetch).inMinutes > 5) {
        await _syncConversations();
      }

      // Only sync messages for very recent conversations (last 24 hours)
      final veryRecentConversations = _conversationMemoryCache.values
          .where((c) {
            final lastActivity = c.lastMessageTime ?? c.updatedAt;
            return DateTime.now().difference(lastActivity).inHours < 24;
          })
          .take(3) // Only top 3 most recent
          .toList();

      for (final conversation in veryRecentConversations) {
        await _syncMessages(conversation.id, limit: 20); // Limit messages
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

      // Fetch conversations with participant information (without profiles join)
      final response = await supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              id,
              conversation_id,
              user_id,
              created_at,
              last_read_time,
              is_muted
            )
          ''')
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
          .order('created_at', ascending: false) // جدیدترین اول
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

    // Convert back to list and sort (جدیدترین اول برای لیست reverse)
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

    // Add new message at the end (chronological order)
    messages.add(message);

    // Sort messages by creation time (newest first for reverse list)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Limit cache size
    if (messages.length > maxMessagesPerConversation) {
      messages.removeRange(maxMessagesPerConversation, messages.length);
    }

    // Mark for upload if it's a temporary message
    if (message.id.startsWith('temp_')) {
      _pendingUploads.add(message.id);
    }

    // Update conversation with the latest message (including temp messages)
    final conversation = _conversationMemoryCache[conversationId];
    if (conversation != null) {
      // Get the latest message (including temp messages)
      final latestMessage = messages.isNotEmpty ? messages.first : message;

      // Format last message content for temp messages
      String lastMessageContent = latestMessage.content;
      if (latestMessage.id.startsWith('temp_') && !latestMessage.isSent) {
        // Add clock icon for pending messages
        lastMessageContent = '🕐 $lastMessageContent';
      }

      final updatedConversation = conversation.copyWith(
        lastMessage: lastMessageContent,
        lastMessageTime: latestMessage.createdAt,
        updatedAt: latestMessage.createdAt,
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
      // مرتب‌سازی از جدید به قدیمی برای نمایش صحیح در لیست reverse
      final sortedResult = List<MessageModel>.from(memoryResult)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Cache in performance optimizer for next time
      _performanceOptimizer.cacheMessages(conversationId, sortedResult);
      return sortedResult;
    }

    return memoryResult;
  }

  /// Clean up resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    _conversationStreamSubscription?.cancel();
    _profileStreamSubscription?.cancel();
    for (final subscription in _messageStreamSubscriptions.values) {
      subscription.cancel();
    }
    _messageStreamSubscriptions.clear();
    _conversationStream.close();
    _performanceOptimizer.dispose();

    for (final controller in _messageStreams.values) {
      controller.close();
    }
    _messageStreams.clear();
    _videoThumbMemoryCache.clear();
    _videoThumbOrder.clear();

    _isInitialized = false;
    print('🧹 Advanced Cache System disposed');
  }
}

// Public API for video thumbnail caching
extension VideoThumbnailCacheExt on AdvancedCacheSystem {
  Uint8List? getVideoThumbnail(String url) {
    final cached = _videoThumbMemoryCache[url];
    if (cached != null) {
      _videoThumbOrder.remove(url);
      _videoThumbOrder.addLast(url);
      return cached;
    }
    return null;
  }

  void cacheVideoThumbnail(String url, Uint8List bytes) {
    _setVideoThumbInMemory(url, bytes);
    // Persist lazily; don't block UI. Fire and forget.
    // ignore: discarded_futures
    _saveToDisk();
  }

  void _setVideoThumbInMemory(String url, Uint8List bytes) {
    if (_videoThumbMemoryCache.containsKey(url)) {
      _videoThumbOrder.remove(url);
    }
    _videoThumbMemoryCache[url] = bytes;
    _videoThumbOrder.addLast(url);
    while (_videoThumbOrder.length > AdvancedCacheSystem.maxVideoThumbs) {
      final oldest = _videoThumbOrder.removeFirst();
      _videoThumbMemoryCache.remove(oldest);
    }
  }
}
