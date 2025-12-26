import '../security/logging_utility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/const.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';
import '../services/channel_service.dart';
import 'dart:io';

// پرووایدر سرویس کانال
final channelServiceProvider = Provider<ChannelService>((ref) {
  return ChannelService();
});

// پرووایدر لیست کانال‌ها
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  final channelService = ref.read(channelServiceProvider);
  return await channelService.getChannels();
});

// پرووایدر برای دریافت یک کانال خاص
final channelProvider =
    FutureProvider.family<ChannelModel?, String>((ref, channelId) async {
  final channelService = ref.read(channelServiceProvider);
  return await channelService.getChannel(channelId);
});

// پرووایدر برای دریافت پیام‌های کانال
final channelMessagesProvider =
    StreamProvider.family<List<ChannelMessageModel>, String>(
  (ref, channelId) {
    final channelService = ref.read(channelServiceProvider);
    return channelService.getChannelMessagesStream(channelId);
  },
);

// نوتیفایر برای مدیریت عملیات‌های کانال
class ChannelNotifier extends StateNotifier<AsyncValue<void>> {
  final ChannelService _channelService;
  final Ref ref;

  ChannelNotifier(this._channelService, this.ref)
      : super(const AsyncValue.data(null));

  Future<ChannelModel> createChannel({
    required String name,
    String? description,
    required String username,
    bool isPrivate = false,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    try {
      final channel = await _channelService.createChannel(
        name: name,
        description: description,
        username: username,
        isPrivate: isPrivate,
        avatarFile: avatarFile,
      );
      state = const AsyncValue.data(null);
      return channel;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ✏️ ویرایش پیام
  Future<void> editMessage({
    required String messageId,
    required String channelId,
    required String newContent,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.editMessage(messageId, channelId, newContent);

      // پاک کردن حالت ویرایش
      ref.read(editingMessageProvider.notifier).state = null;
      ref.read(editingContentProvider.notifier).state = '';

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId, String channelId) async {
    try {
      await _channelService.deleteMessage(messageId, channelId);

      // آپدیت stream
      ref.invalidate(channelMessagesProvider(channelId));

      logInfo('پیام با موفقیت حذف شد');
    } catch (e) {
      logInfo('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  // ✅ بروزرسانی متد sendMessage
  Future<ChannelMessageModel> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
    File? imageFile,
  }) async {
    try {
      final message = await _channelService.sendMessage(
        channelId: channelId,
        content: content,
        replyToMessageId: replyToMessageId,
        imageFile: imageFile,
      );

      // ✅ دیگه نیازی به invalidate نیست - stream خودکار بروزرسانی می‌شه!
      logInfo('پیام ارسال شد - stream خودکار بروزرسانی می‌شه');

      return message;
    } catch (e) {
      logInfo('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel(String channelId) async {
    try {
      await _channelService.leaveChannel(channelId);

      // بروزرسانی لیست کانال‌ها
      await loadChannels();

      // Channel cache removed
    } catch (e) {
      logInfo('Error in leaveChannel: $e');
      rethrow;
    }
  }

  Future<void> loadChannels() async {
    try {
      await _channelService.getChannels();
      state = const AsyncValue.data(null);
    } catch (e) {
      logInfo('Error loading channels: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // رفرش کردن لیست کانال‌ها
  Future<List<ChannelModel>> refreshChannels() async {
    try {
      return await _channelService.getChannels(forceRefresh: true);
    } catch (e) {
      logInfo('خطا در رفرش کانال‌ها: $e');
      rethrow;
    }
  }

  // رفرش کردن یک کانال خاص
  Future<ChannelModel?> refreshChannel(String channelId) async {
    try {
      return await _channelService.getChannel(channelId, forceRefresh: true);
    } catch (e) {
      logInfo('خطا در رفرش کانال $channelId: $e');
      rethrow;
    }
  }

  // پاک کردن کش
  Future<void> clearCache() async {
    try {
      await _channelService.clearCache();
    } catch (e) {
      logInfo('خطا در پاک کردن کش: $e');
    }
  }

  // دریافت آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await _channelService.getCacheStats();
    } catch (e) {
      logInfo('خطا در دریافت آمار کش: $e');
      return {};
    }
  }

  Future<void> joinChannel(String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.joinChannel(channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // 🎯 شروع ویرایش پیام
  void startEditingMessage(String messageId, String currentContent) {
    ref.read(editingMessageProvider.notifier).state = messageId;
    ref.read(editingContentProvider.notifier).state = currentContent;
  }

  // 🎯 لغو ویرایش
  void cancelEditing() {
    ref.read(editingMessageProvider.notifier).state = null;
    ref.read(editingContentProvider.notifier).state = '';
  }

  // 🎯 تنظیم پیام برای reply
  void setReplyToMessage(ChannelMessageModel? message) {
    ref.read(replyToMessageProvider.notifier).state = message;
  }

  // 🎯 لغو reply
  void cancelReply() {
    ref.read(replyToMessageProvider.notifier).state = null;
  }
}

final channelNotifierProvider =
    StateNotifierProvider<ChannelNotifier, AsyncValue<void>>((ref) {
  return ChannelNotifier(ref.read(channelServiceProvider), ref);
});

class EditMessageNotifier
    extends StateNotifier<AsyncValue<ChannelMessageModel?>> {
  final ChannelService _channelService;
  final Ref _ref;

  EditMessageNotifier(this._channelService, this._ref)
      : super(const AsyncValue.data(null));

  void resetState() {
    state = const AsyncValue.data(null);
  }
}

final editMessageNotifierProvider = StateNotifierProvider<EditMessageNotifier,
    AsyncValue<ChannelMessageModel?>>(
  (ref) {
    final channelService = ref.read(channelServiceProvider);
    return EditMessageNotifier(channelService, ref);
  },
);

// StateNotifier برای مدیریت حذف پیام
class DeleteMessageNotifier extends StateNotifier<AsyncValue<bool>> {
  final ChannelService _channelService;
  final Ref _ref;

  DeleteMessageNotifier(this._channelService, this._ref)
      : super(const AsyncValue.data(false));

  Future<void> deleteMessage(String messageId, String channelId) async {
    state = const AsyncValue.loading();

    try {
      await _channelService.deleteMessage(messageId, channelId);

      state = const AsyncValue.data(true);

      // رفرش کردن لیست پیام‌ها
      _ref.invalidate(channelMessagesProvider(channelId));

      logInfo('پیام با موفقیت حذف شد');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      logInfo('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  void resetState() {
    state = const AsyncValue.data(false);
  }
}

// پروایدر برای مدیریت حالت ویرایش پیام
final editingMessageProvider = StateProvider<String?>((ref) => null);

// پروایدر برای مدیریت محتوای ویرایش
final editingContentProvider = StateProvider<String>((ref) => '');

// پروایدر برای مدیریت حالت reply
final replyToMessageProvider =
    StateProvider<ChannelMessageModel?>((ref) => null);
final deleteMessageNotifierProvider =
    StateNotifierProvider<DeleteMessageNotifier, AsyncValue<bool>>(
  (ref) {
    final channelService = ref.read(channelServiceProvider);
    return DeleteMessageNotifier(channelService, ref);
  },
);

// Provider برای چک کردن مجوزات پیام
final messagePermissionsProvider =
    FutureProvider.family<Map<String, bool>, Map<String, String>>(
  (ref, params) async {
    final channelService = ref.read(channelServiceProvider);
    final messageId = params['messageId']!;
    final channelId = params['channelId']!;
    final userId = params['userId']!;

    try {
      // بررسی مجوزات کانال
      final channelPermissions =
          await channelService.getUserPermissions(channelId);

      // گرفتن اطلاعات پیام
      final messageInfo = await supabase
          .from('channel_messages')
          .select('sender_id, is_deleted, image_url, created_at')
          .eq('id', messageId)
          .eq('channel_id', channelId)
          .maybeSingle();

      if (messageInfo == null) {
        return {
          'canEdit': false,
          'canDelete': false,
          'canReply': false,
        };
      }

      final isOwner = messageInfo['sender_id'] == userId;
      final isDeleted = messageInfo['is_deleted'] == true;
      final hasImage = messageInfo['image_url'] != null;

      // بررسی محدودیت زمانی برای ویرایش (48 ساعت)
      final createdAt = DateTime.parse(messageInfo['created_at']);
      final isWithinEditTime =
          DateTime.now().difference(createdAt).inHours <= 48;

      return {
        'canEdit': isOwner && !isDeleted && !hasImage && isWithinEditTime,
        'canDelete':
            isOwner || (channelPermissions['canDeleteMessage'] ?? false),
        'canReply':
            !isDeleted && (channelPermissions['canSendMessage'] ?? false),
      };
    } catch (e) {
      logInfo('خطا در بررسی مجوزات پیام: $e');
      return {
        'canEdit': false,
        'canDelete': false,
        'canReply': false,
      };
    }
  },
);
