// lib/features/chat/repositories/chat_details_repository.dart
//
// Repository برای جزئیات چت
//
// ویژگی‌ها:
// ✅ آمار چت (تعداد پیام‌ها، تصاویر، ویدیوها، فایل‌ها)
// ✅ تنظیمات چت (mute, pin, archive)
// ✅ دریافت Media/Files/Links
//

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/const.dart';
import '../../../model/message_model.dart';
import '../../../security/logging_utility.dart';

/// آمار چت
class ChatStatistics {
  final int totalMessages;
  final int imagesCount;
  final int videosCount;
  final int documentsCount;
  final int linksCount;
  final int audioCount;

  const ChatStatistics({
    required this.totalMessages,
    required this.imagesCount,
    required this.videosCount,
    required this.documentsCount,
    required this.linksCount,
    required this.audioCount,
  });
}

/// تنظیمات چت
class ChatSettings {
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final String? wallpaperUrl;

  const ChatSettings({
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.wallpaperUrl,
  });

  ChatSettings copyWith({
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    String? wallpaperUrl,
  }) {
    return ChatSettings(
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
    );
  }
}

/// Repository برای جزئیات چت
class ChatDetailsRepository {
  final SupabaseClient _supabase = supabase;

  /// دریافت آمار چت
  Future<ChatStatistics> getChatStatistics(String conversationId) async {
    try {
      final messages = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      int imagesCount = 0;
      int videosCount = 0;
      int documentsCount = 0;
      int linksCount = 0;
      int audioCount = 0;

      for (final message in messages) {
        final attachmentType = message['attachment_type'] as String?;
        final content = message['content'] as String? ?? '';

        if (attachmentType == 'image') {
          imagesCount++;
        } else if (attachmentType == 'video') {
          videosCount++;
        } else if (attachmentType == 'document') {
          documentsCount++;
        } else if (attachmentType == 'voice' || attachmentType == 'audio') {
          audioCount++;
        }

        // بررسی لینک در محتوا
        if (_hasLink(content)) {
          linksCount++;
        }
      }

      return ChatStatistics(
        totalMessages: messages.length,
        imagesCount: imagesCount,
        videosCount: videosCount,
        documentsCount: documentsCount,
        linksCount: linksCount,
        audioCount: audioCount,
      );
    } catch (e) {
      logInfo('❌ Error getting chat statistics: $e');
      return const ChatStatistics(
        totalMessages: 0,
        imagesCount: 0,
        videosCount: 0,
        documentsCount: 0,
        linksCount: 0,
        audioCount: 0,
      );
    }
  }

  /// دریافت تنظیمات چت
  Future<ChatSettings> getChatSettings(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return const ChatSettings();
      }

      final result = await _supabase
          .from('chat_settings')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (result == null) {
        return const ChatSettings();
      }

      return ChatSettings(
        isMuted: result['is_muted'] as bool? ?? false,
        isPinned: result['is_pinned'] as bool? ?? false,
        isArchived: result['is_archived'] as bool? ?? false,
        wallpaperUrl: result['wallpaper_url'] as String?,
      );
    } catch (e) {
      logInfo('❌ Error getting chat settings: $e');
      return const ChatSettings();
    }
  }

  /// ذخیره تنظیمات چت
  Future<bool> saveChatSettings({
    required String conversationId,
    required ChatSettings settings,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await _supabase.from('chat_settings').upsert({
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'is_muted': settings.isMuted,
        'is_pinned': settings.isPinned,
        'is_archived': settings.isArchived,
        'wallpaper_url': settings.wallpaperUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      return true;
    } catch (e) {
      logInfo('❌ Error saving chat settings: $e');
      return false;
    }
  }

  /// دریافت تصاویر چت
  Future<List<MessageModel>> getChatImages({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('attachment_type', 'image')
          .order('created_at', ascending: false)
          .limit(limit);

      final currentUserId = _supabase.auth.currentUser?.id ?? '';
      return result
          .map((json) =>
              MessageModel.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      logInfo('❌ Error getting chat images: $e');
      return [];
    }
  }

  /// دریافت ویدیوهای چت
  Future<List<MessageModel>> getChatVideos({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('attachment_type', 'video')
          .order('created_at', ascending: false)
          .limit(limit);

      final currentUserId = _supabase.auth.currentUser?.id ?? '';
      return result
          .map((json) =>
              MessageModel.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      logInfo('❌ Error getting chat videos: $e');
      return [];
    }
  }

  /// دریافت فایل‌های چت
  Future<List<MessageModel>> getChatDocuments({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('attachment_type', 'document')
          .order('created_at', ascending: false)
          .limit(limit);

      final currentUserId = _supabase.auth.currentUser?.id ?? '';
      return result
          .map((json) =>
              MessageModel.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      logInfo('❌ Error getting chat documents: $e');
      return [];
    }
  }

  /// دریافت لینک‌های چت
  Future<List<MessageModel>> getChatLinks({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final currentUserId = _supabase.auth.currentUser?.id ?? '';
      final messages = result
          .map((json) =>
              MessageModel.fromJson(json, currentUserId: currentUserId))
          .toList();

      // فیلتر کردن پیام‌هایی که لینک دارند
      return messages.where((msg) => _hasLink(msg.content)).toList();
    } catch (e) {
      logInfo('❌ Error getting chat links: $e');
      return [];
    }
  }

  /// استخراج لینک‌ها از متن
  List<String> extractLinks(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    return urlRegex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  /// بررسی وجود لینک در متن
  bool _hasLink(String text) {
    return extractLinks(text).isNotEmpty;
  }
}
