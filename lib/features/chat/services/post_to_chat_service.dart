// lib/features/chat/services/post_to_chat_service.dart
//
// سرویس ارسال پست به چت
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/forward_message_sheet.dart';
import '../theme/chat_theme.dart';

class PostToChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// ارسال پست به یک یا چند مکالمه
  Future<bool> sharePost({
    required String postId,
    required List<String> conversationIds,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('کاربر احراز هویت نشده');

      // دریافت اطلاعات پست
      final postData = await _getPostData(postId);
      if (postData == null) throw Exception('پست یافت نشد');

      // برای هر مکالمه
      for (final conversationId in conversationIds) {
        // ساخت پیام
        final messageId = _uuid.v4();
        final message = {
          'id': messageId,
          'conversation_id': conversationId,
          'sender_id': userId,
          'content': postData['content'] ?? '',
          'metadata': {
            'type': 'post',
            'post_id': postId,
            'author_name': postData['author_name'],
            'author_avatar': postData['author_avatar'],
            'author_username': postData['author_username'],
            'media_urls': postData['media_urls'],
            'likes_count': postData['likes_count'],
            'comments_count': postData['comments_count'],
            'post_created_at': postData['created_at'],
          },
          'created_at': DateTime.now().toIso8601String(),
        };

        // Insert پیام
        await _supabase.from('messages').insert(message);

        // آپدیت last_message مکالمه
        await _supabase
            .from('conversations')
            .update({
              'last_message_id': messageId,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      return false;
    }
  }

  /// دریافت اطلاعات پست
  Future<Map<String, dynamic>?> _getPostData(String postId) async {
    try {
      // فرض بر این است که جدول posts دارید
      final response = await _supabase
          .from('posts')
          .select('''
            id,
            content,
            created_at,
            likes_count,
            comments_count,
            profiles!posts_user_id_fkey (
              full_name,
              avatar_url,
              username
            ),
            post_media (
              media_url
            )
          ''')
          .eq('id', postId)
          .single();

      final profile = response['profiles'];
      final mediaList = response['post_media'] as List?;

      return {
        'content': response['content'],
        'created_at': response['created_at'],
        'likes_count': response['likes_count'] ?? 0,
        'comments_count': response['comments_count'] ?? 0,
        'author_name': profile?['full_name'] ?? 'کاربر',
        'author_avatar': profile?['avatar_url'],
        'author_username': profile?['username'],
        'media_urls': mediaList?.map((m) => m['media_url']).toList() ?? [],
      };
    } catch (e) {
      debugPrint('❌ Error getting post data: $e');
      return null;
    }
  }

  /// نمایش دیالوگ انتخاب مکالمه برای اشتراک پست
  static Future<bool> showShareDialog(
    BuildContext context, {
    required String postId,
  }) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostShareSheet(postId: postId),
    ) ?? false;
  }
}

/// Provider برای سرویس
final postToChatServiceProvider = Provider((ref) {
  return PostToChatService();
});

// Widget انتخاب مکالمه برای Share Post
class _PostShareSheet extends ConsumerStatefulWidget {
  final String postId;

  const _PostShareSheet({required this.postId});

  @override
  ConsumerState<_PostShareSheet> createState() => _PostShareSheetState();
}

class _PostShareSheetState extends ConsumerState<_PostShareSheet> {
  final _selectedConvIds = <String>{};
  bool _isSharing = false;

  Future<void> _share() async {
    if (_selectedConvIds.isEmpty) return;

    setState(() => _isSharing = true);

    final service = ref.read(postToChatServiceProvider);
    final success = await service.sharePost(
      postId: widget.postId,
      conversationIds: _selectedConvIds.toList(),
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پست به چت‌ها ارسال شد'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ارسال پست'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.share_rounded,
                  color: theme.sendButtonColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اشتراک‌گذاری پست',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedConvIds.isNotEmpty)
                        Text(
                          '${_selectedConvIds.length} انتخاب شده',
                          style: TextStyle(
                            color: theme.sendButtonColor,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedConvIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: const Text('ارسال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.sendButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // استفاده از همان لیست مکالمات از ForwardMessageSheet
          Expanded(
            child: ForwardMessageSheet(
              messageIds: [],
              onSuccess: () {},
            ),
          ),

          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }
}











