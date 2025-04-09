import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../view/Exeption/app_exceptions.dart';
import '/main.dart';

import 'uploadImageChatService.dart';

class ChatService {
  final SupabaseClient _supabase = supabase;

  // دریافت تمامی مکالمات کاربر فعلی
// دریافت تمامی مکالمات کاربر فعلی
  Future<List<ConversationModel>> getConversations() async {
    final userId = _supabase.auth.currentUser!.id;

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

      return ConversationModel.fromJson(json, currentUserId: userId).copyWith(
        participants: participants,
        otherUserName: otherParticipantProfile?['username'] ?? 'کاربر',
        otherUserAvatar: otherParticipantProfile?['avatar_url'],
        otherUserId: otherParticipantData?['user_id'],
        hasUnreadMessages: hasUnreadMessages,
      );
    }));

    return conversations;
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

      final insertResponse = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'attachment_url': attachmentUrl,
            'attachment_type': attachmentType,
            'reply_to_message_id': replyToMessageId,
            'reply_to_content': replyToContent,
            'reply_to_sender_name': replyToSenderName,
          })
          .select()
          .single();

      // سپس به صورت جداگانه اطلاعات فرستنده را دریافت می‌کنیم
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
      // اول بررسی می‌کنیم که آیا پیام متعلق به کاربر جاری است یا نه
      final message = await _supabase
          .from('messages')
          .select('sender_id, conversation_id')
          .eq('id', messageId)
          .single();

      final isSender = message['sender_id'] == userId;

      if (forEveryone && !isSender) {
        throw Exception('فقط فرستنده پیام می‌تواند آن را برای همه حذف کند');
      }

      if (forEveryone) {
        // حذف کامل پیام از دیتابیس
        await _supabase.from('messages').delete().eq('id', messageId);
        print('پیام به طور کامل حذف شد: $messageId');
      } else {
        // مخفی کردن پیام برای کاربر فعلی
        await _supabase.from('hidden_messages').upsert({
          'message_id': messageId,
          'user_id': userId,
          'conversation_id': message['conversation_id'],
          'hidden_at': DateTime.now().toIso8601String(),
        });
        print('پیام برای کاربر $userId مخفی شد: $messageId');
      }
    } catch (e) {
      print('خطا در حذف پیام: $e');
      rethrow;
    }
  }

// اضافه کردن متد پاکسازی تاریخچه گفتگو با قابلیت حذف برای همه یا فقط برای کاربر فعلی
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
            'hidden_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      print('خطا در پاکسازی مکالمه: $e');
      throw Exception('پاکسازی مکالمه با خطا مواجه شد: $e');
    }
  }

  // حذف تمام پیام‌های یک مکالمه
  Future<void> deleteAllMessages(String conversationId,
      {bool forEveryone = false}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      if (forEveryone) {
        // حذف برای همه شرکت‌کنندگان

        // ابتدا پیام‌ها را از جدول hidden_messages حذف می‌کنیم که به این مکالمه مربوط هستند
        await _supabase
            .from('hidden_messages')
            .delete()
            .eq('conversation_id', conversationId);

        // سپس پیام‌ها را از جدول messages حذف می‌کنیم
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);

        print('تمام پیام‌های مکالمه $conversationId برای همه کاربران حذف شد');
      } else {
        // حذف فقط برای کاربر فعلی (با مخفی کردن پیام‌ها)

        // ابتدا پیام‌های موجود در hidden_messages که قبلاً توسط این کاربر مخفی شده را بررسی می‌کنیم
        final existingHiddenMessages = await _supabase
            .from('hidden_messages')
            .select('message_id')
            .eq('user_id', userId)
            .eq('conversation_id', conversationId);

        final hiddenMessageIds = existingHiddenMessages
            .map((item) => item['message_id'] as String)
            .toList();

        // پیام‌های مکالمه را دریافت می‌کنیم
        final messagesResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);

        // برای هر پیام که هنوز مخفی نشده، یک رکورد در جدول hidden_messages ایجاد می‌کنیم
        for (final message in messagesResponse) {
          final messageId = message['id'] as String;

          // اگر این پیام قبلاً مخفی نشده باشد
          if (!hiddenMessageIds.contains(messageId)) {
            await _supabase.from('hidden_messages').insert({
              'message_id': messageId,
              'user_id': userId,
              'conversation_id': conversationId,
              'hidden_at': DateTime.now().toIso8601String(),
            });
          }
        }

        print(
            'تمام پیام‌های مکالمه $conversationId برای کاربر $userId مخفی شد');
      }
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
      // دریافت لیست پیام‌های مخفی شده برای کاربر
      final hiddenMessagesResponse = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId);

      // تبدیل به لیست شناسه‌های پیام مخفی شده
      final hiddenMessageIds =
          hiddenMessagesResponse.map((e) => e['message_id'] as String).toList();

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

        final message = MessageModel.fromJson(json, currentUserId: userId);
        return message.copyWith(
          senderName: profileResponse?['username'] ?? 'کاربر',
          senderAvatar: profileResponse?['avatar_url'],
        );
      }));

      return messages;
    } catch (e) {
      print('خطا در دریافت پیام‌ها: $e');
      rethrow;
    }
  }

  // دریافت پیام‌های بلادرنگ یک مکالمه
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
    final userId = _supabase.auth.currentUser!.id;

    print('شروع اشتراک به پیام‌های مکالمه: $conversationId');

    // ابتدا بررسی می‌کنیم چه پیام‌هایی مخفی شده‌اند
    return Stream.periodic(Duration(seconds: 2)).asyncMap((_) async {
      // دریافت لیست پیام‌های مخفی شده برای کاربر
      final hiddenMessagesResponse = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId);

      final hiddenMessageIds =
          hiddenMessagesResponse.map((e) => e['message_id'] as String).toList();

      // دریافت پیام‌ها و فیلتر کردن پیام‌های مخفی شده
      final messagesResponse = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false);

      // فیلتر کردن پیام‌های مخفی شده
      final filteredMessages = messagesResponse
          .where((message) => !hiddenMessageIds.contains(message['id']))
          .toList();

      // تبدیل به MessageModel
      final messages = await Future.wait(filteredMessages.map((json) async {
        // دریافت اطلاعات فرستنده
        final profileResponse = await _supabase
            .from('profiles')
            .select()
            .eq('id', json['sender_id'])
            .maybeSingle();

        final message = MessageModel.fromJson(json, currentUserId: userId);
        return message.copyWith(
          senderName: profileResponse?['username'] ?? 'کاربر',
          senderAvatar: profileResponse?['avatar_url'],
        );
      }));

      return messages;
    });
  }

  // علامت‌گذاری همه پیام‌های یک مکالمه به عنوان خوانده شده
  Future<void> markConversationAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser!.id;

    // بروزرسانی زمان خواندن
    await _supabase
        .from('conversation_participants')
        .update({'last_read_time': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

// دریافت مکالمات بلادرنگ
  Stream<List<ConversationModel>> subscribeToConversations() {
    // بروزرسانی هر 3 ثانیه
    return Stream.periodic(const Duration(seconds: 3))
        .asyncMap((_) => getConversations());
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
}
