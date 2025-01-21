// import 'package:Vista/model/UserModel.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// import '../model/Direct_message.dart';

// class ChatRepository {
//   final SupabaseClient _supabase;

//   ChatRepository(this._supabase);

//   // دریافت لیست چت‌های اخیر
//   Stream<List<UserModel>> getRecentChats() {
//     final userId = _supabase.auth.currentUser!.id;

//     return _supabase
//         .from('direct_messages')
//         .stream(primaryKey: ['id'])
//         .order('created_at')
//         .execute()
//         .map((messages) {
//           // گرفتن یونیک یوزرهایی که با کاربر فعلی چت داشته‌اند
//           final userIds = messages
//               .where((msg) =>
//                   msg['sender_id'] == userId || msg['receiver_id'] == userId)
//               .map((msg) => msg['sender_id'] == userId
//                   ? msg['receiver_id']
//                   : msg['sender_id'])
//               .toSet();

//           // دریافت پروفایل‌های کاربران
//           return _supabase
//               .from('profiles')
//               .select()
//               .in_('id', userIds)
//               .execute()
//               .then((response) => response.data
//                   .map((json) => UserModel.fromJson(json))
//                   .toList());
//         });
//   }

//   // دریافت پیام‌های یک چت خاص
//   Stream<List<DirectMessage>> getChatMessages(String otherUserId) {
//     final userId = _supabase.auth.currentUser!.id;

//     return _supabase
//         .from('direct_messages')
//         .stream(primaryKey: ['id'])
//         .eq(
//             'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
//         .order('created_at')
//         .execute()
//         .map((data) =>
//             data.map((json) => DirectMessage.fromJson(json)).toList());
//   }

//   // ارسال پیام جدید
//   Future<void> sendMessage({
//     required String receiverId,
//     required String content,
//     String messageType = 'text',
//     String? mediaUrl,
//   }) async {
//     final userId = _supabase.auth.currentUser!.id;

//     await _supabase.from('direct_messages').insert({
//       'sender_id': userId,
//       'receiver_id': receiverId,
//       'content': content,
//       'message_type': messageType,
//       'media_url': mediaUrl,
//     });
//   }

//   // علامت‌گذاری پیام‌ها به عنوان خوانده شده
//   Future<void> markAsRead(String otherUserId) async {
//     final userId = _supabase.auth.currentUser!.id;

//     await _supabase
//         .from('direct_messages')
//         .update({'is_read': true})
//         .eq('sender_id', otherUserId)
//         .eq('receiver_id', userId);
//   }
// }
