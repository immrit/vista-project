import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';
import '../DB/channel_cache_service.dart';
import '/main.dart';

class ChannelService {
  final SupabaseClient _supabase = supabase;
  final ChannelCacheService _cache = ChannelCacheService();

  // Singleton pattern
  static final ChannelService _instance = ChannelService._internal();
  factory ChannelService() => _instance;
  ChannelService._internal();

  // مقداردهی اولیه
  Future<void> initialize() async {
    await _cache.initialize();
  }

  // 📸 آپلود تصویر به آروان کلود
  Future<String?> _uploadImageToArvan(File imageFile, String folder) async {
    try {
      const String accessKey = 'YOUR_ARVAN_ACCESS_KEY';
      const String secretKey = 'YOUR_ARVAN_SECRET_KEY';
      const String bucketName = 'YOUR_BUCKET_NAME';
      const String endpoint = 'https://s3.ir-thr-at1.arvanstorage.ir';

      // ساخت نام فایل یونیک
      final String fileName =
          '${folder}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

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
        print('تصویر با موفقیت آپلود شد: $imageUrl');
        return imageUrl;
      } else {
        print('خطا در آپلود تصویر: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('خطا در آپلود تصویر به آروان: $e');
      return null;
    }
  }

  // 🗑️ حذف تصویر از آروان کلود
  Future<bool> _deleteImageFromArvan(String imageUrl) async {
    try {
      const String accessKey = 'YOUR_ARVAN_ACCESS_KEY';
      const String secretKey = 'YOUR_ARVAN_SECRET_KEY';
      const String bucketName = 'YOUR_BUCKET_NAME';
      const String endpoint = 'https://s3.ir-thr-at1.arvanstorage.ir';

      // استخراج نام فایل از URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.skip(1).join('/'); // حذف bucket name

      // ساخت URL برای حذف
      final deleteUri = Uri.parse('$endpoint/$bucketName/$fileName');

      // ارسال درخواست DELETE
      final response = await http.delete(deleteUri);

      if (response.statusCode == 204 || response.statusCode == 200) {
        print('تصویر با موفقیت حذف شد');
        return true;
      } else {
        print('خطا در حذف تصویر: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('خطا در حذف تصویر از آروان: $e');
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
      print('خطا در بررسی مجوزها: $e');
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

      // اگر force refresh نباشه، اول کش رو چک کن
      if (!forceRefresh) {
        final cachedChannels = await _cache.getCachedChannels();
        if (cachedChannels.isNotEmpty) {
          print('${cachedChannels.length} کانال از کش بارگذاری شد');

          // در پس‌زمینه آپدیت کن
          _refreshChannelsInBackground(userId);

          return cachedChannels;
        }
      }

      // دریافت از سرور
      final channels = await _fetchChannelsFromServer(userId);

      // کش کردن
      await _cache.cacheChannels(channels);

      print('${channels.length} کانال از سرور دریافت و کش شد');
      return channels;
    } catch (e) {
      print('خطا در دریافت کانال‌ها: $e');

      // در صورت خطا، کش رو برگردون
      final cachedChannels = await _cache.getCachedChannels();
      if (cachedChannels.isNotEmpty) {
        print('در صورت خطا، ${cachedChannels.length} کانال از کش برگردانده شد');
        return cachedChannels;
      }

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
        ''').eq('user_id', userId).order('joined_at', ascending: false);

    return response.map<ChannelModel>((data) {
      final channelData = Map<String, dynamic>.from(data['channels']);
      channelData['member_role'] = data['role'];
      channelData['joined_at'] = data['joined_at'];
      return ChannelModel.fromJson(channelData, currentUserId: userId);
    }).toList();
  }

  // آپدیت در پس‌زمینه
  void _refreshChannelsInBackground(String userId) async {
    try {
      final channels = await _fetchChannelsFromServer(userId);
      await _cache.cacheChannels(channels);
      print('کش کانال‌ها در پس‌زمینه آپدیت شد');
    } catch (e) {
      print('خطا در آپدیت پس‌زمینه: $e');
    }
  }

  // دریافت یک کانال خاص
  Future<ChannelModel?> getChannel(String channelId,
      {bool forceRefresh = false}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // چک کردن کش
      if (!forceRefresh) {
        final cachedChannel = await _cache.getChannel(channelId);
        if (cachedChannel != null) {
          print('کانال ${cachedChannel.name} از کش بارگذاری شد');

          // آپدیت در پس‌زمینه
          _refreshChannelInBackground(channelId, userId);

          return cachedChannel;
        }
      }

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
      await _cache.cacheChannel(channel);

      return channel;
    } catch (e) {
      print('خطا در دریافت کانال: $e');

      // در صورت خطا، کش رو چک کن
      final cachedChannel = await _cache.getChannel(channelId);
      if (cachedChannel != null) {
        return cachedChannel;
      }

      rethrow;
    }
  }

  // آپدیت کانال در پس‌زمینه
  void _refreshChannelInBackground(String channelId, String userId) async {
    try {
      final channel = await getChannel(channelId, forceRefresh: true);
      if (channel != null) {
        await _cache.cacheChannel(channel);
        print('کش کانال $channelId در پس‌زمینه آپدیت شد');
      }
    } catch (e) {
      print('خطا در آپدیت کانال در پس‌زمینه: $e');
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
      await _cache.cacheChannel(channel);
      await _cache.clearChannelsCache(); // برای آپدیت لیست

      print('کانال ${channel.name} با موفقیت ایجاد شد');
      return channel;
    } catch (e) {
      print('خطا در ایجاد کانال: $e');
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
      await _invalidateChannelCache(channelId);
      await _cache.clearChannelsCache();

      print('با موفقیت به کانال پیوستید');
    } catch (e) {
      print('خطا در پیوستن به کانال: $e');
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
      await _invalidateChannelCache(channelId);
      await _cache.clearChannelsCache();

      print('با موفقیت کانال را ترک کردید');
    } catch (e) {
      print('خطا در ترک کانال: $e');
      rethrow;
    }
  }

  Stream<List<ChannelMessageModel>> getChannelMessagesStream(String channelId) {
    try {
      return _supabase
          .from('channel_messages')
          .stream(primaryKey: ['id'])
          .eq('channel_id', channelId)
          .order('created_at', ascending: false) // جدیدترین اول
          .map((data) {
            final messages = data.map((json) {
              return ChannelMessageModel.fromJson(json);
            }).toList();

            // کش کردن پیام‌ها
            _cache.cacheChannelMessages(channelId, messages);

            print('Real-time: ${messages.length} پیام دریافت شد');
            return messages;
          });
    } catch (e) {
      print('خطا در stream پیام‌ها: $e');
      return Stream.error(e);
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

      // چک کردن کش
      if (!forceRefresh && before == null) {
        final cachedMessages = await _cache.getChannelMessages(channelId);
        print(
            'Loaded ${cachedMessages.length} messages from cache'); // Debug log
        if (cachedMessages.isNotEmpty) {
          _refreshMessagesInBackground(channelId, limit);
          return cachedMessages;
        }
      }

      // دریافت از سرور
      final messages =
          await _fetchMessagesFromServer(channelId, limit, before, userId);
      print('Fetched ${messages.length} messages from server'); // Debug log

      // کش کردن
      if (before == null) {
        await _cache.cacheChannelMessages(channelId, messages);
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
      ''').eq('channel_id', channelId);

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

  // آپدیت پیام‌ها در پس‌زمینه
  void _refreshMessagesInBackground(String channelId, int limit) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final messages =
          await _fetchMessagesFromServer(channelId, limit, null, userId);
      await _cache.cacheChannelMessages(channelId, messages);
      print('کش پیام‌ها در پس‌زمینه آپدیت شد');
    } catch (e) {
      print('خطا در آپدیت پس‌زمینه پیام‌ها: $e');
    }
  }

  // ارسال پیام با آپلود تصویر به آروان

  Future<ChannelMessageModel> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId, // تغییر نام
    File? imageFile,
  }) async {
    try {
      final message = await _sendMessageLogic(
        channelId: channelId,
        content: content,
        replyToMessageId: replyToMessageId,
        imageFile: imageFile,
      );

      // به‌روزرسانی کش پیام‌ها
      await _cache.cacheChannelMessage(channelId, message);

      return message;
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  Future<ChannelMessageModel> _sendMessageLogic({
    required String channelId,
    required String content,
    String? replyToMessageId,
    File? imageFile,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // بررسی مجوز ارسال پیام
      final permissions = await getUserPermissions(channelId);
      if (!permissions['canSendMessage']!) {
        throw Exception('شما مجاز به ارسال پیام در این کانال نیستید');
      }

      String? attachmentUrl;
      String? attachmentType;

      // آپلود تصویر در صورت وجود
      if (imageFile != null) {
        try {
          attachmentUrl =
              await _uploadImageToArvan(imageFile, 'channel_messages');
          attachmentType = 'image';
        } catch (e) {
          print('خطا در آپلود تصویر: $e');
          throw Exception('خطا در آپلود تصویر');
        }
      }

      // آماده‌سازی داده‌های پیام
      final messageData = <String, dynamic>{
        'channel_id': channelId,
        'sender_id': userId,
        'content': content,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'created_at': DateTime.now().toIso8601String(),
      };

      // اضافه کردن reply اگر وجود داشته باشه
      if (replyToMessageId != null) {
        messageData['reply_to_message_id'] = replyToMessageId;

        // دریافت اطلاعات پیام مرجع
        final replyMessage = await _supabase
            .from('channel_messages')
            .select('content, sender_id')
            .eq('id', replyToMessageId)
            .single();

        // دریافت نام فرستنده پیام مرجع
        final senderProfile = await _supabase
            .from('profiles')
            .select('username, full_name')
            .eq('id', replyMessage['sender_id'])
            .single();

        messageData['reply_to_content'] = replyMessage['content'];
        messageData['reply_to_sender_name'] =
            senderProfile['username'] ?? senderProfile['full_name'];
      }

      // ارسال پیام
      final response = await _supabase
          .from('channel_messages')
          .insert(messageData)
          .select()
          .single();

      // آپدیت آخرین پیام کانال
      await _supabase.from('channels').update({
        'last_message': content,
        'last_message_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', channelId);

      // دریافت اطلاعات فرستنده
      final senderProfile = await _supabase
          .from('profiles')
          .select(
              'username, full_name, avatar_url, is_verified, verification_type, is_online, role')
          .eq('id', userId)
          .single();

      // اضافه کردن اطلاعات فرستنده به response
      response['sender_name'] =
          senderProfile['username'] ?? senderProfile['full_name'];
      response['sender_avatar'] = senderProfile['avatar_url'];
      response['sender_verified'] = senderProfile['is_verified'] ?? false;
      response['sender_verification_type'] = senderProfile['verification_type'];
      response['sender_online'] = senderProfile['is_online'] ?? false;
      response['sender_role'] = senderProfile['role'];

      final message =
          ChannelMessageModel.fromJson(response, currentUserId: userId);

      // اضافه کردن به کش
      await _cache.cacheChannelMessage(channelId, message);

      // آپدیت کش کانال
      await _invalidateChannelCache(channelId);

      print('پیام با موفقیت ارسال شد');
      return message;
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  // حذف پیام با حذف تصویر از آروان
  Future<void> deleteMessage(String messageId, String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // دریافت اطلاعات پیام
      final messageInfo = await _supabase
          .from('channel_messages')
          .select('sender_id, image_url')
          .eq('id', messageId)
          .single();

      // بررسی مجوزات
      final permissions = await getUserPermissions(channelId);
      final isOwner = messageInfo['sender_id'] == userId;

      if (!isOwner && !permissions['canDeleteMessage']!) {
        throw Exception('شما مجاز به حذف این پیام نیستید');
      }

      // حذف تصویر از آروان در صورت وجود
      if (messageInfo['image_url'] != null) {
        await _deleteImageFromArvan(messageInfo['image_url']);
      }

      // حذف پیام از دیتابیس
      await _supabase.from('channel_messages').delete().eq('id', messageId);

      // آپدیت کش
      await _cache.clearChannelCache(channelId);

      print('پیام با موفقیت حذف شد');
    } catch (e) {
      print('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  Future<List<ChannelMessageModel>> _fetchChannelMessages(
      String channelId) async {
    final response = await _supabase
        .from('channel_messages')
        .select('''
        id,
        content,
        sender_id,
        channel_id,
        image_url,
        reply_to_message_id,
        created_at,
        updated_at,
        profiles!inner(
          id,
          username,
          full_name,
          avatar_url
        )
      ''')
        .eq('channel_id', channelId)
        .order('created_at',
            ascending: false); // ✅ تغییر به false برای جدیدترین اول

    return response.map<ChannelMessageModel>((data) {
      return ChannelMessageModel.fromJson(data);
    }).toList();
  }

  // جستجو در پیام‌ها
  Future<List<ChannelMessageModel>> searchMessages(
    String channelId,
    String query, {
    int limit = 20,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('channel_messages')
          .select('''
            *,
            profiles!channel_messages_sender_id_fkey(
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type,
              is_online,
              role
            )
          ''')
          .eq('channel_id', channelId)
          .textSearch('content', query)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<ChannelMessageModel>((data) {
        return ChannelMessageModel.fromJson(data, currentUserId: userId);
      }).toList();
    } catch (e) {
      print('خطا در جستجوی پیام‌ها: $e');
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
      print('خطا در دریافت اعضا: $e');
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

      print('نقش عضو با موفقیت تغییر کرد');
    } catch (e) {
      print('خطا در تغییر نقش: $e');
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

      print('عضو با موفقیت اخراج شد');
    } catch (e) {
      print('خطا در اخراج عضو: $e');
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
      await _cache.cacheChannel(channel);
      await _invalidateChannelCache(channelId);

      print('تنظیمات کانال با موفقیت آپدیت شد');
      return channel;
    } catch (e) {
      print('خطا در آپدیت تنظیمات کانال: $e');
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
      await _cache.clearChannelCache(channelId);
      await _cache.clearChannelsCache();

      print('کانال با موفقیت حذف شد');
    } catch (e) {
      print('خطا در حذف کانال: $e');
      rethrow;
    }
  }

  // پاک کردن کش
  Future<void> clearCache() async {
    try {
      await _cache.clearAll();
    } catch (e) {
      print('خطا در پاک کردن کش: $e');
      rethrow;
    }
  }

  // دریافت آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await _cache.getStats();
    } catch (e) {
      print('خطا در دریافت آمار کش: $e');
      rethrow;
    }
  }

  // اضافه کردن متد clearChannelCache
  Future<void> clearChannelCache(String channelId) async {
    await _invalidateChannelCache(channelId);
  }

  // پاک کردن کش کانال
  Future<void> _invalidateChannelCache(String channelId) async {
    await _cache.clearChannelCache(channelId);
  }

  // پاک کردن کل کش
  Future<void> clearAllCache() async {
    await _cache.clearAll();
  }
}
