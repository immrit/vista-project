import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../services/message_forward_service.dart';
import '../../../services/user_friendly_error_handler.dart';

final messageForwardServiceProvider = Provider((ref) {
  return MessageForwardService();
});

class ForwardMessageSheet extends ConsumerStatefulWidget {
  final List<String> messageIds;
  final VoidCallback? onSuccess;

  const ForwardMessageSheet({
    super.key,
    required this.messageIds,
    this.onSuccess,
  });

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
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  final Set<String> _selectedUsers = {};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHandleBar(),
          _buildHeader(theme),
          _buildSearchBar(theme),
          Expanded(child: _buildUsersGrid(theme)),
          if (_selectedUsers.isNotEmpty) _buildSendButton(theme),
        ],
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            'فوروارد پیام',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const Spacer(),
          if (_selectedUsers.isNotEmpty)
            Text(
              '${_selectedUsers.length} انتخاب شده',
              style: TextStyle(
                fontSize: 14,
                color: theme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 40,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'جستجو',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildUsersGrid(ThemeData theme) {
    // ✅ استفاده از provider بهینه‌شده
    final state = ref.watch(optimizedConversationsProvider);

    // Loading state
    if (state.status == ConversationsStatus.loading ||
        state.status == ConversationsStatus.initial) {
      if (state.conversations.isEmpty) {
        return _buildLoadingState(theme);
      }
    }

    // Error state
    if (state.status == ConversationsStatus.error &&
        state.conversations.isEmpty) {
      return _buildErrorState(theme, state.errorMessage ?? 'خطای نامشخص');
    }

    // Filter conversations
    final filteredConversations = state.conversations.where((conversation) {
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      return conversation.otherUserName?.toLowerCase().contains(searchLower) ==
          true;
    }).toList();

    if (filteredConversations.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildInstagramStyleGrid(theme, filteredConversations);
  }

  Widget _buildInstagramStyleGrid(
      ThemeData theme, List<dynamic> conversations) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        // Ensure we handle ConversationModel
        return _buildInstagramStyleUserCard(theme, conversation, index);
      },
    );
  }

  Widget _buildInstagramStyleUserCard(
      ThemeData theme, dynamic conversation, int index) {
    // Assuming conversation.otherUserId and otherUserName are available
    // conversations based on ConversationModel
    final userName = conversation.otherUserName ?? 'Unknown';
    final userAvatar = conversation.otherUserAvatar;

    final isSelected = _selectedUsers.contains(conversation.id);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => _toggleUserSelection(conversation.id),
            child: Column(
              children: [
                // دایره آواتار
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: userAvatar != null && userAvatar.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: userAvatar,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    _buildDefaultAvatar(theme, userName),
                              )
                            : _buildDefaultAvatar(theme, userName),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // نام کاربری
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme, String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'در حال بارگذاری مکالمات...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری مکالمات',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(optimizedConversationsProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'مکالمه‌ای یافت نشد' : 'نتیجه‌ای یافت نشد',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _forwardToSelectedUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'فوروارد به ${_selectedUsers.length} مکالمه',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUserSelection(String conversationId) {
    setState(() {
      if (_selectedUsers.contains(conversationId)) {
        _selectedUsers.remove(conversationId);
      } else {
        _selectedUsers.add(conversationId);
      }
    });
  }

  Future<void> _forwardToSelectedUsers() async {
    if (_isLoading || _selectedUsers.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(messageForwardServiceProvider);
      final result = await service.forwardMultiple(
        messageIds: widget.messageIds,
        targetConversationIds: _selectedUsers.toList(),
      );

      if (mounted) {
        if (result.isSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('پیام با موفقیت فوروارد شد'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        } else {
          _showErrorMessage(result.error ?? 'خطا در ارسال');
        }
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorHandler.logError(e, context: 'forward_message');
        _showErrorMessage(UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'forward_message'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorMessage(String error) {
    final friendlyMessage = UserFriendlyErrorHandler.getFriendlyMessage(
      error,
      context: 'forward_message',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(friendlyMessage)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
