import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '/main.dart';

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

  // دریافت پیام‌های یک مکالمه
  Future<List<MessageModel>> getMessages(String conversationId,
      {int limit = 20, int offset = 0}) async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      // بررسی نام ستون در جدول messages
      final messagesResponse = await _supabase
          .from('messages')
          .select() // بدون تلاش برای ارتباط با profiles
          .eq('conversation_id',
              conversationId) // از نام ستون صحیح استفاده کنید
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final messages = await Future.wait(messagesResponse.map((json) async {
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
      }).toList());

      return messages;
    } catch (e) {
      print('خطا در دریافت پیام‌ها: $e');
      rethrow;
    }
  }

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
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) {
    final userId = _supabase.auth.currentUser!.id;

    print('شروع اشتراک به پیام‌های مکالمه: $conversationId');

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((data) {
          print('دریافت داده‌های جدید از stream: ${data.length} پیام');
          return data.map((json) {
            // دریافت اطلاعات فرستنده
            final message = MessageModel.fromJson(json, currentUserId: userId);

            return message.copyWith(
              senderName: json['profiles']?['username'] ?? 'کاربر',
              senderAvatar: json['profiles']?['avatar_url'],
            );
          }).toList();
        });
  }

// دریافت مکالمات بلادرنگ
  Stream<List<ConversationModel>> subscribeToConversations() {
    // بروزرسانی هر 3 ثانیه
    return Stream.periodic(const Duration(seconds: 3))
        .asyncMap((_) => getConversations());
  }
}
