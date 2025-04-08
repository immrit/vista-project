import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '/main.dart';
import 'package:rxdart/rxdart.dart';

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

  // // دریافت پیام‌های یک مکالمه
  // Future<List<MessageModel>> getMessages(String conversationId,
  //     {int limit = 20, int offset = 0}) async {
  //   final userId = _supabase.auth.currentUser!.id;

  //   try {
  //     // بررسی نام ستون در جدول messages
  //     final messagesResponse = await _supabase
  //         .from('messages')
  //         .select() // بدون تلاش برای ارتباط با profiles
  //         .eq('conversation_id',
  //             conversationId) // از نام ستون صحیح استفاده کنید
  //         .order('created_at', ascending: false)
  //         .range(offset, offset + limit - 1);

  //     final messages = await Future.wait(messagesResponse.map((json) async {
  //       // برای هر پیام، اطلاعات فرستنده را جداگانه دریافت می‌کنیم
  //       final profileResponse = await _supabase
  //           .from('profiles')
  //           .select()
  //           .eq('id', json['sender_id'])
  //           .maybeSingle();

  //       final message = MessageModel.fromJson(json, currentUserId: userId);
  //       return message.copyWith(
  //         senderName: profileResponse?['username'] ?? 'کاربر',
  //         senderAvatar: profileResponse?['avatar_url'],
  //       );
  //     }).toList());

  //     return messages;
  //   } catch (e) {
  //     print('خطا در دریافت پیام‌ها: $e');
  //     rethrow;
  //   }
  // }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      print('ارسال پیام به مکالمه: $conversationId');
      print('محتوای پیام: $content');
      print('فرستنده: $userId');

      // ابتدا پیام را بدون select برای رابطه sender_id اضافه می‌کنیم
      final insertResponse = await _supabase
          .from('messages')
          .insert({
            'conversation_id':
                conversationId, // مطمئن شوید این نام با نام ستون در دیتابیس مطابقت دارد
            'sender_id': userId,
            'content': content,
            'attachment_url': attachmentUrl,
            'attachment_type': attachmentType,
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
      print('خطا در ارسال پیام: $e');
      rethrow;
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
      print('خطا در ایجاد یا دریافت گفتگو: $e');
      throw Exception('خطا در ایجاد یا دریافت گفتگو');
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
  // Future<void> updateUserOnlineStatus() async {
  //   final userId = _supabase.auth.currentUser?.id;
  //   if (userId == null) {
  //     print('updateUserOnlineStatus: کاربر وارد نشده است');
  //     return;
  //   }

  //   try {
  //     // اطمینان حاصل کنید که ستون last_online در جدول profiles وجود دارد
  //     await _supabase.from('profiles').update({
  //       'last_online': DateTime.now().toUtc().toIso8601String(),
  //     }).eq('id', userId);
  //     print('updateUserOnlineStatus: وضعیت آنلاین کاربر به‌روزرسانی شد');
  //   } catch (e) {
  //     print('updateUserOnlineStatus: خطا در به‌روزرسانی وضعیت آنلاین: $e');
  //   }
  // }

// دریافت زمان آخرین فعالیت کاربر
  // Future<DateTime?> getUserLastOnline(String userId) async {
  //   try {
  //     // باید از جدول profiles استفاده شود نه user_status
  //     final response = await _supabase
  //         .from('profiles')
  //         .select('last_online')
  //         .eq('id', userId)
  //         .maybeSingle();

  //     if (response != null && response['last_online'] != null) {
  //       return DateTime.parse(response['last_online']);
  //     }
  //     return null;
  //   } catch (e) {
  //     print('خطا در دریافت زمان آخرین فعالیت: $e');
  //     return null;
  //   }
  // }
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
      if (forEveryone) {
        // حذف کامل پیام از دیتابیس
        await _supabase.from('messages').delete().eq('id', messageId);
        print('پیام به طور کامل حذف شد: $messageId');
      } else {
        // برچسب زدن پیام به عنوان حذف شده برای کاربر فعلی
        await _supabase.from('deleted_messages').insert({
          'message_id': messageId,
          'user_id': userId,
          'deleted_at': DateTime.now().toIso8601String(),
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
      throw e;
    }
  }

  // حذف تمام پیام‌های یک مکالمه
  Future<void> deleteAllMessages(String conversationId,
      {bool forEveryone = false}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      if (forEveryone) {
        // حذف تمام پیام‌های مکالمه برای همه
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
      } else {
        // ایجاد جدول hidden_messages در دیتابیس اگر وجود ندارد
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
      throw e;
    }
  }

// دریافت پیام‌های یک مکالمه (با در نظر گرفتن پیام‌های حذف شده)
  Future<List<MessageModel>> getMessages(String conversationId,
      {int limit = 20, int offset = 0}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      // دریافت تمام پیام‌های مکالمه
      final messagesResponse = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // دریافت شناسه پیام‌های حذف شده توسط کاربر فعلی
      final deletedMessagesResponse = await _supabase
          .from('deleted_messages')
          .select('message_id')
          .eq('user_id', userId);

      // تبدیل به مجموعه‌ای از شناسه‌های پیام‌های حذف شده
      final deletedMessageIds = Set<String>.from(
        deletedMessagesResponse.map((item) => item['message_id'] as String),
      );

      // فیلتر کردن پیام‌های حذف شده
      final filteredMessages = messagesResponse
          .where(
            (json) => !deletedMessageIds.contains(json['id']),
          )
          .toList();

      // ایجاد مدل‌ها و دریافت اطلاعات اضافی
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
      }).toList());

      return messages;
    } catch (e) {
      print('خطا در دریافت پیام‌ها: $e');
      rethrow;
    }
  }

  // اصلاح متد استریم پیام‌ها برای فیلتر کردن پیام‌های حذف شده
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
    final userId = _supabase.auth.currentUser!.id;

    print('شروع اشتراک به پیام‌های مکالمه: $conversationId');

    // ایجاد استریم ترکیبی از پیام‌ها و پیام‌های حذف شده
    final messagesStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false);

    final deletedMessagesStream = _supabase
        .from('deleted_messages')
        .stream(primaryKey: ['id']).eq('user_id', userId);

    // ترکیب استریم‌ها و فیلتر کردن پیام‌های حذف شده
    return Rx.combineLatest2(
      messagesStream,
      deletedMessagesStream,
      (List<Map<String, dynamic>> messages,
          List<Map<String, dynamic>> deletedMessages) {
        // تبدیل به مجموعه‌ای از شناسه‌های پیام‌های حذف شده
        final deletedMessageIds = Set<String>.from(
          deletedMessages.map((item) => item['message_id'] as String),
        );

        // فیلتر کردن پیام‌های حذف شده
        final filteredMessages = messages
            .where(
              (message) => !deletedMessageIds.contains(message['id']),
            )
            .toList();

        print(
            'دریافت ${filteredMessages.length} پیام (${messages.length - filteredMessages.length} پیام حذف شده)');

        // تبدیل به مدل‌های پیام
        return filteredMessages.map((json) {
          return MessageModel.fromJson(json, currentUserId: userId);
        }).toList();
      },
    );
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

  // گوش دادن به تغییرات پیام‌های یک مکالمه
// دریافت پیام‌های بلادرنگ یک مکالمه
  // Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
  //   final userId = _supabase.auth.currentUser!.id;

  //   print('شروع اشتراک به پیام‌های مکالمه: $conversationId');

  //   return _supabase
  //       .from('messages')
  //       .stream(primaryKey: ['id'])
  //       .eq('conversation_id', conversationId)
  //       .order('created_at', ascending: false)
  //       .map((data) {
  //         print('دریافت داده‌های جدید از stream: ${data.length} پیام');
  //         return data.map((json) {
  //           // دریافت اطلاعات فرستنده
  //           final message = MessageModel.fromJson(json, currentUserId: userId);

  //           return message.copyWith(
  //             senderName: json['profiles']?['username'] ?? 'کاربر',
  //             senderAvatar: json['profiles']?['avatar_url'],
  //           );
  //         }).toList();
  //       });
  // }

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
      // دریافت اطلاعات کاربر فعلی
      final currentUserId = supabase.auth.currentUser!.id;

      // بررسی وجود رکورد بلاک
      final existingRecord = await supabase
          .from('blocked_users')
          .select()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      return existingRecord != null;
    } catch (e) {
      print('خطا در بررسی وضعیت بلاک کاربر: $e');
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
}
