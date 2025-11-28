// lib/features/chat/widgets/forward_message_sheet.dart
//
// صفحه انتخاب مکالمه برای فوروارد - با الهام از تلگرام
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_forward_service.dart';
import '../theme/chat_theme.dart';

/// مدل مکالمه ساده برای نمایش
class ConversationItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isGroup;

  const ConversationItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isGroup = false,
  });
}

class ForwardMessageSheet extends ConsumerStatefulWidget {
  final List<String> messageIds;
  final VoidCallback? onSuccess;

  const ForwardMessageSheet({
    super.key,
    required this.messageIds,
    this.onSuccess,
  });

  /// نمایش bottom sheet
  static Future<bool?> show(
    BuildContext context, {
    required List<String> messageIds,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardMessageSheet(messageIds: messageIds),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  
  List<ConversationItem> _conversations = [];
  List<ConversationItem> _filteredConversations = [];
  bool _isLoading = true;
  bool _isForwarding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _error = 'کاربر احراز هویت نشده';
            _isLoading = false;
          });
        }
        return;
      }

      // دریافت مکالمات کاربر
      final response = await Supabase.instance.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      if (response.isEmpty) {
        if (mounted) {
          setState(() {
            _conversations = [];
            _filteredConversations = [];
            _isLoading = false;
          });
        }
        return;
      }

      final conversationIds = (response as List)
          .map((e) => e['conversation_id'] as String?)
          .whereType<String>()
          .toList();

      final List<ConversationItem> items = [];

      // برای هر مکالمه، اطلاعات رو بگیر
      for (final convId in conversationIds) {
        try {
          // دریافت اطلاعات مکالمه
          final convData = await Supabase.instance.client
              .from('conversations')
              .select('id, type, name, image')
              .eq('id', convId)
              .maybeSingle();

          if (convData == null) continue;

          final convIdValue = convData['id'] as String?;
          if (convIdValue == null) continue;

          final convType = convData['type'] as String?;
          final isGroup = convType == 'group' || convType == 'channel';

          if (isGroup) {
            // مکالمه گروهی
            items.add(ConversationItem(
              id: convIdValue,
              name: (convData['name'] as String?) ?? 'گروه',
              avatarUrl: convData['image'] as String?,
              isGroup: true,
            ));
          } else {
            // مکالمه خصوصی - پیدا کردن طرف مقابل
            final otherUserResponse = await Supabase.instance.client
                .from('conversation_participants')
                .select('user_id')
                .eq('conversation_id', convId)
                .neq('user_id', userId)
                .limit(1)
                .maybeSingle();

            if (otherUserResponse != null) {
              final otherUserId = otherUserResponse['user_id'] as String?;
              
              if (otherUserId != null) {
                // دریافت پروفایل کاربر
                final profileResponse = await Supabase.instance.client
                    .from('profiles')
                    .select('full_name, avatar_url')
                    .eq('id', otherUserId)
                    .maybeSingle();

                if (profileResponse != null) {
                  items.add(ConversationItem(
                    id: convIdValue,
                    name: (profileResponse['full_name'] as String?) ?? 'کاربر',
                    avatarUrl: profileResponse['avatar_url'] as String?,
                    isGroup: false,
                  ));
                }
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error loading conversation $convId: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _conversations = items;
          _filteredConversations = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _error = 'خطا در بارگذاری مکالمات';
          _isLoading = false;
        });
      }
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations
          .where((c) => c.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _forward() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isForwarding = true);

    try {
      // استفاده از سرویس فوروارد که قبلاً نوشتیم
      final service = ref.read(messageForwardServiceProvider);
      final result = await service.forwardMultiple(
        messageIds: widget.messageIds,
        targetConversationIds: _selectedIds.toList(),
      );

      if (mounted) {
        if (result.isSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'پیام${widget.messageIds.length > 1 ? '‌ها' : ''} به ${_selectedIds.length} مکالمه فوروارد شد',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _error = result.error ?? 'خطا در فوروارد پیام';
            _isForwarding = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isForwarding = false;
        });
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
                  Icons.forward_rounded,
                  color: theme.sendButtonColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فوروارد به...',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        Text(
                          '${_selectedIds.length} انتخاب شده',
                          style: TextStyle(
                            color: theme.sendButtonColor,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isForwarding ? null : _forward,
                    icon: _isForwarding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: const Text('فوروارد'),
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

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                hintText: 'جستجو...',
                hintStyle: TextStyle(color: theme.secondaryTextColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.secondaryTextColor,
                ),
                filled: true,
                fillColor: theme.inputBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Error
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.errorColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.sendButtonColor,
                    ),
                  )
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: theme.secondaryTextColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'مکالمه‌ای یافت نشد',
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conv = _filteredConversations[index];
                          final isSelected = _selectedIds.contains(conv.id);

                          return ListTile(
                            onTap: () => _toggleSelection(conv.id),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      theme.sendButtonColor.withOpacity(0.1),
                                  backgroundImage: conv.avatarUrl != null
                                      ? NetworkImage(conv.avatarUrl!)
                                      : null,
                                  child: conv.avatarUrl == null
                                      ? Text(
                                          conv.name.isNotEmpty
                                              ? conv.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: theme.sendButtonColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: theme.sendButtonColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.backgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              conv.name,
                              style: TextStyle(
                                color: theme.textColor,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: conv.isGroup
                                ? Text(
                                    'گروه',
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.sendButtonColor,
                                  )
                                : null,
                          );
                        },
                      ),
          ),

          // Safe area
          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }
}

// Provider برای سرویس فوروارد
final messageForwardServiceProvider = Provider((ref) {
  return MessageForwardService();
});

