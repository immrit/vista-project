import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../DB/conversation_cache_service.dart';
import '../DB/message_cache_service.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../view/Exeption/app_exceptions.dart';
import '/main.dart';

import 'uploadImageChatService.dart';

class ChatService {
  final SupabaseClient _supabase = supabase;
  final ConversationCacheService _conversationCache =
      ConversationCacheService();
  final MessageCacheService _messageCache = MessageCacheService();

  // متغیر static برای نگهداری conversationId فعال و آخرین messageId دیده‌شده
  static String? activeConversationId;
  static String? lastNotifiedMessageId;

  // نگهداری لیست پیام‌هایی که نوتیفیکیشن گرفته‌اند (در یک session)
  static final Set<String> _notifiedMessageIds = {};

// دریافت تمامی مکالمات کاربر فعلی
  Future<List<ConversationModel>> getConversations() async {
    final userId = _supabase.auth.currentUser!.id;
    final ConversationCacheService conversationCache =
        ConversationCacheService();

    try {
      // بررسی می‌کنیم که آیا آنلاین هستیم
      final isOnline = kIsWeb ? true : await isDeviceOnline();

      // ابتدا سعی می‌کنیم مکالمات را از کش بگیریم
      final cachedConversations =
          await conversationCache.getCachedConversations();

      // اگر آفلاین هستیم و کش داریم، از کش استفاده می‌کنیم
      if (!isOnline && cachedConversations.isNotEmpty) {
        return cachedConversations;
      }

      // در حالت آنلاین، مکالمات را از سرور دریافت می‌کنیم
      if (isOnline) {
        // دریافت شناسه‌های مکالماتی که کاربر در آنها شرکت دارد
        final participantsResponse = await _supabase
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', userId);

        if (participantsResponse.isEmpty) return [];

        // تبدیل به لیستی از شناسه‌ها
        final conversationIds = participantsResponse
            .map((e) => e['conversation_id'] as String)
            .toList();

        // دریافت مکالمات
        final conversationsResponse = await _supabase
            .from('conversations')
            .select()
            .inFilter('id', conversationIds)
            .order('updated_at', ascending: false);

        // برای هر مکالمه، شرکت‌کنندگان را دریافت می‌کنیم
        final conversations =
            await Future.wait(conversationsResponse.map((json) async {
          final conversationId = json['id'] as String;

          // دریافت شرکت‌کنندگان - اصلاح کوئری
          final participantsJson = await _supabase
              .from('conversation_participants')
              .select('*')
              .eq('conversation_id', conversationId);

          // برای هر شرکت‌کننده، اطلاعات پروفایل را جداگانه دریافت می‌کنیم
          final participants =
              await Future.wait(participantsJson.map((participant) async {
            final userId = participant['user_id'] as String;
            final profileJson = await _supabase
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

            final updatedParticipant = {...participant};
            if (profileJson != null) {
              updatedParticipant['profile'] = profileJson;
            }

            return ConversationParticipantModel.fromJson(updatedParticipant);
          }));

          // پیدا کردن کاربر دیگر در چت (برای چت دو نفره)
          Map<String, dynamic>? otherParticipantData;
          Map<String, dynamic>? otherParticipantProfile;

          for (final participant in participantsJson) {
            if (participant['user_id'] != userId) {
              otherParticipantData = participant;

              // دریافت اطلاعات پروفایل کاربر دیگر
              otherParticipantProfile = await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', participant['user_id'])
                  .maybeSingle();

              break;
            }
          }

          // آخرین زمان خواندن پیام توسط کاربر فعلی
          String? myLastRead;
          for (final participant in participantsJson) {
            if (participant['user_id'] == userId) {
              myLastRead = participant['last_read_time'];
              break;
            }
          }

          // بررسی وجود پیام‌های خوانده نشده
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
                      .toList())
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          // اگر پیامی وجود داشت، آن را در json قرار بده
          if (lastMessageQuery != null) {
            json['last_message'] = lastMessageQuery['content'];
            json['last_message_time'] = lastMessageQuery['created_at'];
          }

          // محاسبه تعداد پیام‌های خوانده‌نشده
          int unreadCount = 0;
          if (myLastRead != null) {
            final unreadMessages = await _supabase
                .from('messages')
                .select('id')
                .eq('conversation_id', conversationId)
                .gt('created_at', myLastRead)
                .neq('sender_id', userId); // فقط پیام‌های دریافتی

            // فیلتر پیام‌های مخفی شده
            final hiddenMessages = await _supabase
                .from('hidden_messages')
                .select('message_id')
                .eq('user_id', userId)
                .eq('conversation_id', conversationId);

            final hiddenIds =
                hiddenMessages.map((e) => e['message_id'] as String).toSet();

            unreadCount = unreadMessages
                .where((msg) => !hiddenIds.contains(msg['id']))
                .length;
          }

          final conversation =
              ConversationModel.fromJson(json, currentUserId: userId).copyWith(
            participants: participants,
            otherUserName: otherParticipantProfile?['username'] ?? 'کاربر',
            otherUserAvatar: otherParticipantProfile?['avatar_url'],
            otherUserId: otherParticipantData?['user_id'],
            hasUnreadMessages: hasUnreadMessages,
            unreadCount: unreadCount,
          );

          // ذخیره هر مکالمه در کش
          await conversationCache.updateConversation(conversation);

          return conversation;
        }));

        return conversations;
      }

      // اگر آنلاین نیستیم و تا اینجا رسیدیم، از هر کشی که داریم استفاده می‌کنیم
      return cachedConversations;
    } catch (e) {
      // در صورت خطا، اگر کش داریم از آن استفاده می‌کنیم
      final fallbackCachedConversations =
          await conversationCache.getCachedConversations();
      if (fallbackCachedConversations.isNotEmpty) {
        print('خطا در دریافت مکالمات از سرور. استفاده از کش: $e');
        return fallbackCachedConversations;
      }

      throw AppException(
        userFriendlyMessage: 'دریافت مکالمات با مشکل مواجه شد',
        technicalMessage: 'خطا در دریافت مکالمات: $e',
      );
    }
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

  Future<MessageModel> sendMessage({
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
      print('ارسال پیام به مکالمه: $conversationId');
      print('محتوای پیام: $content');
      print('فرستنده: $userId');
      print('attachmentUrl: $attachmentUrl'); // اضافه شد برای دیباگ
      print('attachmentType: $attachmentType'); // اضافه شد برای دیباگ

      // اطمینان از آنلاین بودن فقط روی موبایل/دسکتاپ
      final isOnline = await isDeviceOnline();
      if (!isOnline) {
        throw AppException(
          userFriendlyMessage: 'اتصال اینترنت برقرار نیست',
          technicalMessage: 'ارسال پیام در حالت آفلاین مجاز نیست',
        );
      }

      // اطمینان از اینکه اگر attachmentUrl مقدار ندارد، فیلد را null بفرستیم
      final insertMap = {
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'attachment_url': (attachmentUrl != null && attachmentUrl.isNotEmpty)
            ? attachmentUrl
            : null,
        'attachment_type': (attachmentType != null && attachmentType.isNotEmpty)
            ? attachmentType
            : null,
        'reply_to_message_id': replyToMessageId,
        'reply_to_content': replyToContent,
        'reply_to_sender_name': replyToSenderName,
      };

      print('insertMap: $insertMap'); // دیباگ

      // ارسال پیام به سرور
      final insertResponse =
          await _supabase.from('messages').insert(insertMap).select().single();

      // دریافت اطلاعات فرستنده
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // ساخت مدل پیام با اطلاعات فرستنده
      final message =
          MessageModel.fromJson(insertResponse, currentUserId: userId).copyWith(
        senderName: profileResponse?['username'] ?? 'کاربر',
        senderAvatar: profileResponse?['avatar_url'],
      );

      // ذخیره پیام در کش
      await _messageCache.cacheMessage(message);

      // بروزرسانی مکالمه در کش
      final conversation =
          await _conversationCache.getConversation(conversationId);
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: content,
          lastMessageTime: DateTime.now(),
          updatedAt: DateTime.now(),
          hasUnreadMessages: false, // برای فرستنده پیام خوانده شده است
        );
        await _conversationCache.updateConversation(updatedConversation);
      }

      // بروزرسانی زمان خواندن پیام‌ها
      await _supabase
          .from('conversation_participants')
          .update({'last_read_time': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      return message;
    } catch (e) {
      throw AppException(
        userFriendlyMessage: 'ارسال پیام با مشکل مواجه شد',
        technicalMessage: 'خطا در ارسال پیام: $e',
      );
    }
  }

  Future<void> cleanOldCache() async {
    try {
      // پاک کردن مکالمات قدیمی‌تر از یک ماه
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

      final conversations = await _conversationCache.getCachedConversations();
      for (final conversation in conversations) {
        if (conversation.updatedAt.isBefore(oneMonthAgo)) {
          await _conversationCache.removeConversation(conversation.id);
          await _messageCache.clearConversationMessages(conversation.id);
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

      // دریافت مکالمات به‌روز
      await getConversations();

      // سپس برای هر مکالمه، پیام‌های اخیر را دریافت می‌کنیم
      final conversations = await _conversationCache.getCachedConversations();
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
      await _messageCache.cacheMessage(temporaryMessage);

      // بروزرسانی مکالمه در کش
      final conversation =
          await _conversationCache.getConversation(conversationId);
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: content,
          lastMessageTime: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _conversationCache.updateConversation(updatedConversation);
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

    final pendingMessagesCopy =
        List<Map<String, dynamic>>.from(_pendingMessages);

    for (final pendingMessage in pendingMessagesCopy) {
      try {
        // ارسال پیام به سرور
        final message = await sendMessage(
          conversationId: pendingMessage['conversationId'],
          content: pendingMessage['content'],
          attachmentUrl: pendingMessage['attachmentUrl'],
          attachmentType: pendingMessage['attachmentType'],
          replyToMessageId: pendingMessage['replyToMessageId'],
          replyToContent: pendingMessage['replyToContent'],
          replyToSenderName: pendingMessage['replyToSenderName'],
        );

        // حذف پیام موقت از کش
        await _messageCache
            .clearConversationMessages(pendingMessage['conversationId']);

        // حذف از صف
        _pendingMessages.removeWhere(
            (msg) => msg['temporaryId'] == pendingMessage['temporaryId']);
      } catch (e) {
        print('خطا در ارسال پیام در صف: $e');
      }
    }
  }

  Future<String> createOrGetConversation(String otherUserId) async {
    final userId = _supabase.auth.currentUser!.id;

    // جلوگیری از ایجاد مکالمه با خود کاربر
    if (userId == otherUserId) {
      throw Exception('کاربر نمی‌تواند با خودش گفتگو ایجاد کند.');
    }

    try {
      // بررسی وجود مکالمه قبلی بین دو کاربر با کوئری ساده‌تر
      final existingQuery = await _supabase.rpc(
        'find_conversation_between_users',
        params: {
          'user1': userId,
          'user2': otherUserId,
        },
      );

      if (existingQuery != null && existingQuery.isNotEmpty) {
        // مکالمه قبلاً وجود دارد
        return existingQuery[0]['id'];
      }

      // ایجاد مکالمه جدید بدون نگرانی از RLS
      final newConversation =
          await _supabase.from('conversations').insert({}).select().single();

      final conversationId = newConversation['id'];

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

      return conversationId;
    } catch (e) {
      throw AppException(
        userFriendlyMessage: 'مشکل در ایجاد گفتگو',
        technicalMessage: 'خطا در createOrGetConversation: $e',
      );
    }
  }

  // ایجاد مکالمه جدید
  Future<ConversationModel> createConversation(String otherUserId) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      // بررسی آیا مکالمه‌ای بین این دو کاربر وجود دارد
      final existingConversationsResponse = await _supabase.rpc(
        'find_conversation_between_users',
        params: {
          'user1': userId,
          'user2': otherUserId,
        },
      );

      if (existingConversationsResponse != null &&
          existingConversationsResponse.isNotEmpty) {
        // مکالمه قبلاً وجود دارد، آن را برمی‌گردانیم
        final conversationId = existingConversationsResponse[0]['id'];

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

        final otherParticipant =
            participantsJson.firstWhere((e) => e['user_id'] == otherUserId);

        return ConversationModel.fromJson(conversationResponse).copyWith(
          participants: participants,
          otherUserName: otherParticipant['profiles']['username'] ?? 'کاربر',
          otherUserAvatar: otherParticipant['profiles']['avatar_url'],
          otherUserId: otherUserId,
        );
      }

      // ایجاد مکالمه جدید
      final conversationResponse =
          await _supabase.from('conversations').insert({}).select().single();

      final conversationId = conversationResponse['id'];

      // افزودن شرکت‌کنندگان در دو تراکنش جداگانه
      // ابتدا کاربر فعلی را اضافه می‌کنیم
      await _supabase.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': userId,
        'last_read_time': DateTime.now().toIso8601String(),
      });

      // سپس کاربر دیگر را اضافه می‌کنیم
      await _supabase.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': otherUserId,
        'last_read_time': DateTime.now().toIso8601String(),
      });

      // دریافت اطلاعات کاربر دیگر
      final otherUserResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', otherUserId)
          .single();

      return ConversationModel.fromJson(conversationResponse).copyWith(
        otherUserName: otherUserResponse['username'] ?? 'کاربر',
        otherUserAvatar: otherUserResponse['avatar_url'],
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
          'isUserOnline: کاربر $userId - آخرین فعالیت: $lastOnline - اختلاف: ${difference.inMinutes} دقیقه - آنلاین: $isOnlineBased');

      return isOnlineBased;
    } catch (e) {
      print('خطا در بررسی وضعیت آنلاین: $e');
      return false;
    }
  }

  // حذف یک پیام
  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final message = await _supabase
          .from('messages')
          .select('sender_id, conversation_id')
          .eq('id', messageId)
          .single();

      final conversationId = message['conversation_id'];
      final isSender = message['sender_id'] == userId;

      if (forEveryone && !isSender) {
        throw Exception('فقط فرستنده پیام می‌تواند آن را برای همه حذف کند');
      }

      if (forEveryone) {
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
      await _messageCache.clearMessage(conversationId, messageId);

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
      await _conversationCache.clearCache();
      await getConversations();
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

      if (conversationResponse != null) {
        final userId = _supabase.auth.currentUser!.id;
        final conversation =
            await _getConversationWithDetails(conversationResponse, userId);
        await _conversationCache.updateConversation(conversation);
      }
    } catch (e) {
      print('خطا در بروزرسانی مکالمه: $e');
    }
  }

  // Helper method to get conversation with details
  Future<ConversationModel> _getConversationWithDetails(
      Map<String, dynamic> conversationData, String userId) async {
    // ... کد موجود از متد getConversations برای دریافت جزئیات مکالمه ...
    // این متد را از بخش مربوطه در getConversations کپی کنید
    return ConversationModel.fromJson(conversationData, currentUserId: userId);
  }

  // حذف تمام پیام‌های یک مکالمه
  Future<void> deleteAllMessages(String conversationId,
      {bool forEveryone = false}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      if (forEveryone) {
        // Delete messages for everyone
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);

        // Clear all messages from cache
        await _messageCache.clearConversationMessages(conversationId);
      } else {
        // Hide messages only for current user
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

        // Clear messages from local cache
        await _messageCache.clearConversationMessages(conversationId);
      }

      // Update conversation in cache
      await _conversationCache.removeConversation(conversationId);
    } catch (e) {
      print('خطا در پاکسازی مکالمه: $e');
      rethrow;
    }
  }

// دریافت پیام‌های یک مکالمه
  Future<List<MessageModel>> getMessages(String conversationId,
      {int limit = 20, int offset = 0}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      // بررسی وضعیت آنلاین
      final isOnline = await isDeviceOnline();

      // ابتدا از کش استفاده می‌کنیم
      final cachedMessages = await _messageCache.getConversationMessages(
        conversationId,
        limit: limit,
      );

      // اگر آفلاین هستیم و کش داریم، از کش استفاده می‌کنیم
      if (!isOnline && cachedMessages.isNotEmpty) {
        return cachedMessages;
      }

      // در حالت آنلاین، پیام‌ها را از سرور دریافت می‌کنیم
      if (isOnline) {
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

        final messages = await Future.wait(filteredMessages.map((json) async {
          // برای هر پیام، اطلاعات فرستنده را جداگانه دریافت می‌کنیم
          final profileResponse = await _supabase
              .from('profiles')
              .select()
              .eq('id', json['sender_id'])
              .maybeSingle();

          final message =
              MessageModel.fromJson(json, currentUserId: userId).copyWith(
            senderName: profileResponse?['username'] ?? 'کاربر',
            senderAvatar: profileResponse?['avatar_url'],
          );

          // ذخیره پیام در کش
          await _messageCache.cacheMessage(message);

          return message;
        }));

        // در حال دریافت اولین صفحه پیام‌ها هستیم (offset=0)
        // مکالمه را به عنوان خوانده شده علامت‌گذاری می‌کنیم
        if (offset == 0) {
          await markConversationAsRead(conversationId);
        }

        return messages;
      }

      // اگر آنلاین نیستیم و تا اینجا رسیدیم، از هر کشی که داریم استفاده می‌کنیم
      return cachedMessages;
    } catch (e) {
      // در صورت خطا، اگر کش داریم از آن استفاده می‌کنیم
      final fallbackCachedMessages =
          await _messageCache.getConversationMessages(
        conversationId,
        limit: limit,
      );

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
          // تبدیل به MessageModel
          final messages = await Future.wait(
            data.map((json) async {
              final profileResponse = await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', json['sender_id'])
                  .maybeSingle();

              return MessageModel.fromJson(json, currentUserId: userId)
                  .copyWith(
                senderName: profileResponse?['username'] ?? 'کاربر',
                senderAvatar: profileResponse?['avatar_url'],
              );
            }),
          );

          // همگام‌سازی با کش
          await _messageCache.smartSync(conversationId, messages);

          return messages;
        });

    // ترکیب با Stream دیگر برای بروزرسانی وضعیت پیام‌ها
    final readStatusStream = _supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id']).eq('conversation_id', conversationId);

    return messagesStream.asyncMap((messages) async {
      // بروزرسانی وضعیت خوانده شدن پیام‌ها
      return messages;
    });
  }

  // Helper method to show notification
  void _showMessageNotification(
      Map<String, dynamic> messageData, Map<String, dynamic>? senderProfile) {
    final content = messageData['content'] ?? '';
    final senderName = senderProfile?['username'] ?? 'کاربر';

    String bodyText = content.isNotEmpty
        ? content
        : (messageData['attachment_type'] == 'image'
            ? 'یک تصویر ارسال شد'
            : 'پیام جدید');

    if (bodyText.length > 60) {
      bodyText = bodyText.substring(0, 57) + '...';
    }

    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '$senderName پیام جدید داد',
      bodyText,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'پیام‌های چت',
          channelDescription: 'اعلان پیام‌های جدید چت',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // علامت‌گذاری همه پیام‌های یک مکالمه به عنوان خوانده شده
// علامت‌گذاری مکالمه به عنوان خوانده شده
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // دریافت پیام‌های نخوانده‌ی مکالمه
      final unreadMessages = await supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId); // فقط پیام‌هایی که برای من هستند

      if (unreadMessages.isEmpty) {
        print('پیام نخوانده‌ای برای علامت‌گذاری وجود ندارد');
        return; // اگر پیام نخوانده‌ای نیست، کاری انجام نده
      }

      print(
          'در حال علامت‌گذاری ${unreadMessages.length} پیام به عنوان خوانده شده');

      // به‌روزرسانی در سرور
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);

      // به‌روزرسانی در کش محلی برای هر پیام
      for (final message in unreadMessages) {
        await _messageCache.updateMessageStatus(conversationId, message['id'],
            isRead: true);
        print('پیام ${message['id']} به عنوان خوانده شده علامت‌گذاری شد');
      }

      print(
          'تمام پیام‌های مکالمه به عنوان خوانده‌شده علامت‌گذاری شدند: $conversationId');
    } catch (e) {
      print('خطا در علامت‌گذاری مکالمه به عنوان خوانده‌شده: $e');
      rethrow;
    }
  }

// دریافت مکالمات بلادرنگ
  Stream<List<ConversationModel>> subscribeToConversations() {
    print('📡 شروع گوش دادن به تغییرات مکالمات');
    final userId = _supabase.auth.currentUser!.id;

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

  // حذف یک گفتگو
  Future<void> deleteConversation(String conversationId) async {
    final userId = _supabase.auth.currentUser!.id;

    // حذف مشارکت کاربر از گفتگو
    await _supabase
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);

    // بررسی آیا کاربر دیگری در این گفتگو باقی مانده است
    final remainingParticipants = await _supabase
        .from('conversation_participants')
        .select('id')
        .eq('conversation_id', conversationId);

    // اگر هیچ شرکت کننده‌ای باقی نمانده، کل گفتگو و پیام‌های آن را حذف کنیم
    if (remainingParticipants.isEmpty) {
      // حذف تمام پیام‌های این گفتگو
      await _supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // حذف خود گفتگو
      await _supabase.from('conversations').delete().eq('id', conversationId);
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
          .or('and(user_id.eq.$currentUserId,blocked_user_id.eq.$userId),and(user_id.eq.$userId,blocked_user_id.eq.$currentUserId)')
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
      String conversationId, String query) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .ilike('content',
              '%$query%') // استفاده از ilike برای جستجوی حساس به حروف کوچک و بزرگ
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
      String imageUrl, Function(double) onProgress) async {
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

      // دانلود فایل با نمایش پیشرفت
      final response = await http.get(Uri.parse(imageUrl));

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

  // Add a method to refresh the conversations (updates cache by fetching from server)
  Future<void> refreshConversations() async {
    await getConversations();
  }

  Future<void> clearConversation(String conversationId,
      {bool bothSides = false}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      if (bothSides) {
        // حذف تمام پیام‌های مکالمه برای همه
        final messagesWithImages = await _supabase
            .from('messages')
            .select('attachment_url')
            .eq('conversation_id', conversationId)
            .neq('attachment_url', '');

        // تبدیل به لیستی از Futureها
        final deleteFutures = messagesWithImages
            .where((msg) => msg['attachment_url'] != null)
            .map((msg) => ChatImageUploadService.deleteChatImage(
                msg['attachment_url'] as String))
            .toList();

        await Future.wait(deleteFutures);

        // حذف پیام‌ها از دیتابیس
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);

        // پاکسازی کش پیام‌های این مکالمه
        await _messageCache.clearConversationMessages(conversationId);
      } else {
        // فقط برای کاربر فعلی پیام‌ها را مخفی کن (با استفاده از جدول hidden_messages)
        final messages = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);

        // برای هر پیام، یک رکورد در جدول hidden_messages اضافه می‌کنیم
        for (var message in messages) {
          await _supabase.from('hidden_messages').upsert({
            'message_id': message['id'],
            'user_id': userId,
            'conversation_id': conversationId,
            'hidden_at': DateTime.now().toIso8601String(),
          });
        }

        // پاکسازی کش پیام‌های این مکالمه
        await _messageCache.clearConversationMessages(conversationId);
      }

      // پاکسازی کش مکالمه
      await _conversationCache.removeConversation(conversationId);
    } catch (e) {
      print('خطا در پاکسازی مکالمه: $e');
      throw Exception('پاکسازی مکالمه با خطا مواجه شد: $e');
    }
  }

  // متد گرفتن مکالمات کش شده
  Future<List<ConversationModel>> getCachedConversations() async {
    return await _conversationCache.getCachedConversations();
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
}
