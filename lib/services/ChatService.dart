import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../DB/conversation_cache_service_wrapper.dart';
import '../DB/message_cache_service_wrapper.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../view/Exeption/app_exceptions.dart';
import 'user_friendly_error_handler.dart';
import '/main.dart';
import 'uploadImageChatService.dart';
import 'uploadAudioChatService.dart';
import 'profile_service.dart';

class ChatService {
  final SupabaseClient _supabase = supabase;
  final ConversationCacheService _conversationCache =
      ConversationCacheService();
  final MessageCacheService _messageCache = MessageCacheService();
  final ProfileService _profileService = ProfileService();

  // حذف فایل پیوست چت از استوریج (بر اساس نوع)
  Future<void> _tryDeleteChatAttachment(
    String? attachmentType,
    String? attachmentUrl,
  ) async {
    if (attachmentUrl == null || attachmentUrl.isEmpty) return;
    try {
      if (attachmentType == 'image') {
        await ChatImageUploadService.deleteChatImage(attachmentUrl);
      } else if (attachmentType == 'audio') {
        await ChatAudioUploadService.deleteChatAudio(attachmentUrl);
      } else {
        // تلاش fallback در صورت نامشخص بودن نوع
        final deletedImage =
            await ChatImageUploadService.deleteChatImage(attachmentUrl);
        if (!deletedImage) {
          await ChatAudioUploadService.deleteChatAudio(attachmentUrl);
        }
      }
    } catch (e) {
      print('هشدار: حذف فایل پیوست چت ناموفق بود: $e');
    }
  }

  // متغیر static برای نگهداری conversationId فعال و آخرین messageId دیده‌شده
  // A constant to represent a cleared conversation state
  static const String clearedHistoryPlaceholder = '[conversation_cleared]';

  static String? activeConversationId;
  // static String? lastNotifiedMessageId;

  // اضافه شد: برای حل مشکل race condition در خواندن وضعیت خوانده‌نشده
  // ignore: unused_field
  static final Map<String, DateTime> _recentReadConversations =
      {}; // reserved for future read-status logic

  // اضافه شد: قفل درحال انجام برای جلوگیری از ساخت مکالمه تکراری بین دو کاربر (روی کلاینت)
  // کلید بر اساس جفت مرتب‌شده از userId ها ساخته می‌شود
  static final Map<String, Future<String>> _pendingConversationFutures = {};

  // تولید کلید یکتا برای جفت کاربرها بدون توجه به ترتیب
  static String _pairKey(String a, String b) {
    return (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
  }

  // // نگهداری لیست پیام‌هایی که نوتیفیکیشن گرفته‌اند (در یک session)
  // static final Set<String> _notifiedMessageIds = {};

  // دریافت تمامی مکالمات کاربر فعلی - بهینه شده با ProfileService
  Future<List<ConversationModel>> getConversations() async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      // بررسی وضعیت آنلاین
      final isOnline = kIsWeb ? true : await isDeviceOnline();

      // ابتدا سعی می‌کنیم مکالمات را از کش بگیریم
      final cachedConversations =
          await _conversationCache.getCachedConversations(userId);

      // اگر آفلاین هستیم و کش داریم، از کش استفاده می‌کنیم
      if (!isOnline && cachedConversations.isNotEmpty) {
        return cachedConversations;
      }

      if (isOnline) {
        // دریافت شناسه‌های مکالماتی که کاربر در آنها شرکت دارد
        final participantsResponse = await _supabase
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', userId);

        if (participantsResponse.isEmpty) return [];

        final conversationIds = participantsResponse
            .map((e) => e['conversation_id'] as String)
            .toList();

        // دریافت مکالمات به صورت باتچ
        final conversationsResponse = await _supabase
            .from('conversations')
            .select()
            .inFilter('id', conversationIds)
            .order('updated_at', ascending: false);

        // دریافت تمام شرکت‌کنندگان به صورت باتچ برای بهبود عملکرد
        final participantsResponseAll = await _supabase
            .from('conversation_participants')
            .select('*, profiles:user_id(username, full_name, avatar_url)')
            .inFilter('conversation_id', conversationIds);

        // ایجاد مپ از conversation_id به لیست شرکت‌کنندگان
        final Map<String, List<Map<String, dynamic>>>
            participantsByConversation = {};
        for (final participant in participantsResponseAll) {
          final convId = participant['conversation_id'] as String;
          if (participantsByConversation[convId] == null) {
            participantsByConversation[convId] = [];
          }
          participantsByConversation[convId]!.add(participant);
        }

        // استخراج تمام userId های منحصر به فرد برای دریافت پروفایل
        final allUserIds = participantsResponseAll
            .map((p) => p['user_id'] as String)
            .toSet()
            .toList();

        // پیش‌بارگذاری پروفایل‌ها با ProfileService
        await _profileService.preloadProfiles(allUserIds);

        // ساخت مکالمات با استفاده از پروفایل‌های کش شده
        final conversationsFromServer = await Future.wait(
          conversationsResponse.map((json) async {
            final conversationId = json['id'] as String;
            final participantsJson =
                participantsByConversation[conversationId] ?? [];

            // ساخت شرکت‌کنندگان با استفاده از پروفایل‌های کش شده
            final participants = participantsJson.map((participant) {
              final String pUserId = participant['user_id'] as String;

              // استفاده از پروفایل کش شده
              final cachedProfile = _profileService.getCachedProfile(pUserId);

              final updatedParticipant = {...participant};
              if (cachedProfile != null) {
                updatedParticipant['profiles'] = {
                  'username': cachedProfile.username,
                  'full_name': cachedProfile.fullName,
                  'avatar_url': cachedProfile.avatarUrl,
                };
              }

              return ConversationParticipantModel.fromJson(updatedParticipant);
            }).toList();

            // پیدا کردن کاربر دیگر در چت
            String? otherUserId;
            for (final participant in participantsJson) {
              if (participant['user_id'] != userId) {
                otherUserId = participant['user_id'] as String?;
                break;
              }
            }

            // دریافت پروفایل طرف مقابل از کش (یا دریافت از سرور اگر در کش نباشد)
            final otherProfile = otherUserId != null
                ? _profileService.getCachedProfile(otherUserId) ??
                    await _profileService.getProfile(otherUserId)
                : null;

            // وضعیت کاربر فعلی
            String? myLastRead;
            bool currentUserIsMuted = false;
            bool currentUserIsArchived = false;
            for (final participant in participantsJson) {
              if (participant['user_id'] == userId) {
                myLastRead = participant['last_read_time'];
                currentUserIsMuted = participant['is_muted'] ?? false;
                currentUserIsArchived = participant['is_archived'] ?? false;
                break;
              }
            }

            // بررسی پیام‌های خوانده نشده
            bool hasUnreadMessages = false;
            if (json['last_message_time'] != null && myLastRead != null) {
              final lastMessageTime = DateTime.parse(json['last_message_time']);
              final lastReadTime = DateTime.parse(myLastRead);
              hasUnreadMessages = lastMessageTime.isAfter(lastReadTime);
            }

            // دریافت آخرین پیام غیر مخفی
            final lastMessageQuery = await _supabase
                .from('messages')
                .select()
                .eq('conversation_id', conversationId)
                .not(
                  'id',
                  'in',
                  (await _supabase
                          .from('hidden_messages')
                          .select('message_id')
                          .eq('user_id', userId))
                      .map((e) => e['message_id'])
                      .toList(),
                )
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (lastMessageQuery != null) {
              json['last_message'] = lastMessageQuery['content'] as String?;
              json['last_message_time'] = lastMessageQuery['created_at'];
              json['updated_at'] = lastMessageQuery['created_at'];
            }

            final conversation = ConversationModel.fromJson(
              json,
              currentUserId: userId,
            ).copyWith(
              participants: participants,
              otherUserName: otherProfile?.displayName ??
                  otherProfile?.username ??
                  'کاربر ناشناس',
              otherUserAvatar: otherProfile?.avatar,
              otherUserId: otherUserId,
              hasUnreadMessages: hasUnreadMessages,
              unreadCount: 0,
              isPinned: (await _conversationCache.getConversation(
                    conversationId,
                    userId,
                  ))
                      ?.isPinned ??
                  false,
              isMuted: currentUserIsMuted,
              isArchived: currentUserIsArchived,
            );

            // ذخیره در کش
            await _conversationCache.updateConversation(conversation, userId);

            return conversation;
          }),
        );

        // ذخیره در کش
        for (final conversation in conversationsFromServer) {
          await _conversationCache.cacheConversation(conversation, userId);
        }

        return conversationsFromServer;
      }

      // اگر آفلاین هستیم، از کش استفاده می‌کنیم
      return cachedConversations;
    } catch (e) {
      // فال‌بک به کش
      final fallbackCachedConversations =
          await _conversationCache.getCachedConversations(userId);
      if (fallbackCachedConversations.isNotEmpty) {
        print('خطا در دریافت مکالمات از سرور. استفاده از کش: $e');
        return fallbackCachedConversations;
      }

      UserFriendlyErrorHandler.logError(e, context: 'conversations');
      throw AppException(
        userFriendlyMessage: UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'conversations'),
        technicalMessage: 'خطا در دریافت مکالمات: $e',
      );
    }
  }

  // Request throttling
  final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _requestThrottleDuration = Duration(milliseconds: 500);

  /// Throttle requests to prevent excessive server calls
  bool _shouldThrottleRequest(String requestKey) {
    final lastRequest = _lastRequestTime[requestKey];
    if (lastRequest == null) return false;

    final timeSinceLastRequest = DateTime.now().difference(lastRequest);
    return timeSinceLastRequest < _requestThrottleDuration;
  }

  /// Mark request as made
  void _markRequestMade(String requestKey) {
    _lastRequestTime[requestKey] = DateTime.now();
  }

  // متد کمکی برای بررسی وضعیت آنلاین بودن
  Future<bool> isDeviceOnline() async {
    if (kIsWeb) {
      // روی وب همیشه آنلاین فرض کن
      return true;
    }
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Renamed to avoid conflict with the other deleteConversation method
  Future<void> adminDeleteConversation(String conversationId) async {
    // حذف از Supabase
    // ۱. اول رکوردهای conversation_participants را حذف کن (تا ارور Constraint نده)
    await _supabase
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', conversationId);

    // ۲. همه پیام‌های این مکالمه را حذف کن (در صورت نیاز)
    await _supabase
        .from('messages')
        .delete()
        .eq('conversation_id', conversationId);

    // ۳. در نهایت خود conversation را حذف کن
    await _supabase.from('conversations').delete().eq('id', conversationId);

    // حذف از کش لوکال Drift
    await _conversationCache.removeConversation(
      conversationId,
      _supabase.auth.currentUser!.id,
    ); // این مربوط به کش مکالمه است

    // حذف پیام‌های کش‌شده مربوطه هم (در صورت وجود)
    await _messageCache.clearConversationMessages(
        conversationId, _supabase.auth.currentUser!.id); // استفاده از متد صحیح
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? localId, // اضافه کردن پارامتر localId
  }) async {
    if (_supabase.auth.currentUser == null) {
      throw AppException(
        userFriendlyMessage: 'کاربر وارد نشده است',
        technicalMessage: 'No authenticated user',
      );
    }

    try {
      final userId = _supabase.auth.currentUser!.id;

      // ساخت داده‌های پیام برای insert مستقیم
      final messageData = {
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'reply_to_message_id': replyToMessageId,
        'reply_to_content': replyToContent,
        'reply_to_sender_name': replyToSenderName,
        'local_id': localId, // شناسه محلی برای تطبیق در کلاینت
        'is_sent': true, // فرض بر اینکه سرور با موفقیت دریافت می‌کند
        'is_pending': false, // دیگر در حالت انتظار نیست
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      print('📝 ارسال پیام به سرور (insert مستقیم): $messageData');

      // ارسال پیام به سرور با insert مستقیم
      final response = await _supabase
          .from('messages')
          .insert(messageData)
          .select()
          .single();

      print('✅ پیام با موفقیت ارسال شد');

      // *** اضافه شد: رفرش کردن اطلاعات مکالمه در کش پس از ارسال پیام ***
      await refreshConversation(conversationId);

      // دریافت اطلاعات پروفایل کاربر
      final profileResponse =
          await _supabase.from('profiles').select().eq('id', userId).single();

      // اطمینان از اینکه isSent و isPending به درستی از پاسخ سرور خوانده می‌شوند یا ست می‌شوند
      return MessageModel.fromJson(response, currentUserId: userId).copyWith(
        senderName: profileResponse['username'] ?? profileResponse['full_name'],
        senderAvatar: profileResponse['avatar_url'],
        isSent: true, // اطمینان از اینکه پیام ارسالی isSent=true دارد
        isPending: false, // و isPending=false
      );
    } catch (e) {
      print('❌ خطا در ارسال پیام: $e');
      throw AppException(
        userFriendlyMessage: 'ارسال پیام با مشکل مواجه شد',
        technicalMessage: 'Error in sendMessage: $e',
      );
    }
  }

  Future<void> cleanOldCache() async {
    try {
      // پاک کردن مکالمات قدیمی‌تر از یک ماه
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      final userId = _supabase.auth.currentUser!.id;
      final conversations =
          await _conversationCache.getCachedConversations(userId);
      for (final conversation in conversations) {
        if (conversation.updatedAt.isBefore(oneMonthAgo)) {
          await _conversationCache.removeConversation(conversation.id, userId);
          await _messageCache.clearConversationMessages(
              conversation.id, userId);
        }
      }
    } catch (e) {
      print('خطا در پاک کردن کش قدیمی: $e');
    }
  }

  // همگام‌سازی داده‌های کش با سرور
  Future<void> syncCache() async {
    try {
      final isOnline = await isDeviceOnline();
      if (!isOnline) return;
      final userId = _supabase.auth.currentUser!.id;
      // دریافت مکالمات به‌روز
      await getConversations();
      // سپس برای هر مکالمه، پیام‌های اخیر را دریافت می‌کنیم
      final conversations =
          await _conversationCache.getCachedConversations(userId);
      for (final conversation in conversations) {
        await getMessages(conversation.id, limit: 20, offset: 0);
      }
      print('همگام‌سازی کش با موفقیت انجام شد');
    } catch (e) {
      print('خطا در همگام‌سازی کش: $e');
    }
  }

  // لیست پیام‌های در صف ارسال
  final List<Map<String, dynamic>> _pendingMessages = [];

  // ارسال پیام آفلاین
  Future<MessageModel> sendOfflineMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final isOnline = await isDeviceOnline();
      // ساخت یک پیام موقت با ID موقت
      final temporaryId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final temporaryMessage = MessageModel(
        id: temporaryId,
        conversationId: conversationId,
        senderId: userId,
        content: content,
        createdAt: DateTime.now(),
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        isRead: false,
        isSent: false, // هنوز ارسال نشده است
        senderName: 'من', // می‌توانید از اطلاعات کاربر فعلی استفاده کنید
        senderAvatar: null,
        isMe: true,
        replyToMessageId: replyToMessageId,
        replyToContent: replyToContent,
        replyToSenderName: replyToSenderName,
      );
      // ذخیره در کش
      await _messageCache.cacheMessage(temporaryMessage, userId);
      // بروزرسانی مکالمه در کش
      final conversation = await _conversationCache.getConversation(
        conversationId,
        userId,
      );
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: content,
          lastMessageTime: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _conversationCache.updateConversation(
            updatedConversation, userId);
      }
      // اگر آنلاین هستیم، همان لحظه ارسال می‌کنیم
      if (isOnline) {
        return await sendMessage(
          conversationId: conversationId,
          content: content,
          attachmentUrl: attachmentUrl,
          attachmentType: attachmentType,
          replyToMessageId: replyToMessageId,
          replyToContent: replyToContent,
          replyToSenderName: replyToSenderName,
        );
      }
      // اگر آفلاین هستیم، به صف اضافه می‌کنیم
      _pendingMessages.add({
        'temporaryId': temporaryId,
        'conversationId': conversationId,
        'content': content,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'replyToMessageId': replyToMessageId,
        'replyToContent': replyToContent,
        'replyToSenderName': replyToSenderName,
      });
      // در صف ذخیره می‌کنیم تا بعداً ارسال شود
      return temporaryMessage;
    } catch (e) {
      print('خطا در ارسال پیام آفلاین: $e');
      throw AppException(
        userFriendlyMessage: 'ارسال پیام با مشکل مواجه شد',
        technicalMessage: 'خطا در ارسال پیام آفلاین: $e',
      );
    }
  }

  // ارسال پیام‌های در صف
  Future<void> sendPendingMessages() async {
    if (_pendingMessages.isEmpty) return;
    final isOnline = await isDeviceOnline();
    if (!isOnline) return;
    final pendingMessagesCopy = List<Map<String, dynamic>>.from(
      _pendingMessages,
    );
    for (final pendingMessage in pendingMessagesCopy) {
      try {
        final message = await sendMessage(
          conversationId: pendingMessage['conversationId'],
          content: pendingMessage['content'],
          attachmentUrl: pendingMessage['attachmentUrl'],
          attachmentType: pendingMessage['attachmentType'],
          replyToMessageId: pendingMessage['replyToMessageId'],
          replyToContent: pendingMessage['replyToContent'],
          replyToSenderName: pendingMessage['replyToSenderName'],
          localId: pendingMessage['temporaryId'] as String?,
        );
        await _messageCache.replaceTempMessage(
          message,
          message,
        );
        _pendingMessages.removeWhere(
          (msg) => msg['temporaryId'] == pendingMessage['temporaryId'],
        );
      } catch (e) {
        print('خطا در ارسال پیام در صف: $e');
      }
    }
  }

  // اضافه شد: متد جدید برای یافتن مکالمه موجود بدون ایجاد مکالمه جدید
  Future<String?> findExistingConversation(String otherUserId) async {
    final userId = _supabase.auth.currentUser!.id;

    // جلوگیری از جستجو با خود کاربر
    if (userId == otherUserId) {
      return null;
    }

    try {
      // 1) بررسی روی سرور با RPC (ترجیحی)
      try {
        final existingQuery = await _supabase.rpc(
          'find_conversation_between_users',
          params: {'user1': userId, 'user2': otherUserId},
        );
        if (existingQuery != null && existingQuery.isNotEmpty) {
          print('مکالمه موجود در سرور یافت شد: ${existingQuery[0]['id']}');
          return existingQuery[0]['id'];
        }
      } catch (e) {
        print('find_conversation_between_users RPC failed: $e');
      }

      // 2) جستجو در کش محلی
      try {
        final cached = await _conversationCache.getCachedConversations(userId);
        for (final c in cached) {
          if (c.otherUserId == otherUserId) {
            print('مکالمه موجود در کش یافت شد: ${c.id}');
            return c.id;
          }
        }
      } catch (e) {
        print('خطا در جستجوی کش: $e');
      }

      // 3) جستجو در سرور (از طریق getConversations)
      try {
        final all = await getConversations();
        for (final c in all) {
          if (c.otherUserId == otherUserId) {
            print(
                'مکالمه موجود در سرور (از طریق getConversations) یافت شد: ${c.id}');
            return c.id;
          }
        }
      } catch (e) {
        print('خطا در جستجوی سرور: $e');
      }

      print('هیچ مکالمه موجودی یافت نشد');
      return null;
    } catch (e) {
      print('خطا در findExistingConversation: $e');
      return null;
    }
  }

  Future<String> createOrGetConversation(String otherUserId) async {
    final userId = _supabase.auth.currentUser!.id;

    // جلوگیری از ایجاد مکالمه با خود کاربر
    if (userId == otherUserId) {
      throw Exception('کاربر نمی‌تواند با خودش گفتگو ایجاد کند.');
    }

    final key = _pairKey(userId, otherUserId);
    print(
        'createOrGetConversation: جستجو برای کاربر $otherUserId (کلید: $key)');

    // اگر درحال ساخت/واکشی همین مکالمه هستیم، همان Future را برگردان
    final inFlight = _pendingConversationFutures[key];
    if (inFlight != null) {
      print('createOrGetConversation: در حال انجام برای کلید $key');
      return await inFlight;
    }

    Future<String> task() async {
      try {
        // ابتدا بررسی کن که آیا مکالمه موجود است
        final existingId = await findExistingConversation(otherUserId);
        if (existingId != null && existingId.isNotEmpty) {
          print('createOrGetConversation: مکالمه موجود یافت شد: $existingId');
          return existingId;
        }

        print(
            'createOrGetConversation: هیچ مکالمه موجودی یافت نشد، ایجاد مکالمه جدید...');

        // اگر هیچ گفتگویی پیدا نشد، مکالمه جدید بساز
        final newConversation =
            await _supabase.from('conversations').insert({}).select().single();

        final conversationId = newConversation['id'];
        print('createOrGetConversation: مکالمه جدید ایجاد شد: $conversationId');

        // افزودن کاربران به مکالمه
        await _supabase.from('conversation_participants').insert([
          {
            'conversation_id': conversationId,
            'user_id': userId,
            'last_read_time': DateTime.now().toIso8601String(),
          },
          {
            'conversation_id': conversationId,
            'user_id': otherUserId,
            'last_read_time': DateTime.now().toIso8601String(),
          },
        ]);

        print(
            'createOrGetConversation: کاربران به مکالمه $conversationId اضافه شدند');

        // بروزرسانی کش برای جلوگیری از ساخت مجدد
        await refreshConversation(conversationId);
        return conversationId;
      } catch (e) {
        print('createOrGetConversation: خطا در ایجاد مکالمه: $e');
        throw AppException(
          userFriendlyMessage: 'مشکل در ایجاد گفتگو',
          technicalMessage: 'خطا در createOrGetConversation: $e',
        );
      }
    }

    final future = task();
    _pendingConversationFutures[key] = future;
    try {
      final result = await future;
      print('createOrGetConversation: عملیات با موفقیت انجام شد: $result');
      return result;
    } finally {
      _pendingConversationFutures.remove(key);
    }
  }

  // ایجاد مکالمه جدید
  Future<ConversationModel> createConversation(String otherUserId) async {
    try {
      // ابتدا از متد ایمن createOrGet استفاده می‌کنیم تا هرگز مکالمه تکراری ایجاد نشود
      final conversationId = await createOrGetConversation(otherUserId);

      // سپس جزئیات مکالمه را واکشی می‌کنیم
      final conversationResponse = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();

      // دریافت شرکت‌کنندگان و اطلاعات کاربر دیگر
      final participantsJson = await _supabase
          .from('conversation_participants')
          .select('*, profiles:user_id(*)')
          .eq('conversation_id', conversationId);

      final participants = participantsJson
          .map((e) => ConversationParticipantModel.fromJson(e))
          .toList();

      Map<String, dynamic>? otherParticipant;
      try {
        otherParticipant = participantsJson
            .cast<Map<String, dynamic>>()
            .firstWhere((e) => e['user_id'] == otherUserId);
      } catch (_) {
        otherParticipant = null;
      }

      String? otherName;
      String? otherAvatar;
      if (otherParticipant != null) {
        final profilesField = otherParticipant['profiles'];
        final Map<String, dynamic> prof = profilesField is Map<String, dynamic>
            ? profilesField
            : <String, dynamic>{};
        otherName = prof['username'] as String?;
        otherAvatar = prof['avatar_url'] as String?;
      } else {
        // fallback: پروفایل طرف مقابل را مستقیم بخوان
        try {
          final otherUserResponse = await _supabase
              .from('profiles')
              .select()
              .eq('id', otherUserId)
              .maybeSingle();
          otherName = otherUserResponse?['username'] as String?;
          otherAvatar = otherUserResponse?['avatar_url'] as String?;
        } catch (_) {}
      }

      return ConversationModel.fromJson(conversationResponse).copyWith(
        participants: participants,
        otherUserName: otherName ?? 'کاربر',
        otherUserAvatar: otherAvatar,
        otherUserId: otherUserId,
      );
    } catch (e) {
      throw Exception('خطا در ایجاد مکالمه: $e');
    }
  }

  // اصلاح متد updateUserOnlineStatus برای بروزرسانی دقیق‌تر
  // به‌روزرسانی زمان آخرین فعالیت کاربر
  Future<void> updateUserOnlineStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('updateUserOnlineStatus: کاربر وارد نشده است');
      return;
    }

    try {
      // اطلاعات دیباگ
      print('updateUserOnlineStatus: به‌روزرسانی وضعیت برای کاربر: $userId');

      // به‌روزرسانی is_online و last_online
      await _supabase.from('profiles').update({
        'last_online': DateTime.now().toUtc().toIso8601String(),
        'is_online': true,
      }).eq('id', userId);

      print('updateUserOnlineStatus: وضعیت آنلاین کاربر به‌روزرسانی شد');
    } catch (e) {
      print('updateUserOnlineStatus: خطا در به‌روزرسانی وضعیت آنلاین: $e');
    }
  }

  // دریافت زمان آخرین فعالیت کاربر
  Future<DateTime?> getUserLastOnline(String userId) async {
    try {
      // ابتدا تنظیم نمایش آخرین بازدید را برای کاربر مقابل بخوان
      final settings = await _supabase
          .from('user_settings')
          .select('last_seen_visibility')
          .eq('user_id', userId)
          .maybeSingle();

      final visibility = settings?['last_seen_visibility'] as String?;

      // اگر هیچکس، برنگردان
      if (visibility == 'nobody') {
        return null;
      }

      // اگر فقط مخاطبین من، بررسی کن آیا کاربر فعلی دنبالکننده است یا ارتباط دارد
      if (visibility == 'my_contacts') {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) return null;
        // تعریف مخاطب: فالو دوطرفه
        final otherFollowsMe = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', userId)
            .eq('following_id', currentUserId)
            .maybeSingle();
        if (otherFollowsMe == null) return null;
        final iFollowOther = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUserId)
            .eq('following_id', userId)
            .maybeSingle();
        if (iFollowOther == null) return null;
      }

      // خواندن آخرین بازدید از پروفایل
      final response = await _supabase
          .from('profiles')
          .select('last_online')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['last_online'] != null) {
        return DateTime.parse(response['last_online']);
      }
      return null;
    } catch (e) {
      print('خطا در دریافت زمان آخرین فعالیت: $e');
      return null;
    }
  }

  // بررسی آنلاین بودن کاربر
  Future<bool> isUserOnline(String userId) async {
    try {
      // ابتدا تنظیمات نمایش آخرین بازدید را برای کاربر مقابل بخوان
      final settings = await _supabase
          .from('user_settings')
          .select('last_seen_visibility')
          .eq('user_id', userId)
          .maybeSingle();

      final visibility = settings?['last_seen_visibility'] as String?;

      // اگر هیچکس، همیشه آفلاین نشان بده
      if (visibility == 'nobody') {
        return false;
      }

      // اگر فقط مخاطبین من، بررسی کن آیا کاربر فعلی مخاطب است
      if (visibility == 'my_contacts') {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) return false;

        // تعریف مخاطب: فالو دوطرفه
        final otherFollowsMe = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', userId)
            .eq('following_id', currentUserId)
            .maybeSingle();
        if (otherFollowsMe == null) return false;

        final iFollowOther = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUserId)
            .eq('following_id', userId)
            .maybeSingle();
        if (iFollowOther == null) return false;
      }

      // اگر تنظیمات اجازه نمایش می‌دهد، وضعیت فنی آنلاین بودن را بررسی کن
      final response = await _supabase
          .from('profiles')
          .select('is_online, last_online')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('isUserOnline: اطلاعات برای کاربر $userId یافت نشد');
        return false;
      }

      final bool isOnline = response['is_online'] ?? false;
      final String? lastOnlineStr = response['last_online'];

      // اگر کاربر آنلاین نیست یا آخرین فعالیت ثبت نشده، آفلاین محسوب می‌شود
      if (!isOnline || lastOnlineStr == null) {
        return false;
      }

      // بررسی زمان آخرین فعالیت
      final lastOnline = DateTime.parse(lastOnlineStr);
      final now = DateTime.now().toUtc();
      final difference = now.difference(lastOnline);

      // اگر آخرین فعالیت بیش از 2 دقیقه پیش بوده، کاربر آفلاین محسوب می‌شود
      final isOnlineBased = difference.inMinutes < 2;

      // اگر کاربر بیش از 2 دقیقه غیرفعال بوده اما is_online هنوز true است، آن را به false تغییر می‌دهیم
      if (isOnline && !isOnlineBased) {
        await _supabase
            .from('profiles')
            .update({'is_online': false}).eq('id', userId);
      }

      print(
        'isUserOnline: کاربر $userId - آخرین فعالیت: $lastOnline - اختلاف: ${difference.inMinutes} دقیقه - آنلاین: $isOnlineBased',
      );

      return isOnlineBased;
    } catch (e) {
      print('خطا در بررسی وضعیت آنلاین: $e');
      return false;
    }
  }

  // حذف یک پیام
  Future<String> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final message = await _supabase
          .from('messages')
          .select('sender_id, conversation_id, attachment_url, attachment_type')
          .eq('id', messageId)
          .single();
      final conversationId = message['conversation_id'];
      final isSender = message['sender_id'] == userId;
      if (forEveryone && !isSender) {
        throw Exception('فقط فرستنده پیام می‌تواند آن را برای همه حذف کند');
      }
      if (forEveryone) {
        // ابتدا حذف فایل پیوست از استوریج (در صورت وجود)
        await _tryDeleteChatAttachment(
          message['attachment_type'] as String?,
          message['attachment_url'] as String?,
        );
        await _supabase.from('messages').delete().eq('id', messageId);
      } else {
        await _supabase.from('hidden_messages').upsert({
          'message_id': messageId,
          'user_id': userId,
          'conversation_id': conversationId,
          'hidden_at': DateTime.now().toIso8601String(),
        });
      }
      // پاکسازی فوری کش پیام
      await _messageCache.clearMessage(conversationId, messageId, userId);
      // بروزرسانی آخرین پیام مکالمه
      final hiddenMessages = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId);
      final hiddenMessageIds =
          hiddenMessages.map((e) => e['message_id']).toList();
      final lastMessage = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .not('id', 'in', hiddenMessageIds)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (lastMessage != null) {
        await _supabase.from('conversations').update({
          'last_message': lastMessage['content'],
          'last_message_time': lastMessage['created_at'],
        }).eq('id', conversationId);
      }
      // بروزرسانی کش مکالمه
      await refreshConversation(conversationId);
      // بروزرسانی فوری لیست مکالمات (برای UI)
      await _conversationCache.clearCache(userId);
      await getConversations();
      return conversationId;
    } catch (e) {
      print('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  // Add new helper method to refresh a specific conversation
  Future<void> refreshConversation(String conversationId) async {
    try {
      final conversationResponse = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();

      final userId = _supabase.auth.currentUser!.id;
      final conversation = await _getConversationWithDetails(
        conversationResponse,
        userId,
      );
      await _conversationCache.updateConversation(conversation, userId);
    } catch (e) {
      print('خطا در بروزرسانی مکالمه: $e');
    }
  }

  // Helper method to get conversation with details
  Future<ConversationModel> _getConversationWithDetails(
    Map<String, dynamic> conversationData,
    String userId,
  ) async {
    // Create a mutable copy of conversationData to update last_message fields if necessary
    final updatedConversationData = Map<String, dynamic>.from(conversationData);
    final conversationId = conversationData['id'] as String;

    // دریافت شرکت‌کنندگان
    final participantsJson = await _supabase
        .from('conversation_participants')
        .select('*') // Select all fields from conversation_participants
        .eq('conversation_id', conversationId);

    final participants = await Future.wait(
      participantsJson.map((participant) async {
        final participantUserId = participant['user_id'] as String;
        final profileJson = await _supabase
            .from('profiles')
            .select() // Select all fields from profiles
            .eq('id', participantUserId)
            .maybeSingle();

        final updatedParticipant = {...participant};
        if (profileJson != null) {
          updatedParticipant['profile'] =
              profileJson; // Nest profile data if needed by fromJson
        }
        return ConversationParticipantModel.fromJson(updatedParticipant);
      }),
    );

    // پیدا کردن کاربر دیگر در چت (برای چت دو نفره)
    // Map<String, dynamic>? otherParticipantProfile; // not used
    String? otherParticipantUserId;
    Map<String, dynamic>? otherParticipantProfileData;

    // پیدا کردن اطلاعات شرکت‌کننده فعلی برای وضعیت is_muted
    bool currentUserIsMuted = false;
    bool currentUserIsArchived = false;
    for (final pData in participantsJson) {
      if (pData['user_id'] == userId) {
        currentUserIsMuted = pData['is_muted'] ?? false;
        currentUserIsArchived = pData['is_archived'] ?? false;
        break;
      }
    }

    for (final pData in participantsJson) {
      // Iterate over the raw participantsJson
      if (pData['user_id'] != userId) {
        otherParticipantUserId = pData['user_id'] as String?;
        // Fetch profile for the other user
        if (otherParticipantUserId != null) {
          otherParticipantProfileData = await _supabase
              .from('profiles')
              .select()
              .eq('id', otherParticipantUserId)
              .maybeSingle();

          // اگر پروفایل در دیتابیس پیدا نشد، از ProfileService استفاده کنیم
          if (otherParticipantProfileData == null) {
            final profile =
                await _profileService.getProfile(otherParticipantUserId);
            if (profile != null) {
              otherParticipantProfileData = {
                'username': profile.username,
                'full_name': profile.fullName,
                'avatar_url': profile.avatarUrl,
              };
            }
          }
        }
        break;
      }
    }

    // آخرین زمان خواندن پیام توسط کاربر فعلی
    // String? myLastRead; // not used
    for (final participantData in participantsJson) {
      // Iterate over the raw participantsJson
      if (participantData['user_id'] == userId) {
        // myLastRead = participantData['last_read_time'] as String?;
        break;
      }
    }

    // دریافت آخرین پیام غیر مخفی (برای last_message and last_message_time)
    final lastMessageQuery = await _supabase
        .from('messages')
        .select('content, created_at')
        .eq('conversation_id', conversationId)
        .not(
          'id',
          'in',
          (await _supabase
                  .from('hidden_messages')
                  .select('message_id')
                  .eq('user_id', userId))
              .map((e) => e['message_id'])
              .toList(),
        )
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastMessageQuery != null) {
      String? lastContent = lastMessageQuery['content'] as String?;
      updatedConversationData['last_message'] = lastContent;
      updatedConversationData['last_message_time'] =
          lastMessageQuery['created_at'] as String?;
      updatedConversationData['updated_at'] =
          lastMessageQuery['created_at'] as String?;
    }

    // محاسبه تعداد پیام‌های خوانده‌نشده
    final int unreadCount = 0;
    final bool hasUnreadMessages = false;
    return ConversationModel.fromJson(
      updatedConversationData,
      currentUserId: userId,
    ).copyWith(
      participants: participants,
      otherUserName:
          otherParticipantProfileData?['username'] as String? ?? 'کاربر ناشناس',
      otherUserAvatar: otherParticipantProfileData?['avatar_url'] as String?,
      otherUserId: otherParticipantUserId,
      unreadCount: unreadCount,
      hasUnreadMessages: hasUnreadMessages,
      isPinned: (await _conversationCache.getConversation(
            conversationId,
            userId,
          ))
              ?.isPinned ??
          false,
      isMuted: currentUserIsMuted,
      isArchived: currentUserIsArchived,
    ); // اضافه کردن isArchived
  }

  // حذف تمام پیام‌های یک مکالمه
  Future<void> deleteAllMessages(
    String conversationId, {
    bool forEveryone = false,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    try {
      if (forEveryone) {
        // حذف فایل‌های پیوست از استوریج، سپس حذف پیام‌ها از دیتابیس
        final attachmentMessages = await _supabase
            .from('messages')
            .select('id, attachment_url, attachment_type')
            .eq('conversation_id', conversationId);

        for (final m in attachmentMessages) {
          final String? url = m['attachment_url'] as String?;
          if (url != null && url.isNotEmpty) {
            await _tryDeleteChatAttachment(
              m['attachment_type'] as String?,
              url,
            );
          }
        }
        // حذف همه پیام‌های این مکالمه از دیتابیس
        print(
            '[DEBUG] Deleting all messages for conversation: $conversationId');
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
      } else {
        // فقط برای کاربر فعلی پیام‌ها را مخفی کن (با استفاده از جدول hidden_messages)
        final messages = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);

        if (messages.isNotEmpty) {
          final hiddenMessagesData = messages
              .map((message) => {
                    'message_id': message['id'],
                    'user_id': userId,
                    'conversation_id': conversationId,
                    'hidden_at': now.toIso8601String(),
                  })
              .toList();
          await _supabase.from('hidden_messages').upsert(hiddenMessagesData);
        }
      }

      // 1. Update the conversation on the server with a placeholder
      await _supabase.from('conversations').update({
        'last_message': clearedHistoryPlaceholder,
        'last_message_time': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', conversationId);

      // 2. Clear local messages for this conversation
      await _messageCache.clearConversationMessages(conversationId, userId);

      // 3. Refresh the conversation in the local cache from the server to ensure consistency
      await refreshConversation(conversationId);
    } catch (e) {
      print('خطا در پاکسازی مکالمه: $e');
      rethrow;
    }
  }

  // دریافت پیام‌های جدید بعد از تاریخ مشخص (برای sync)
  Future<List<MessageModel>> getMessagesAfter(
      String conversationId, DateTime after) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .gt('created_at', after.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      // استخراج sender_id های منحصر به فرد
      final senderIds =
          response.map((m) => m['sender_id'] as String).toSet().toList();

      // پیش‌بارگذاری پروفایل‌ها
      await _profileService.preloadProfiles(senderIds);

      final messages = await Future.wait(
        response.map((json) async {
          final senderId = json['sender_id'] as String;
          final senderProfile = _profileService.getCachedProfile(senderId);

          return MessageModel.fromJson(json, currentUserId: userId).copyWith(
            senderName: senderProfile?.displayName ?? 'کاربر',
            senderAvatar: senderProfile?.avatar,
          );
        }),
      );

      return messages;
    } catch (e) {
      print('خطا در دریافت پیام‌های جدید: $e');
      return [];
    }
  }

  // دریافت پیام‌های یک مکالمه
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 20,
    int offset = 0,
  }) async {
    //final userId = _supabase.auth.currentUser!.id;
    final userId = _supabase.auth.currentUser!.id;

    final requestKey = 'getMessages_${conversationId}_${offset}_$limit';

    // Throttle requests to prevent excessive server calls
    if (_shouldThrottleRequest(requestKey)) {
      print('🚫 Throttling request for $requestKey');
      final cachedMessages = await _messageCache.getConversationMessages(
        conversationId,
        userId,
        limit: limit,
      );
      return cachedMessages;
    }

    try {
      // بررسی وضعیت آنلاین
      final isOnline = await isDeviceOnline();

      // ابتدا از کش استفاده می‌کنیم
      final cachedMessages = await _messageCache.getConversationMessages(
        conversationId,
        userId,
        limit: limit,
      );

      // اگر آفلاین هستیم و کش داریم، از کش استفاده می‌کنیم
      if (!isOnline && cachedMessages.isNotEmpty) {
        return cachedMessages;
      }

      // در حالت آنلاین، پیام‌ها را از سرور دریافت می‌کنیم
      if (isOnline) {
        // Mark request as made
        _markRequestMade(requestKey);
        // دریافت لیست پیام‌های مخفی شده برای کاربر
        final hiddenMessagesResponse = await _supabase
            .from('hidden_messages')
            .select('message_id')
            .eq('user_id', userId)
            .eq('conversation_id', conversationId);

        // تبدیل به لیست شناسه‌های پیام مخفی شده
        final hiddenMessageIds = hiddenMessagesResponse
            .map((e) => e['message_id'] as String)
            .toList();

        // دریافت پیام‌ها با فیلتر کردن پیام‌های مخفی شده
        final messagesResponse = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        // فیلتر کردن پیام‌های مخفی شده
        final filteredMessages = messagesResponse
            .where((message) => !hiddenMessageIds.contains(message['id']))
            .toList();

        print('messagesResponse ${messagesResponse.length}');

        // استخراج sender_id های منحصر به فرد
        final senderIds = filteredMessages
            .map((m) => m['sender_id'] as String)
            .toSet()
            .toList();

        // پیش‌بارگذاری پروفایل‌ها
        await _profileService.preloadProfiles(senderIds);

        final messages = await Future.wait(
          filteredMessages.map((json) async {
            final senderId = json['sender_id'] as String;
            final senderProfile = _profileService.getCachedProfile(senderId);

            var message = MessageModel.fromJson(
              json,
              currentUserId: userId,
            ).copyWith(
              senderName: senderProfile?.displayName ?? 'کاربر',
              senderAvatar: senderProfile?.avatar,
            );

            await _messageCache.cacheMessage(message, userId);
            return message;
          }),
        );

        // در حال دریافت اولین صفحه پیام‌ها هستیم (offset=0)
        // مکالمه را به عنوان خوانده شده علامت‌گذاری می‌کنیم
        if (offset == 0) {
          await markConversationAsRead(conversationId);
        }

        print('getMessages From Server ${messages.length}');
        return messages;
      }

      // اگر آنلاین نیستیم و تا اینجا رسیدیم، از هر کشی که داریم استفاده می‌کنیم
      return cachedMessages;
    } catch (e) {
      final fallbackCachedMessages = await _messageCache
          .getConversationMessages(conversationId, userId, limit: limit);
      if (fallbackCachedMessages.isNotEmpty) {
        print('خطا در دریافت پیام‌ها از سرور. استفاده از کش: $e');
        return fallbackCachedMessages;
      }
      print('خطا در دریافت پیام‌ها: $e');
      throw AppException(
        userFriendlyMessage: 'دریافت پیام‌ها با مشکل مواجه شد',
        technicalMessage: 'خطا در دریافت پیام‌ها: $e',
      );
    }
  }

  // دریافت پیام‌های بلادرنگ یک مکالمه
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
    final userId = _supabase.auth.currentUser!.id;

    // استفاده از merge برای ترکیب استریم‌های مختلف
    final messagesStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) async {
          // استخراج sender_id های منحصر به فرد
          final senderIds =
              data.map((m) => m['sender_id'] as String).toSet().toList();

          // پیش‌بارگذاری پروفایل‌ها
          await _profileService.preloadProfiles(senderIds);

          // تبدیل به MessageModel
          final messages = await Future.wait(
            data.map((json) async {
              final senderId = json['sender_id'] as String;
              final senderProfile = _profileService.getCachedProfile(senderId);

              return MessageModel.fromJson(
                json,
                currentUserId: userId,
              ).copyWith(
                senderName: senderProfile?.displayName ?? 'کاربر',
                senderAvatar: senderProfile?.avatar,
              );
            }),
          );

          // همگام‌سازی با کش
          await _syncMessagesWithCache(conversationId, messages);

          return messages;
        });

    return messagesStream.asyncMap((messages) async {
      // بروزرسانی وضعیت خوانده شدن پیام‌ها
      return messages;
    });
  }

  // متد کمکی برای همگام‌سازی پیام‌های دریافتی از استریم با کش
  Future<void> _syncMessagesWithCache(
    String conversationId,
    List<MessageModel> newMessages,
  ) async {
    final userId = _supabase.auth.currentUser!.id;
    final cachedMessageIds = (await _messageCache.getConversationMessages(
      conversationId,
      userId,
    ))
        .map((m) => m.id)
        .toSet();
    // پیام‌های جدیدی که در کش نیستند
    final messagesToCache =
        newMessages.where((m) => !cachedMessageIds.contains(m.id)).toList();

    if (messagesToCache.isNotEmpty) {
      await _messageCache.cacheMessages(messagesToCache, userId);
    }

    // TODO: Handle updates for existing messages (e.g., is_read status) if needed.
    // Currently, markConversationAsRead handles is_read updates.
    // Other updates (like edits, deletes) are handled via stream or separate calls.
  }

  // علامت‌گذاری همه پیام‌های یک مکالمه به عنوان خوانده شده
  Future<void> markConversationAsRead(String conversationId) async {
    // قابلیت خوانده شده حذف شد
    return;
  }

  // دریافت مکالمات بلادرنگ
  Stream<List<ConversationModel>> subscribeToConversations() {
    print('📡 شروع گوش دادن به تغییرات مکالمات');

    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .map((event) async {
          print('🔔 دریافت تغییرات جدید از سرور');
          return await getConversations();
        })
        .asyncMap((future) => future)
        .handleError((error) {
          print('❌ خطا در استریم مکالمات: $error');
          return [];
        });
  }

  // حذف مکالمه برای همه (مثل تلگرام)
  Future<void> deleteConversationForEveryone(String conversationId) async {
    try {
      print('🔥 حذف مکالمه برای همه شرکت‌کنندگان: $conversationId');

      // حذف همه شرکت‌کنندگان از مکالمه
      await _supabase
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId);

      // حذف تمام پیام‌های این گفتگو
      await _supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // حذف خود گفتگو
      await _supabase.from('conversations').delete().eq('id', conversationId);

      print('✅ مکالمه برای همه حذف شد');
    } catch (e) {
      print('❌ خطا در حذف مکالمه برای همه: $e');
      rethrow;
    }
  }

  // حذف یک گفتگو
  Future<void> deleteConversation(String conversationId) async {
    final userId = _supabase.auth.currentUser!.id;

    // --- اضافه شد: بررسی وضعیت اتصال به اینترنت ---
    final isOnline = await isDeviceOnline();
    if (!isOnline) {
      throw AppException(
        userFriendlyMessage:
            'اتصال به اینترنت برقرار نیست. لطفاً دوباره تلاش کنید.',
        technicalMessage: 'Cannot delete conversation: Device is offline.',
      );
    }
    // --- پایان اضافه شده ---
    try {
      // ابتدا اطلاعات مکالمه را دریافت کن
      final conversationData = await _supabase
          .from('conversations')
          .select('id, type')
          .eq('id', conversationId)
          .single();

      // حذف مشارکت کاربر از گفتگو
      await _supabase
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      // بررسی آیا کاربر دیگری در این گفتگو باقی مانده است
      final remainingParticipants = await _supabase
          .from('conversation_participants')
          .select('id, user_id')
          .eq('conversation_id', conversationId);

      // اگر هیچ شرکت کننده‌ای باقی نمانده، کل گفتگو و پیام‌های آن را حذف کنیم (از سرور)
      if (remainingParticipants.isEmpty) {
        print(
          'آخرین شرکت‌کننده گفتگو را ترک کرد، حذف کامل گفتگو از سرور: $conversationId',
        );
        // حذف تمام پیام‌های این گفتگو
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);

        // حذف خود گفتگو
        await _supabase.from('conversations').delete().eq('id', conversationId);
      } else {
        print(
          'کاربر گفتگو را ترک کرد، شرکت‌کنندگان دیگر باقی مانده‌اند: $conversationId',
        );

        // 🔥 راهکار جدید: برای جلوگیری از نمایش "کاربر" به طرف مقابل
        // مکالمه را برای همه شرکت‌کنندگان حذف کن (مثل تلگرام)
        if (conversationData['type'] == 'private') {
          print('🔥 حذف مکالمه خصوصی برای همه شرکت‌کنندگان (مثل تلگرام)');

          // حذف همه شرکت‌کنندگان از مکالمه
          await _supabase
              .from('conversation_participants')
              .delete()
              .eq('conversation_id', conversationId);

          // حذف تمام پیام‌های این گفتگو
          await _supabase
              .from('messages')
              .delete()
              .eq('conversation_id', conversationId);

          // حذف خود گفتگو
          await _supabase
              .from('conversations')
              .delete()
              .eq('id', conversationId);

          print('✅ مکالمه خصوصی برای همه حذف شد');
        }
      }

      // --- اضافه شد: حذف از کش لوکال Drift ---
      // مکالمه و پیام‌های آن را از کش لوکال کاربر فعلی حذف کن
      await _conversationCache.removeConversation(
        conversationId,
        userId,
      ); // این مربوط به کش مکالمه است

      // حذف پیام‌های کش‌شده مربوطه هم (در صورت وجود)
      await _messageCache.clearConversationMessages(
        conversationId,
        userId,
      ); // استفاده از متد صحیح
      print('گفتگو و پیام‌های آن از کش لوکال حذف شدند: $conversationId');
      // --- پایان اضافه شده ---
    } catch (e) {
      print('خطا در حذف مکالمه (ترک گفتگو): $e');
      // می‌توانید یک Exception سفارشی پرتاب کنید یا خطا را مدیریت کنید
      throw AppException(
        userFriendlyMessage: 'ترک گفتگو با مشکل مواجه شد',
        technicalMessage: 'Error leaving conversation: $e',
      );
    }
  }

  // بلاک کردن کاربر
  Future<void> blockUser(String userId) async {
    try {
      // دریافت اطلاعات کاربر فعلی
      final currentUserId = supabase.auth.currentUser!.id;

      // بررسی وجود رکورد قبلی
      final existingRecord = await supabase
          .from('blocked_users')
          .select()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      // اگر قبلاً بلاک نشده باشد، آن را بلاک کن
      if (existingRecord == null) {
        await supabase.from('blocked_users').insert({
          'user_id': currentUserId,
          'blocked_user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // به‌روزرسانی مکالمات (برای پنهان کردن مکالمه با کاربر بلاک شده)
      await updateBlockedConversations();
    } catch (e) {
      print('خطا در بلاک کردن کاربر: $e');
      throw Exception('بلاک کردن کاربر با خطا مواجه شد: $e');
    }
  }

  // لغو بلاک کاربر
  Future<void> unblockUser(String userId) async {
    try {
      // دریافت اطلاعات کاربر فعلی
      final currentUserId = supabase.auth.currentUser!.id;

      // حذف رکورد بلاک
      await supabase
          .from('blocked_users')
          .delete()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId);

      // به‌روزرسانی مکالمات (برای نمایش مجدد مکالمه با کاربر)
      await updateBlockedConversations();
    } catch (e) {
      print('خطا در لغو بلاک کاربر: $e');
      throw Exception('لغو بلاک کاربر با خطا مواجه شد: $e');
    }
  }

  // بررسی اینکه آیا کاربر بلاک شده است
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // بررسی دو حالت:
      // 1. آیا کاربر جاری کاربر مقابل را مسدود کرده است؟
      // 2. آیا کاربر مقابل کاربر جاری را مسدود کرده است؟
      final blockingRecord = await supabase
          .from('blocked_users')
          .select()
          .or(
            'and(user_id.eq.$currentUserId,blocked_user_id.eq.$userId),and(user_id.eq.$userId,blocked_user_id.eq.$currentUserId)',
          )
          .maybeSingle();

      return blockingRecord != null;
    } catch (e) {
      print('خطا در بررسی وضعیت بلاک کاربر: $e');
      return false;
    }
  }

  Future<bool> isCurrentUserBlockedBy(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // بررسی آیا کاربر مقابل (userId) کاربر جاری را مسدود کرده است
      final blockingRecord = await supabase
          .from('blocked_users')
          .select()
          .eq('user_id', userId)
          .eq('blocked_user_id', currentUserId)
          .maybeSingle();

      return blockingRecord != null;
    } catch (e) {
      print('خطا در بررسی مسدودیت کاربر جاری: $e');
      return false;
    }
  }

  // به‌روزرسانی مکالمات بلاک شده
  Future<void> updateBlockedConversations() async {
    // می‌توان این متد را برای به‌روزرسانی وضعیت نمایش مکالمات استفاده کرد
    // این متد باید پس از بلاک یا آنبلاک کردن کاربر فراخوانی شود
  }

  // گزارش کاربر
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      // دریافت اطلاعات کاربر فعلی
      final currentUserId = supabase.auth.currentUser!.id;

      // ثبت گزارش در دیتابیس
      await supabase.from('user_reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': userId,
        'reason': reason,
        'additional_info': additionalInfo,
        'created_at': DateTime.now().toIso8601String(),
        'status':
            'pending', // وضعیت‌های ممکن: pending, reviewed, dismissed, actioned
      });
    } catch (e) {
      print('خطا در گزارش کاربر: $e');
      throw Exception('گزارش کاربر با خطا مواجه شد: $e');
    }
  }

  Future<List<MessageModel>> searchMessages(
    String conversationId,
    String query,
  ) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .ilike(
            'content',
            '%$query%',
          ) // استفاده از ilike برای جستجوی حساس به حروف کوچک و بزرگ
          .order('created_at', ascending: false);

      final messages = response
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      return messages;
    } catch (e) {
      print('خطا در جستجوی پیام‌ها: $e');
      rethrow;
    }
  }

  Future<String> downloadChatImage(
    String imageUrl,
    Function(double) onProgress,
  ) async {
    try {
      // بررسی آیا تصویر قبلاً دانلود شده است
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imageUrl);
      final filePath = path.join(appDir.path, 'chat_images', fileName);
      final file = File(filePath);

      // اگر فایل موجود است، مسیر آن را برگردان
      if (await file.exists()) {
        return filePath;
      }

      // ایجاد دایرکتوری اگر وجود نداشته باشد
      final directory = Directory(path.dirname(filePath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // دانلود فایل با نمایش پیشرفت (فقط دامنه‌های مجاز)
      final uri = Uri.parse(imageUrl);
      const allowedHosts = {
        'storage.389346.ir.cdn.ir',
        'coffevista.s3.ir-thr-at1.arvanstorage.ir',
      };
      if (!allowedHosts.contains(uri.host)) {
        throw AppException(
          userFriendlyMessage: 'دانلود از منبع نامعتبر',
          technicalMessage: 'host=${uri.host}',
        );
      }
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw AppException(
          userFriendlyMessage: 'خطا در دریافت تصویر',
          technicalMessage: 'خطای HTTP: ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = response.bodyBytes.length;

      // ذخیره فایل
      await file.writeAsBytes(response.bodyBytes);

      // بروزرسانی وضعیت پیشرفت دانلود
      if (totalBytes > 0) {
        final progress = downloadedBytes / totalBytes;
        onProgress(progress);
      }

      return filePath;
    } catch (e) {
      print('خطا در دانلود تصویر: $e');
      throw AppException(
        userFriendlyMessage: 'دانلود تصویر با مشکل مواجه شد',
        technicalMessage: 'خطا در دانلود تصویر: $e',
      );
    }
  }

  // =================== Inline image prefetch with cancel ===================
  final Map<String, http.Client> _imageDownloadClients = {};

  Future<String> prefetchImageCancelable(
    String messageId,
    String imageUrl,
    void Function(double) onProgress,
  ) async {
    try {
      // target path
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imageUrl);
      final filePath = path.join(appDir.path, 'chat_images', fileName);
      final directory = Directory(path.dirname(filePath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final client = http.Client();
      _imageDownloadClients[messageId] = client;

      // فقط دانلود از دامنه‌های مجاز
      final uri2 = Uri.parse(imageUrl);
      const allowedHosts2 = {
        'storage.389346.ir.cdn.ir',
        'coffevista.s3.ir-thr-at1.arvanstorage.ir',
      };
      if (!allowedHosts2.contains(uri2.host)) {
        throw AppException(
          userFriendlyMessage: 'دانلود از منبع نامعتبر',
          technicalMessage: 'host=${uri2.host}',
        );
      }
      final request = http.Request('GET', uri2);
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        throw AppException(
          userFriendlyMessage: 'خطا در دریافت تصویر',
          technicalMessage: 'HTTP ${streamed.statusCode}',
        );
      }

      final total = streamed.contentLength ?? 0;
      int received = 0;
      final file = File(filePath);
      final IOSink sink = file.openWrite();
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } catch (e) {
        // cancel or stream error
        try {
          await sink.close();
          if (await file.exists()) await file.delete();
        } catch (_) {}
        rethrow;
      }

      await sink.close();
      _imageDownloadClients.remove(messageId)?.close();
      return filePath;
    } catch (e) {
      _imageDownloadClients.remove(messageId)?.close();
      throw AppException(
        userFriendlyMessage: 'دانلود تصویر با مشکل مواجه شد',
        technicalMessage: 'prefetchImageCancelable error: $e',
      );
    }
  }

  void cancelImagePrefetch(String messageId) {
    _imageDownloadClients.remove(messageId)?.close();
  }

  // Add a method to refresh the conversations (updates cache by fetching from server)
  Future<void> refreshConversations() async {
    await getConversations();
  }

  Future<void> clearConversation(
    String conversationId, {
    bool bothSides = false,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      if (bothSides) {
        // پاکسازی دوطرفه: ابتدا حذف فایل‌های پیوست از استوریج، سپس حذف پیام‌ها از دیتابیس
        try {
          final attachmentMessages = await _supabase
              .from('messages')
              .select('id, attachment_url, attachment_type')
              .eq('conversation_id', conversationId);

          for (final m in attachmentMessages) {
            final String? url = m['attachment_url'] as String?;
            if (url != null && url.isNotEmpty) {
              await _tryDeleteChatAttachment(
                m['attachment_type'] as String?,
                url,
              );
            }
          }
        } catch (e) {
          print(
              'هشدار: دریافت/حذف پیوست‌های گفتگو هنگام پاکسازی دوطرفه ناموفق بود: $e');
        }

        // سپس حذف همه پیام‌ها از دیتابیس و پاکسازی last_message
        // فراخوانی فانکشن سرور (در صورت وجود)
        try {
          await _supabase.rpc('clear_conversation_fully',
              params: {'convo_id': conversationId});
        } catch (e) {
          // اگر فانکشن وجود نداشت یا خطا داد، حذف مستقیم پیام‌ها و آپدیت conversation
          await _supabase
              .from('messages')
              .delete()
              .eq('conversation_id', conversationId);
          await _supabase.from('conversations').update({
            'last_message': null,
            'last_message_time': null,
          }).eq('id', conversationId);
        }
        // پاکسازی کش پیام‌ها و مکالمه
        await _messageCache.clearConversationMessages(conversationId, userId);
        await _conversationCache.removeConversation(conversationId, userId);
      } else {
        // پاکسازی یک‌طرفه: فقط برای کاربر فعلی پیام‌ها را مخفی کن
        final messages = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);

        for (final message in messages) {
          await _supabase.from('hidden_messages').upsert({
            'message_id': message['id'],
            'user_id': userId,
            'conversation_id': conversationId,
            'hidden_at': DateTime.now().toIso8601String(),
          });
        }
        await _messageCache.clearConversationMessages(conversationId, userId);
        await _conversationCache.removeConversation(conversationId, userId);
      }
    } catch (e) {
      print('خطا در پاکسازی مکالمه: $e');
      throw Exception('پاکسازی مکالمه با خطا مواجه شد: $e');
    }
  }

  // متد گرفتن مکالمات کش شده
  Future<List<ConversationModel>> getCachedConversations() async {
    final userId = _supabase.auth.currentUser!.id;
    return await _conversationCache.getCachedConversations(userId);
  }

  // متد گرفتن تعداد پیام‌های خوانده‌نشده برای هر مکالمه
  Future<Map<String, int>> getUnreadMessagesCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final conversations = await getConversations();
    final Map<String, int> unreadMap = {};

    for (final conversation in conversations) {
      unreadMap[conversation.id] = conversation.unreadCount;
    }
    return unreadMap;
  }

  // متد بروزرسانی وضعیت پیام‌های خوانده‌نشده (در اینجا فقط کش را sync می‌کند)
  Future<void> updateUnreadMessages() async {
    await getConversations();
  }

  // شمارش پیام‌های خوانده‌نشده برای یک مکالمه
  Future<int> countUnreadMessages(String conversationId) async {
    final messageCache = MessageCacheService();
    return await messageCache.countUnreadMessages(conversationId);
  }

  // حذف پیام‌های قدیمی‌تر از یک تاریخ خاص
  Future<void> deleteOldMessages(DateTime date) async {
    final messageCache = MessageCacheService();
    await messageCache.deleteMessagesOlderThan(date);
  }

  // متد برای تغییر وضعیت سنجاق مکالمه (فقط در کش محلی)
  Future<void> toggleConversationPinLocal(String conversationId) async {
    final userId = _supabase.auth.currentUser!.id;
    final conversation = await _conversationCache.getConversation(
      conversationId,
      userId,
    );
    if (conversation != null) {
      final newPinStatus = !conversation.isPinned;
      await _conversationCache.setPinStatus(
          conversationId, userId, newPinStatus);
      // برای اطمینان از اینکه UI آپدیت می‌شود، می‌توانیم مکالمه را در کش آپدیت کنیم
      // یا به provider ها اجازه دهیم که به تغییرات گوش دهند.
      // فعلا فقط وضعیت پین را در کش تغییر می‌دهیم.
    }
  }

  // متد برای تغییر وضعیت بی‌صدا کردن مکالمه
  Future<void> toggleConversationMute(String conversationId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw AppException(
        userFriendlyMessage: 'کاربر شناسایی نشد.',
        technicalMessage: 'Current user is null',
      );
    }

    try {
      // ۱. دریافت وضعیت فعلی is_muted از جدول conversation_participants
      final participantData = await _supabase
          .from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .single();

      final currentMuteStatus = participantData['is_muted'] as bool? ?? false;
      final newMuteStatus = !currentMuteStatus;

      // ۲. به‌روزرسانی وضعیت is_muted در Supabase
      await _supabase
          .from('conversation_participants')
          .update({'is_muted': newMuteStatus})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);
      // ۳. به‌روزرسانی کش محلی (Drift)
      await _conversationCache.setMuteStatus(
          conversationId, currentUserId, newMuteStatus);
      await refreshConversation(
        conversationId,
      ); // برای اطمینان از همگام‌سازی کامل مدل در کش
    } catch (e) {
      print('Error toggling conversation mute status: $e');
      throw AppException(
        userFriendlyMessage:
            'تغییر وضعیت اعلان با خطا مواجه شد. ${e.toString()}',
        technicalMessage: 'Error in toggleConversationMute: $e',
      );
    }
  }

  // متد برای تغییر وضعیت بایگانی مکالمه
  Future<void> toggleConversationArchive(String conversationId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw AppException(
        userFriendlyMessage: 'کاربر شناسایی نشد.',
        technicalMessage: 'Current user is null.',
      );
    }

    try {
      final participantData = await _supabase
          .from('conversation_participants')
          .select('is_archived')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .single();

      final currentArchiveStatus =
          participantData['is_archived'] as bool? ?? false;
      final newArchiveStatus = !currentArchiveStatus;

      await _supabase
          .from('conversation_participants')
          .update({'is_archived': newArchiveStatus})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);

      await _conversationCache.setArchiveStatus(
        conversationId,
        currentUserId,
        newArchiveStatus,
      );
      await refreshConversation(conversationId);
    } catch (e, stack) {
      print('Error toggling conversation archive status: $e');
      throw AppException(
        technicalMessage:
            'Error in toggleConversationArchive: $e, Stack: $stack',
        userFriendlyMessage: 'تغییر وضعیت بایگانی با خطا مواجه شد.',
      );
    }
  }
}
