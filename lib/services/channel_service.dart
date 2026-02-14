import '../security/logging_utility.dart';
import 'package:Vista/services/secure_config.dart';
import 'package:Vista/services/secure_upload_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';
import '../utils/const.dart';

class ChannelService {
  final SupabaseClient _supabase = supabase;
  // final ChannelCacheService _cache = ChannelCacheService(); // حذف شده

  // Singleton pattern
  static final ChannelService _instance = ChannelService._internal();
  factory ChannelService() => _instance;
  ChannelService._internal();

  // مقداردهی اولیه
  Future<void> initialize() async {
    // Channel cache removed, no initialization needed
  }

  // 📸 آپلود تصویر به آروان کلود
  Future<String?> _uploadImageToArvan(File imageFile, String folder) async {
    try {
      final String bucketName = SecureConfig.awsBucketName;
      const String endpoint = 'https://s3.ir-thr-at1.arvanstorage.ir';

      // ساخت نام فایل یونیک
      final String fileName =
          '$folder/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

      // خواندن فایل
      final bytes = await imageFile.readAsBytes();

      // ساخت URL برای آپلود
      final uri = Uri.parse('$endpoint/$bucketName/$fileName');

      // ساخت درخواست PUT
      final request = http.Request('PUT', uri);
      request.headers.addAll({
        'Content-Type': 'image/jpeg',
        'Content-Length': bytes.length.toString(),
      });
      request.bodyBytes = bytes;

      // ارسال درخواست
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final imageUrl = '$endpoint/$bucketName/$fileName';
        logInfo('تصویر با موفقیت آپلود شد: $imageUrl');
        return imageUrl;
      } else {
        logInfo('خطا در آپلود تصویر: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logInfo('خطا در آپلود تصویر به آروان: $e');
      return null;
    }
  }

  // 🗑️ حذف تصویر از آروان کلود
  // Delete image from storage
  Future<bool> _deleteImageFromArvan(String imageUrl) async {
    try {
      final deleted = await SecureUploadService.deleteByUrl(imageUrl);
      if (deleted) {
        logInfo('تصویر با موفقیت حذف شد');
        return true;
      }
      logInfo('خطا در حذف تصویر: delete failed');
      return false;
    } catch (e) {
      logInfo('خطا در حذف تصویر از آروان: $e');
      return false;
    }
  }

  // 🔐 بررسی مجوزات کاربر
  Future<Map<String, bool>> getUserPermissions(String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final memberInfo = await _supabase
          .from('channel_members')
          .select('role')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .maybeSingle();

      if (memberInfo == null) {
        return {
          'isMember': false,
          'canSendMessage': false,
          'canDeleteMessage': false,
          'canManageChannel': false,
        };
      }

      final role = memberInfo['role'] as String;

      return {
        'isMember': true,
        'canSendMessage': true,
        'canDeleteMessage': ['owner', 'admin', 'moderator'].contains(role),
        'canManageChannel': ['owner', 'admin'].contains(role),
      };
    } catch (e) {
      logInfo('خطا در بررسی مجوزها: $e');
      return {
        'isMember': false,
        'canSendMessage': false,
        'canDeleteMessage': false,
        'canManageChannel': false,
      };
    }
  }

  // 📋 دریافت لیست کانال‌ها با کش هوشمند
  Future<List<ChannelModel>> getChannels({bool forceRefresh = false}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Channel cache removed - always fetch from server
      if (!forceRefresh) {
        // No cache check needed
      }

      // دریافت از سرور
      final channels = await _fetchChannelsFromServer(userId);

      // Channel cache removed

      logInfo('${channels.length} کانال از سرور دریافت و کش شد');
      return channels;
    } catch (e) {
      logInfo('خطا در دریافت کانال‌ها: $e');

      // Channel cache removed - no fallback available

      rethrow;
    }
  }

  // دریافت کانال‌ها از سرور (تطبیق با جدول profiles)
  Future<List<ChannelModel>> _fetchChannelsFromServer(String userId) async {
    final response = await _supabase.from('channel_members').select('''
          channel_id, 
          role, 
          joined_at,
          channels!inner(
            id,
            name,
            description,
            username,
            is_private,
            creator_id,
            member_count,
            avatar_url,
            created_at,
            updated_at,
            last_message
          )
        ''').eq('user_id', userId).order('joined_at', ascending: true);

    return response.map<ChannelModel>((data) {
      final channelData = Map<String, dynamic>.from(data['channels']);
      channelData['member_role'] = data['role'];
      channelData['joined_at'] = data['joined_at'];
      return ChannelModel.fromJson(channelData, currentUserId: userId);
    }).toList();
  }

  // دریافت یک کانال خاص
  Future<ChannelModel?> getChannel(String channelId,
      {bool forceRefresh = false}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // چک کردن کش
      // Channel cache removed - always fetch from server

      // دریافت از سرور
      final response = await _supabase.from('channel_members').select('''
            role,
            joined_at,
            channels!inner(
              id,
              name,
              description,
              username,
              is_private,
              creator_id,
              member_count,
              avatar_url,
              created_at,
              updated_at,
              last_message
            )
          ''').eq('channel_id', channelId).eq('user_id', userId).maybeSingle();

      if (response == null) {
        return null;
      }

      final channelData = Map<String, dynamic>.from(response['channels']);
      channelData['member_role'] = response['role'];
      channelData['joined_at'] = response['joined_at'];

      final channel = ChannelModel.fromJson(channelData, currentUserId: userId);

      // کش کردن
      // Channel cache removed

      return channel;
    } catch (e) {
      logInfo('خطا در دریافت کانال: $e');

      // Channel cache removed - no fallback available

      rethrow;
    }
  }

  // ایجاد کانال جدید
  Future<ChannelModel> createChannel({
    required String name,
    required String username,
    String? description,
    bool isPrivate = false,
    File? avatarFile,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      String? avatarUrl;

      // آپلود آواتار در صورت وجود
      if (avatarFile != null) {
        avatarUrl = await _uploadImageToArvan(avatarFile, 'channel_avatars');
      }

      // ایجاد کانال
      final channelResponse = await _supabase
          .from('channels')
          .insert({
            'name': name,
            'username': username,
            'description': description,
            'is_private': isPrivate,
            'creator_id': userId,
            'avatar_url': avatarUrl,
            'member_count': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final channelId = channelResponse['id'];

      // افزودن سازنده به عنوان owner
      await _supabase.from('channel_members').insert({
        'channel_id': channelId,
        'user_id': userId,
        'role': 'owner',
        'joined_at': DateTime.now().toIso8601String(),
      });

      final channel = ChannelModel.fromJson({
        ...channelResponse,
        'member_role': 'owner',
        'joined_at': DateTime.now().toIso8601String(),
      }, currentUserId: userId);

      // کش کردن
      // Channel cache removed
      // Channel cache removed // برای آپدیت لیست

      logInfo('کانال ${channel.name} با موفقیت ایجاد شد');
      return channel;
    } catch (e) {
      logInfo('خطا در ایجاد کانال: $e');
      rethrow;
    }
  }

  // پیوستن به کانال
  Future<void> joinChannel(String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی عضویت قبلی
      final existingMember = await _supabase
          .from('channel_members')
          .select('id')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingMember != null) {
        throw Exception('شما قبلاً عضو این کانال هستید');
      }

      // افزودن کاربر به کانال
      await _supabase.from('channel_members').insert({
        'channel_id': channelId,
        'user_id': userId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // افزایش تعداد اعضا
      await _supabase.rpc('increment_channel_member_count',
          params: {'channel_id_param': channelId});

      // آپدیت کش
      // Channel cache removed
      // Channel cache removed

      logInfo('با موفقیت به کانال پیوستید');
    } catch (e) {
      logInfo('خطا در پیوستن به کانال: $e');
      rethrow;
    }
  }

  // ترک کانال
  Future<void> leaveChannel(String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی نقش کاربر
      final memberInfo = await _supabase
          .from('channel_members')
          .select('role')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .maybeSingle();

      if (memberInfo == null) {
        throw Exception('شما عضو این کانال نیستید');
      }

      if (memberInfo['role'] == 'owner') {
        throw Exception('مالک کانال نمی‌تواند کانال را ترک کند');
      }

      // حذف کاربر از کانال
      await _supabase
          .from('channel_members')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', userId);

      // کاهش تعداد اعضا
      await _supabase.rpc('decrement_channel_member_count',
          params: {'channel_id_param': channelId});

      // آپدیت کش
      // Channel cache removed
      // Channel cache removed

      logInfo('با موفقیت کانال را ترک کردید');
    } catch (e) {
      logInfo('خطا در ترک کانال: $e');
      rethrow;
    }
  }

  Stream<List<ChannelMessageModel>> getChannelMessagesStream(String channelId) {
    try {
      final userId = _supabase.auth.currentUser!.id;

      return _supabase
          .from('channel_messages')
          .stream(primaryKey: ['id'])
          .eq('channel_id', channelId)
          .order('created_at', ascending: true)
          .map((data) {
            return data
                .where((message) =>
                    message['is_deleted'] != true) // فیلتر پیام‌های حذف شده
                .map<ChannelMessageModel>((messageData) {
              return ChannelMessageModel.fromJson(
                messageData,
                currentUserId: userId,
              );
            }).toList();
          });
    } catch (e) {
      logInfo('خطا در دریافت استریم پیام‌ها: $e');
      rethrow;
    }
  }

  // دریافت پیام‌های کانال با کش (تطبیق با جدول profiles)
  Future<List<ChannelMessageModel>> getChannelMessages(
    String channelId, {
    int limit = 50,
    DateTime? before,
    bool forceRefresh = false,
  }) async {
    try {
      print('Fetching messages for channel $channelId'); // Debug log
      final userId = _supabase.auth.currentUser!.id;

      // بررسی عضویت در کانال
      final permissions = await getUserPermissions(channelId);
      if (!permissions['isMember']!) {
        throw Exception('شما عضو این کانال نیستید');
      }

      // Channel cache removed - always fetch from server

      // دریافت از سرور
      final messages =
          await _fetchMessagesFromServer(channelId, limit, before, userId);
      print('Fetched ${messages.length} messages from server'); // Debug log

      // کش کردن
      if (before == null) {
        // Channel cache removed
      }

      return messages;
    } catch (e) {
      print('Error fetching messages: $e'); // Debug log
      rethrow;
    }
  }

// متد کمکی برای دریافت از سرور
  Future<List<ChannelMessageModel>> _fetchMessagesFromServer(
    String channelId,
    int limit,
    DateTime? before,
    String currentUserId,
  ) async {
    // ابتدا یک PostgrestQueryBuilder یا PostgrestFilterBuilder ایجاد می‌کنیم
    var queryBuilder = _supabase.from('channel_messages').select('''
        id,
        channel_id,
        sender_id,
        content,
        created_at,
        attachment_url,
        attachment_type,
        views_count,
        reply_to_message_id,
        reply_to_content,
        reply_to_sender_name
      ''').eq('channel_id', channelId).eq('is_deleted', false);

    // فیلتر 'lt' را قبل از 'order' و 'limit' اعمال می‌کنیم
    if (before != null) {
      queryBuilder = queryBuilder.lt('created_at', before.toIso8601String());
    }

    // سپس 'order' و 'limit' را اعمال کرده و کوئری را اجرا می‌کنیم
    final response =
        await queryBuilder.order('created_at', ascending: false).limit(limit);

    // دریافت اطلاعات فرستندگان
    final senderIds =
        response.map((msg) => msg['sender_id'] as String).toSet().toList();

    // دریافت profiles فرستندگان
    final profiles = await _supabase
        .from('profiles')
        .select(
            'id, username, full_name, avatar_url, is_verified, verification_type, is_online, role')
        .inFilter('id', senderIds);

    final profilesMap = {for (var profile in profiles) profile['id']: profile};

    return response.map<ChannelMessageModel>((data) {
      final senderId = data['sender_id'] as String;
      final profile = profilesMap[senderId];

      // اضافه کردن اطلاعات profile
      if (profile != null) {
        data['sender_name'] = profile['username'] ?? profile['full_name'];
        data['sender_avatar'] = profile['avatar_url'];
        data['sender_verified'] = profile['is_verified'] ?? false;
        data['sender_verification_type'] = profile['verification_type'];
        data['sender_online'] = profile['is_online'] ?? false;
        data['sender_role'] = profile['role'];
      }

      return ChannelMessageModel.fromJson(data, currentUserId: currentUserId);
    }).toList();
  }

  // ارسال پیام با آپلود تصویر به آروان

  Future<ChannelMessageModel> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
    File? imageFile,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی مجوزات
      final permissions = await getUserPermissions(channelId);
      if (!permissions['canSendMessage']!) {
        throw Exception('شما مجوز ارسال پیام در این کانال را ندارید');
      }

      String? imageUrl;
      String messageType = 'text';

      // آپلود تصویر (اگر وجود داشته باشد)
      if (imageFile != null) {
        imageUrl = await _uploadImageToArvan(imageFile, 'channel_messages');
        if (imageUrl == null) {
          throw Exception('خطا در آپلود تصویر');
        }
        messageType = 'image';
      }

      // دریافت اطلاعات پیام reply (اگر وجود داشته باشد)
      String? replyToContent;
      String? replyToSenderName;
      if (replyToMessageId != null) {
        final replyMessage = await _supabase.from('channel_messages').select('''
              content,
              profiles!channel_messages_sender_id_fkey(username)
            ''').eq('id', replyToMessageId).single();

        replyToContent = replyMessage['content'];
        replyToSenderName = replyMessage['profiles']['username'];
      }

      // ارسال پیام
      final messageData = await _supabase.from('channel_messages').insert({
        'channel_id': channelId,
        'sender_id': userId,
        'content': content.trim().isEmpty ? null : content.trim(),
        'image_url': imageUrl,
        'message_type': messageType,
        'reply_to_message_id': replyToMessageId,
        'reply_to_content': replyToContent,
        'reply_to_sender_name': replyToSenderName,
      }).select('''
            *,
            profiles!channel_messages_sender_id_fkey(
              id,
              username,
              avatar_url
            )
          ''').single();

      // تبدیل به مدل
      final message = ChannelMessageModel.fromJson(
        {
          ...messageData,
          'sender_name': messageData['profiles']['username'],
          'sender_avatar': messageData['profiles']['avatar_url'],
        },
        currentUserId: userId,
      );

      logInfo('پیام با موفقیت ارسال شد');
      return message;
    } catch (e) {
      logInfo('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  // 🗑️ حذف پیام
  // 🗑️ حذف پیام
  Future<void> deleteMessage(String messageId, String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی مجوزات
      final permissions = await getUserPermissions(channelId);

      // دریافت اطلاعات پیام برای بررسی مالکیت
      final messageData = await _supabase
          .from('channel_messages')
          .select('sender_id, image_url')
          .eq('id', messageId)
          .single();

      final isOwner = messageData['sender_id'] == userId;
      final canDelete = permissions['canDeleteMessage'] == true || isOwner;

      if (!canDelete) {
        throw Exception('شما مجوز حذف این پیام را ندارید');
      }

      // حذف تصویر از آروان (اگر وجود داشته باشد)
      if (messageData['image_url'] != null) {
        await _deleteImageFromArvan(messageData['image_url']);
      }

      // به‌روزرسانی پیام به جای حذف فیزیکی
      await _supabase.from('channel_messages').update({
        'is_deleted': true,
        'deleted_by': userId,
        'content': null, // پاک کردن محتوا
        'image_url': null, // پاک کردن لینک تصویر
        'attachment_url': null, // پاک کردن ضمیمه
      }).eq('id', messageId);

      logInfo('پیام با موفقیت حذف شد');
    } catch (e) {
      logInfo('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  // ✏️ ویرایش پیام
  Future<ChannelMessageModel> editMessage(
      String messageId, String channelId, String newContent) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی مالکیت پیام
      final messageData = await _supabase
          .from('channel_messages')
          .select('sender_id, is_deleted')
          .eq('id', messageId)
          .single();

      if (messageData['sender_id'] != userId) {
        throw Exception('شما فقط می‌توانید پیام‌های خود را ویرایش کنید');
      }

      if (messageData['is_deleted'] == true) {
        throw Exception('نمی‌توان پیام حذف شده را ویرایش کرد');
      }

      // به‌روزرسانی پیام
      final updatedData = await _supabase
          .from('channel_messages')
          .update({
            'content': newContent.trim(),
            'is_edited': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .select('''
            *,
            profiles!channel_messages_sender_id_fkey(
              id,
              username,
              avatar_url
            )
          ''')
          .single();

      // تبدیل به مدل
      final editedMessage = ChannelMessageModel.fromJson(
        {
          ...updatedData,
          'sender_name': updatedData['profiles']['username'],
          'sender_avatar': updatedData['profiles']['avatar_url'],
        },
        currentUserId: userId,
      );

      logInfo('پیام با موفقیت ویرایش شد');
      return editedMessage;
    } catch (e) {
      logInfo('خطا در ویرایش پیام: $e');
      rethrow;
    }
  }

  // 📊 آمار پیام‌های حذف شده (برای ادمین)
  Future<Map<String, int>> getChannelDeletedMessagesStats(
      String channelId) async {
    try {
      final permissions = await getUserPermissions(channelId);
      if (!(permissions['canManageChannel'] ?? false)) {
        throw Exception('شما مجوز دسترسی به این آمار را ندارید');
      }

      final response = await _supabase
          .from('channel_messages')
          .select('is_deleted')
          .eq('channel_id', channelId);

      int totalMessages = response.length;
      int deletedMessages =
          response.where((msg) => msg['is_deleted'] == true).length;
      int activeMessages = totalMessages - deletedMessages;

      return {
        'total': totalMessages,
        'active': activeMessages,
        'deleted': deletedMessages,
      };
    } catch (e) {
      logInfo('خطا در گرفتن آمار: $e');
      rethrow;
    }
  }

  // جستجو در پیام‌ها
  Future<List<ChannelMessageModel>> searchMessages(
    String channelId,
    String query, {
    int limit = 20,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی عضویت در کانال
      final permissions = await getUserPermissions(channelId);
      if (!permissions['isMember']!) {
        throw Exception('شما عضو این کانال نیستید');
      }

      // جستجو در پیام‌ها
      final response = await _supabase
          .from('channel_messages')
          .select('''
          id,
          channel_id,
          sender_id,
          content,
          created_at,
          attachment_url,
          attachment_type,
          views_count,
          reply_to_message_id,
          reply_to_content,
          reply_to_sender_name,
          is_edited,
          edited_at
        ''')
          .eq('channel_id', channelId)
          .eq('is_deleted', false)
          .ilike('content', '%$query%')
          .order('created_at', ascending: true)
          .limit(limit);

      // دریافت اطلاعات فرستندگان
      final senderIds =
          response.map((msg) => msg['sender_id'] as String).toSet().toList();

      if (senderIds.isEmpty) {
        return [];
      }

      // دریافت profiles فرستندگان
      final profiles = await _supabase.from('profiles').select('''
          id, 
          username, 
          full_name, 
          avatar_url, 
          is_verified, 
          verification_type, 
          is_online, 
          role
        ''').inFilter('id', senderIds);

      final profilesMap = {
        for (var profile in profiles) profile['id']: profile
      };

      return response.map<ChannelMessageModel>((data) {
        final senderId = data['sender_id'] as String;
        final profile = profilesMap[senderId];

        // اضافه کردن اطلاعات profile
        if (profile != null) {
          data['sender_name'] = profile['username'] ?? profile['full_name'];
          data['sender_avatar'] = profile['avatar_url'];
          data['sender_verified'] = profile['is_verified'] ?? false;
          data['sender_verification_type'] = profile['verification_type'];
          data['sender_online'] = profile['is_online'] ?? false;
          data['sender_role'] = profile['role'];
        }

        return ChannelMessageModel.fromJson(data, currentUserId: userId);
      }).toList();
    } catch (e) {
      logInfo('خطا در جستجوی پیام‌ها: $e');
      rethrow;
    }
  }

  // دریافت لیست اعضا با نقش‌هاشون (تطبیق با جدول profiles)
  Future<List<Map<String, dynamic>>> getChannelMembers(String channelId) async {
    try {
      final response = await _supabase
          .from('channel_members')
          .select('''
            user_id,
            role,
            joined_at,
            profiles!channel_members_user_id_fkey(
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type,
              account_status,
              role,
              is_online,
              last_online
            )
          ''')
          .eq('channel_id', channelId)
          .order('role', ascending: true)
          .order('joined_at', ascending: true);

      return response.map<Map<String, dynamic>>((member) {
        final userData = member['profiles'] as Map<String, dynamic>;
        return {
          'userId': member['user_id'],
          'channelRole': member['role'],
          'joinedAt': member['joined_at'],
          'username': userData['username'],
          'fullName': userData['full_name'],
          'avatarUrl': userData['avatar_url'],
          'isVerified': userData['is_verified'],
          'verificationType': userData['verification_type'],
          'accountStatus': userData['account_status'],
          'systemRole': userData['role'],
          'isOnline': userData['is_online'],
          'lastOnline': userData['last_online'],
        };
      }).toList();
    } catch (e) {
      logInfo('خطا در دریافت اعضا: $e');
      rethrow;
    }
  }

  // تغییر نقش عضو
  Future<void> updateMemberRole(
      String channelId, String memberId, String newRole) async {
    try {
      final permissions = await getUserPermissions(channelId);
      if (permissions['canManageMembers']!) {
        throw Exception('شما مجاز به تغییر نقش اعضا نیستید');
      }

      // دریافت اطلاعات عضو هدف
      final targetMemberInfo =
          await _supabase.from('channel_members').select('''
            role,
            profiles!channel_members_user_id_fkey(
              role,
              account_status
            )
          ''').eq('channel_id', channelId).eq('user_id', memberId).single();

      // بررسی وضعیت حساب کاربری
      final profileData = targetMemberInfo['profiles'] as Map<String, dynamic>;
      if (profileData['account_status'] != 'active') {
        throw Exception('حساب کاربری این عضو فعال نیست');
      }

      // owner نمیتونه نقشش تغییر کنه
      if (targetMemberInfo['role'] == 'owner') {
        throw Exception('نقش مالک کانال قابل تغییر نیست');
      }

      // بررسی نقش‌های معتبر
      final validRoles = ['member', 'moderator', 'admin'];
      if (!validRoles.contains(newRole)) {
        throw Exception('نقش نامعتبر');
      }

      // آپدیت نقش
      await _supabase
          .from('channel_members')
          .update({'role': newRole})
          .eq('channel_id', channelId)
          .eq('user_id', memberId);

      logInfo('نقش عضو با موفقیت تغییر کرد');
    } catch (e) {
      logInfo('خطا در تغییر نقش: $e');
      rethrow;
    }
  }

  // اخراج عضو
  Future<void> removeMember(String channelId, String memberId) async {
    try {
      final permissions = await getUserPermissions(channelId);
      if (!permissions['canManageMembers']!) {
        throw Exception('شما مجاز به اخراج اعضا نیستید');
      }

      // owner رو نمیشه اخراج کرد
      final targetMemberInfo = await _supabase
          .from('channel_members')
          .select('role')
          .eq('channel_id', channelId)
          .eq('user_id', memberId)
          .single();

      if (targetMemberInfo['role'] == 'owner') {
        throw Exception('مالک کانال قابل اخراج نیست');
      }

      // حذف عضو
      await _supabase
          .from('channel_members')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', memberId);

      // کاهش تعداد اعضا
      await _supabase.rpc('decrement_channel_member_count',
          params: {'channel_id_param': channelId});

      logInfo('عضو با موفقیت اخراج شد');
    } catch (e) {
      logInfo('خطا در اخراج عضو: $e');
      rethrow;
    }
  }

  // آپدیت تنظیمات کانال با آپلود آواتار جدید
  Future<ChannelModel> updateChannelSettings({
    required String channelId,
    String? name,
    String? description,
    String? username,
    bool? isPrivate,
    File? avatarFile,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی مجوز
      final permissions = await getUserPermissions(channelId);
      if (!permissions['canEditChannel']!) {
        throw Exception('شما مجاز به ویرایش کانال نیستید');
      }

      String? newAvatarUrl;

      // آپلود آواتار جدید در صورت وجود
      if (avatarFile != null) {
        // دریافت آواتار قبلی برای حذف
        final currentChannel = await _supabase
            .from('channels')
            .select('avatar_url')
            .eq('id', channelId)
            .single();

        // آپلود آواتار جدید
        newAvatarUrl = await _uploadImageToArvan(avatarFile, 'channel_avatars');

        // حذف آواتار قبلی
        if (currentChannel['avatar_url'] != null) {
          await _deleteImageFromArvan(currentChannel['avatar_url']);
        }
      }

      // آماده کردن داده‌های آپدیت
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (username != null) updateData['username'] = username;
      if (isPrivate != null) updateData['is_private'] = isPrivate;
      if (newAvatarUrl != null) updateData['avatar_url'] = newAvatarUrl;

      // آپدیت کانال
      final response = await _supabase
          .from('channels')
          .update(updateData)
          .eq('id', channelId)
          .select()
          .single();

      // دریافت نقش کاربر
      final memberInfo = await _supabase
          .from('channel_members')
          .select('role, joined_at')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .single();

      final channel = ChannelModel.fromJson({
        ...response,
        'member_role': memberInfo['role'],
        'joined_at': memberInfo['joined_at'],
      }, currentUserId: userId);

      // آپدیت کش
      // Channel cache removed
      // Channel cache removed

      logInfo('تنظیمات کانال با موفقیت آپدیت شد');
      return channel;
    } catch (e) {
      logInfo('خطا در آپدیت تنظیمات کانال: $e');
      rethrow;
    }
  }

  // حذف کانال
  Future<void> deleteChannel(String channelId) async {
    try {
      final permissions = await getUserPermissions(channelId);
      if (!permissions['canDeleteChannel']!) {
        throw Exception('شما مجاز به حذف کانال نیستید');
      }

      // دریافت تمام پیام‌های دارای تصویر برای حذف از آروان
      final messagesWithImages = await _supabase
          .from('channel_messages')
          .select('image_url')
          .eq('channel_id', channelId)
          .not('image_url', 'is', null);

      // حذف تصاویر پیام‌ها از آروان
      for (final message in messagesWithImages) {
        if (message['image_url'] != null) {
          await _deleteImageFromArvan(message['image_url']);
        }
      }

      // دریافت آواتار کانال برای حذف
      final channelInfo = await _supabase
          .from('channels')
          .select('avatar_url')
          .eq('id', channelId)
          .single();

      // حذف آواتار کانال از آروان
      if (channelInfo['avatar_url'] != null) {
        await _deleteImageFromArvan(channelInfo['avatar_url']);
      }

      // حذف کانال (cascade delete برای members و messages)
      await _supabase.from('channels').delete().eq('id', channelId);

      // پاک کردن کش
      // Channel cache removed
      // Channel cache removed

      logInfo('کانال با موفقیت حذف شد');
    } catch (e) {
      logInfo('خطا در حذف کانال: $e');
      rethrow;
    }
  }

  // پاک کردن کش
  Future<void> clearCache() async {
    try {
      // Channel cache removed
    } catch (e) {
      logInfo('خطا در پاک کردن کش: $e');
      rethrow;
    }
  }

  // دریافت آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return {'cache_size_kb': 0.0, 'item_count': 0};
    } catch (e) {
      logInfo('خطا در دریافت آمار کش: $e');
      rethrow;
    }
  }

  // Channel cache methods removed
}
