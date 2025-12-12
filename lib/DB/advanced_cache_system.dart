import '../security/logging_utility.dart';
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
      logInfo('✅ Advanced Cache System already initialized');
      return;
    }

    logInfo('🚀 Initializing Advanced Cache System...');

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
      logInfo('✅ Advanced Cache System initialized successfully');
      logInfo('📦 Cache status: ${_conversationMemoryCache.length} conversations loaded from disk');

      // Initial sync (only if cache is empty)
      if (_conversationMemoryCache.isEmpty) {
        logInfo('🔄 Cache is empty, performing initial sync...');
        _performInitialSync();
      } else {
        logInfo('📦 Using existing cache (${_conversationMemoryCache.length} conversations), skipping initial sync');
        // ✅ اطمینان از اینکه کش broadcast شده است
        _broadcastConversationUpdates();
      }
    } catch (e) {
      logInfo('❌ Failed to initialize Advanced Cache System: $e');
      rethrow;
    }
  }

  /// Load cached data from disk
  Future<void> _loadFromDisk() async {
    try {
      final stopwatch = Stopwatch()..start();
      final prefs = await SharedPreferences.getInstance();

      // Load conversations - بهینه‌سازی: استفاده از batch parsing
      final conversationsJson = prefs.getString('cached_conversations');
      if (conversationsJson != null && conversationsJson.isNotEmpty) {
        try {
          final List<dynamic> conversationsList = jsonDecode(conversationsJson);
          final currentUserId = supabase.auth.currentUser?.id;
          
          // ✅ بهینه‌سازی: parse کردن به صورت batch
          final loadedConversations = <String, ConversationModel>{};
          for (final convJson in conversationsList) {
            try {
              final conversation = ConversationModel.fromJson(
                convJson,
                currentUserId: currentUserId,
              );
              loadedConversations[conversation.id] = conversation;
            } catch (e) {
              logInfo('⚠️ Error parsing conversation from cache: $e');
              // ادامه بده با بقیه
            }
          }
          
          // ✅ یکجا اضافه کردن به memory cache
          _conversationMemoryCache.addAll(loadedConversations);
          
          final loadTime = stopwatch.elapsedMilliseconds;
          print(
              '📥 Loaded ${_conversationMemoryCache.length} conversations from disk in ${loadTime}ms');
          
          // ✅ بعد از load شدن، بلافاصله broadcast کن تا UI به‌روز شود
          if (_conversationMemoryCache.isNotEmpty) {
            _broadcastConversationUpdates();
            print('📡 Broadcasted ${_conversationMemoryCache.length} conversations to UI');
          }
        } catch (e) {
          logInfo('❌ Error loading conversations from disk: $e');
        }
      } else {
        print('📥 No cached conversations found on disk');
      }

      // Load recent messages for each conversation - بهینه‌سازی: فقط برای مکالمه‌های فعال
      // فقط برای 20 مکالمه اخیر پیام‌ها را load کن تا startup سریع‌تر شود
      final conversationIds = _conversationMemoryCache.keys.toList();
      final activeConversationIds = conversationIds.take(20).toList();
      
      final currentUserId = supabase.auth.currentUser?.id ?? '';
      for (final conversationId in activeConversationIds) {
        final messagesJson = prefs.getString('cached_messages_$conversationId');
        if (messagesJson != null && messagesJson.isNotEmpty) {
          try {
            final List<dynamic> messagesList = jsonDecode(messagesJson);
            final messages = messagesList
                .map((json) => MessageModel.fromJson(json,
                    currentUserId: currentUserId))
                .toList();
            _messageMemoryCache[conversationId] = messages;
          } catch (e) {
            logInfo('⚠️ Error parsing messages for $conversationId: $e');
          }
        }
      }

      final totalTime = stopwatch.elapsedMilliseconds;
      print(
          '📥 Loaded messages for ${_messageMemoryCache.length} conversations from disk (total time: ${totalTime}ms)');
      stopwatch.stop();

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
      logInfo('⚠️ Error loading from disk: $e');
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

      logInfo('💾 Cache saved to disk');

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
      logInfo('⚠️ Error saving to disk: $e');
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
          logInfo('⚠️ Realtime conversation stream error: $error');
          // Don't crash the app, just log the error
        },
      );
    } catch (e) {
      logInfo('⚠️ Failed to setup conversation realtime stream: $e');
    }

    // Listen to profile changes for real-time updates
    try {
      _profileStreamSubscription =
          supabase.from('profiles').stream(primaryKey: ['id']).listen(
        (data) {
          _handleProfileUpdates(List<Map<String, dynamic>>.from(data));
        },
        onError: (error) {
          logInfo('⚠️ Realtime profile stream error: $error');
        },
      );
    } catch (e) {
      logInfo('⚠️ Failed to setup profile realtime stream: $e');
    }

    // Listen to message changes for active conversations
    for (final conversationId in _conversationMemoryCache.keys) {
      _setupMessageListener(conversationId);
    }
  }

  /// Handle profile updates from real-time
  void _handleProfileUpdates(List<Map<String, dynamic>> data) {
    bool hasConversationChanges = false;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    for (final profileData in data) {
      final updatedUserId = profileData['id'] as String?;
      if (updatedUserId == null) continue;

      // Update profile cache manager
      final profileCacheManager = ProfileCacheManager();
      profileCacheManager.updateProfileFromRealtime(updatedUserId, profileData);

      // به‌روزرسانی آواتار و نام کاربر در مکالمات مربوطه
      final newAvatarUrl = profileData['avatar_url'] as String?;
      final newUsername = profileData['username'] as String?;
      final newFullName = profileData['full_name'] as String?;

      // جستجوی تمام مکالماتی که این کاربر در آن‌ها شرکت دارد
      for (final entry in _conversationMemoryCache.entries) {
        final conversation = entry.value;
        
        // بررسی اینکه آیا این کاربر، کاربر مقابل در این مکالمه است
        if (conversation.otherUserId == updatedUserId) {
          // به‌روزرسانی اطلاعات کاربر در مکالمه
          final updatedConversation = conversation.copyWith(
            otherUserAvatar: newAvatarUrl ?? conversation.otherUserAvatar,
            otherUserName: newUsername ?? newFullName ?? conversation.otherUserName,
          );
          _conversationMemoryCache[entry.key] = updatedConversation;
          hasConversationChanges = true;
        }
      }
    }

    // اگر تغییری در مکالمات ایجاد شد، broadcast کن
    if (hasConversationChanges) {
      _broadcastConversationUpdates();
      _saveToDisk();
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
      logInfo('⚠️ Failed to setup message listener for $conversationId: $e');
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
      logInfo('⚠️ Initial sync failed: $e');
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
      logInfo('⚠️ Background sync failed: $e');
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

        if (existing == null) {
          // مکالمه جدید - اضافه کن
          _conversationMemoryCache[conversation.id] = conversation;
          hasChanges = true;
        } else if (existing.updatedAt.isBefore(conversation.updatedAt)) {
          // مکالمه به‌روز شده - اما اطلاعات پروفایل را از کش حفظ کن
          final updatedConversation = conversation.copyWith(
            // حفظ اطلاعات پروفایل از کش اگر در سرور موجود نیست
            otherUserName: conversation.otherUserName?.isNotEmpty == true
                ? conversation.otherUserName
                : existing.otherUserName,
            otherUserAvatar: conversation.otherUserAvatar?.isNotEmpty == true
                ? conversation.otherUserAvatar
                : existing.otherUserAvatar,
            otherUserId: conversation.otherUserId ?? existing.otherUserId,
          );
          _conversationMemoryCache[conversation.id] = updatedConversation;
          hasChanges = true;
        }
        // اگر مکالمه به‌روز نشده، هیچ کاری نکن (کش را حفظ کن)
      }

      if (hasChanges) {
        _broadcastConversationUpdates();
        _saveToDisk();
      }

      _lastFetch['conversations'] = DateTime.now();
    } catch (e) {
      logInfo('⚠️ Failed to sync conversations: $e');
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
      logInfo('⚠️ Failed to sync messages for $conversationId: $e');
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
        logInfo('⚠️ Failed to upload message $messageId: $e');
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
    // ✅ همیشه initial emit کن (حتی اگر خالی باشد) تا UI بداند که stream آماده است
    // اگر کش موجود است، بلافاصله emit کن
    if (_conversationMemoryCache.isNotEmpty) {
      // استفاده از microtask برای اطمینان از اینکه بعد از initialization emit می‌شود
      Future.microtask(() => _broadcastConversationUpdates());
    } else {
      // اگر کش خالی است، empty list emit کن تا UI بداند که stream آماده است
      Future.microtask(() {
        if (!_conversationStream.isClosed) {
          _conversationStream.add([]);
        }
      });
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
      // اطمینان از اینکه isMe به درستی set شده است
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        return optimizedResult.map((message) {
          // بررسی و اصلاح isMe بر اساس currentUserId فعلی
          final correctIsMe = message.senderId == currentUserId;
          if (message.isMe != correctIsMe) {
            return message.copyWith(isMe: correctIsMe);
          }
          return message;
        }).toList();
      }
      return optimizedResult;
    }

    // Fallback to memory cache
    final memoryResult = _messageMemoryCache[conversationId] ?? [];
    if (memoryResult.isNotEmpty) {
      // مرتب‌سازی از جدید به قدیمی برای نمایش صحیح در لیست reverse
      final sortedResult = List<MessageModel>.from(memoryResult)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // اصلاح isMe برای همه پیام‌ها بر اساس currentUserId فعلی
      final currentUserId = supabase.auth.currentUser?.id;
      final correctedResult = currentUserId != null
          ? sortedResult.map((message) {
              // بررسی و اصلاح isMe بر اساس currentUserId فعلی
              final correctIsMe = message.senderId == currentUserId;
              if (message.isMe != correctIsMe) {
                return message.copyWith(isMe: correctIsMe);
              }
              return message;
            }).toList()
          : sortedResult;

      // Cache in performance optimizer for next time
      _performanceOptimizer.cacheMessages(conversationId, correctedResult);
      return correctedResult;
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
    logInfo('🧹 Advanced Cache System disposed');
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

  /// Clear messages for a specific conversation
  Future<void> clearConversationMessages(String conversationId) async {
    try {
      // Remove from memory cache
      _messageMemoryCache.remove(conversationId);

      // Close stream if exists
      _messageStreams[conversationId]?.close();
      _messageStreams.remove(conversationId);

      // Remove from disk cache
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = 'cached_messages_$conversationId';
      await prefs.remove(messagesKey);

      logInfo('✅ Cleared messages for conversation: $conversationId');
    } catch (e) {
      logInfo('❌ Error clearing conversation messages: $e');
    }
  }

  /// Delete a specific message from cache
  Future<void> deleteMessageFromCache(
      String conversationId, String messageId) async {
    try {
      final messages = _messageMemoryCache[conversationId];
      if (messages != null) {
        messages.removeWhere((m) => m.id == messageId);

        // Broadcast updated messages
        _broadcastMessageUpdates(conversationId, messages);

        // Update conversation if this was the last message
        final conversation = _conversationMemoryCache[conversationId];
        if (conversation != null && messages.isNotEmpty) {
          final latestMessage = messages.first;
          final updatedConversation = conversation.copyWith(
            lastMessage: latestMessage.content,
            lastMessageTime: latestMessage.createdAt,
            updatedAt: latestMessage.createdAt,
          );
          _conversationMemoryCache[conversationId] = updatedConversation;
          _broadcastConversationUpdates();
        }

        // Save to disk
        _saveToDisk();

        logInfo('✅ Message deleted from cache: $messageId');
      }
    } catch (e) {
      logInfo('⚠️ Error deleting message from cache: $e');
    }
  }

  /// Delete multiple messages efficiently
  Future<void> deleteMultipleMessagesFromCache(
    String conversationId,
    List<String> messageIds,
  ) async {
    try {
      final messages = _messageMemoryCache[conversationId];
      if (messages != null) {
        messages.removeWhere((m) => messageIds.contains(m.id));

        // Broadcast updated messages
        _broadcastMessageUpdates(conversationId, messages);

        // Update conversation if needed
        final conversation = _conversationMemoryCache[conversationId];
        if (conversation != null && messages.isNotEmpty) {
          final latestMessage = messages.first;
          final updatedConversation = conversation.copyWith(
            lastMessage: latestMessage.content,
            lastMessageTime: latestMessage.createdAt,
            updatedAt: latestMessage.createdAt,
          );
          _conversationMemoryCache[conversationId] = updatedConversation;
          _broadcastConversationUpdates();
        }

        // Save to disk
        _saveToDisk();

        logInfo('✅ ${messageIds.length} messages deleted from cache');
      }
    } catch (e) {
      logInfo('⚠️ Error deleting multiple messages from cache: $e');
    }
  }

  /// Clean up old messages (older than specified date) to free memory
  Future<void> cleanupOldMessages(
      {Duration olderThan = const Duration(days: 30)}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan);
      int totalDeleted = 0;

      for (final entry in _messageMemoryCache.entries) {
        final conversationId = entry.key;
        final messages = entry.value;

        final initialCount = messages.length;
        messages.removeWhere((m) => m.createdAt.isBefore(cutoffDate));

        final deletedCount = initialCount - messages.length;
        totalDeleted += deletedCount;

        if (deletedCount > 0) {
          _broadcastMessageUpdates(conversationId, messages);
        }
      }

      if (totalDeleted > 0) {
        _saveToDisk();
        logInfo('🧹 Cleaned up $totalDeleted old messages');
      }
    } catch (e) {
      logInfo('⚠️ Error during cleanup: $e');
    }
  }

  /// Sync message deletion from server to cache (for remote deletions)
  Future<void> syncMessageDeletion(
      String conversationId, List<String> deletedMessageIds) async {
    try {
      await deleteMultipleMessagesFromCache(conversationId, deletedMessageIds);
      logInfo('✅ Synced deletion of ${deletedMessageIds.length} messages');
    } catch (e) {
      logInfo('⚠️ Error syncing message deletion: $e');
    }
  }

  /// Clear all cached messages
  Future<void> clearAllMessages() async {
    try {
      // Clear memory cache
      _messageMemoryCache.clear();

      // Close all message streams
      for (final stream in _messageStreams.values) {
        stream.close();
      }
      _messageStreams.clear();

      // Clear disk cache
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cached_messages_')) {
          await prefs.remove(key);
        }
      }

      logInfo('✅ Cleared all cached messages');
    } catch (e) {
      logInfo('❌ Error clearing all messages: $e');
    }
  }

  /// Update a conversation in cache (for enriched data like allowProfileZoom)
  Future<void> updateConversationInCache(ConversationModel conversation) async {
    try {
      // Update memory cache
      _conversationMemoryCache[conversation.id] = conversation;
      
      // Broadcast update
      _broadcastConversationUpdates();
      
      // Save to disk
      await _saveToDisk();
      
      logInfo('✅ Updated conversation in cache: ${conversation.id}');
    } catch (e) {
      logInfo('❌ Error updating conversation in cache: $e');
    }
  }

  /// Remove a specific conversation
  Future<void> removeConversation(String conversationId) async {
    try {
      // Remove from memory cache
      _conversationMemoryCache.remove(conversationId);
      _messageMemoryCache.remove(conversationId);

      // Close stream if exists
      _messageStreams[conversationId]?.close();
      _messageStreams.remove(conversationId);

      // Remove from disk cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_conversations');
      await prefs.remove('cached_messages_$conversationId');

      // Re-save conversations without the removed one
      await _saveToDisk();

      logInfo('✅ Removed conversation: $conversationId');
    } catch (e) {
      logInfo('❌ Error removing conversation: $e');
    }
  }
}
