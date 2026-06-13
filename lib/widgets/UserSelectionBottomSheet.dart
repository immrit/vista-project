import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/publicPostModel.dart';
import '../../model/ProfileModel.dart';
import '../../utils/avatar_asset_utils.dart';

import '../../provider/optimized_conversations_provider.dart';
import '../../features/chat/providers/chat_providers.dart';
import '../../services/user_friendly_error_handler.dart';
import '../../features/chat/domain/message_payload.dart';

class UserSelectionBottomSheet extends ConsumerStatefulWidget {
  final PublicPostModel post;

  const UserSelectionBottomSheet({super.key, required this.post});

  @override
  ConsumerState<UserSelectionBottomSheet> createState() =>
      _UserSelectionBottomSheetState();
}

class _UserSelectionBottomSheetState
    extends ConsumerState<UserSelectionBottomSheet>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  final Set<String> _selectedConversationIds = {};
  late AnimationController _animationController;
  bool _showInfoBanner = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    _loadBannerVisibility();
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
          if (_showInfoBanner) _buildInfoBanner(theme),
          Expanded(child: _buildUsersGrid(theme)),
          if (_selectedConversationIds.isNotEmpty) _buildSendButton(theme),
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
            'اشتراک‌گذاری',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const Spacer(),
          if (_selectedConversationIds.isNotEmpty)
            Text(
              '${_selectedConversationIds.length} انتخاب شده',
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

  Future<void> _loadBannerVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showInfoBanner =
          prefs.getBool('user_selection_info_banner_visible') ?? true;
    });
  }

  Future<void> _hideInfoBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_selection_info_banner_visible', false);
    setState(() {
      _showInfoBanner = false;
    });
  }

  Widget _buildInfoBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'پست را می‌توانید به چت‌های خصوصی و گروه‌ها ارسال کنید. پیام‌هایی که به افراد غیر دنبال‌کننده فرستاده می‌شوند، به صورت درخواست پیام ارسال خواهند شد.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: _hideInfoBanner,
            child: Icon(
              Icons.close,
              color: Colors.grey[400],
              size: 16,
            ),
          ),
        ],
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

    return _buildSocialStyleGrid(theme, filteredConversations);
  }

  Widget _buildSocialStyleGrid(
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
        return _buildSocialStyleUserCard(theme, conversation, index);
      },
    );
  }

  Widget _buildSocialStyleUserCard(
      ThemeData theme, dynamic conversation, int index) {
    final isSelected = _selectedConversationIds.contains(conversation.id);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => _toggleConversationSelection(conversation),
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
                        child: conversation.otherUserAvatar != null &&
                                conversation.otherUserAvatar.isNotEmpty
                            ? AvatarAssetUtils.image(
                                source: conversation.otherUserAvatar,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                fallback:
                                    _buildDefaultAvatar(theme, conversation),
                              )
                            : _buildDefaultAvatar(theme, conversation),
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
                  conversation.otherUserName ?? 'Unknown',
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

  Widget _buildDefaultAvatar(ThemeData theme, dynamic conversation) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Center(
        child: Text(
          conversation.otherUserName?.isNotEmpty == true
              ? conversation.otherUserName![0].toUpperCase()
              : '?',
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
            'در حال بارگذاری مخاطبین...',
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
            'خطا در بارگذاری مخاطبین',
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
            _searchQuery.isEmpty ? 'مخاطبی یافت نشد' : 'نتیجه‌ای یافت نشد',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'برای اشتراک‌گذاری پست‌ها، مکالمات را شروع کنید'
                : 'از واژگان جستجوی دیگری استفاده کنید',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendToSelectedConversations,
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
                      'ارسال به ${_selectedConversationIds.length} مقصد',
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

  void _toggleConversationSelection(dynamic conversation) {
    setState(() {
      if (_selectedConversationIds.contains(conversation.id)) {
        _selectedConversationIds.remove(conversation.id);
      } else {
        _selectedConversationIds.add(conversation.id);
      }
    });
  }

  Future<void> _sendToSelectedConversations() async {
    if (_isLoading || _selectedConversationIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(chatRepositoryProvider);
      int successCount = 0;

      for (final conversationId in _selectedConversationIds) {
        try {
          // ایجاد محتوای پیام برای پست به صورت JSON
          final postContent = _createPostJsonContent(widget.post);

          // ارسال پیام با attachmentType: 'post' برای نمایش به صورت کارت پست
          final payload = MessagePayload(
            conversationId: conversationId,
            content: postContent,
            attachmentType: 'post',
          );

          await repo.sendMessage(payload);

          successCount++;
        } catch (e) {
          // خطا در ارسال به کاربر - ادامه با کاربر بعدی
        }
      }

      if (mounted) {
        // نمایش پیام موفقیت
        _showSuccessMessage(successCount);

        // بستن bottom sheet
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorHandler.logError(e, context: 'post_share');
        _showErrorMessage(UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'post_share'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage(int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('پست به $count مقصد ارسال شد'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('خطا: $error')),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// ایجاد محتوای JSON برای پست (نمایش به صورت کارت پست در چت)
  String _createPostJsonContent(PublicPostModel post) {
    // ساخت لیست URL های مدیا
    final List<String> mediaUrls = [];
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      mediaUrls.add(post.imageUrl!);
    }
    if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
      mediaUrls.add(post.videoUrl!);
    }

    // تعیین نوع تأیید
    String verificationTypeStr = 'none';
    switch (post.verificationType) {
      case VerificationType.blueTick:
        verificationTypeStr = 'blueTick';
        break;
      case VerificationType.goldTick:
        verificationTypeStr = 'goldTick';
        break;
      case VerificationType.blackTick:
        verificationTypeStr = 'blackTick';
        break;
      default:
        verificationTypeStr = 'none';
    }

    final postData = {
      'postId': post.id,
      'authorName': post.fullName.isNotEmpty ? post.fullName : post.username,
      'authorAvatar': post.avatarUrl,
      'authorUsername': post.username,
      'content': post.content,
      'mediaUrls': mediaUrls,
      'likesCount': post.likeCount,
      'commentsCount': post.commentCount,
      'createdAt': post.createdAt.toIso8601String(),
      'verificationType': verificationTypeStr,
      'role': post.profiles?['role'],
      'hashtags': post.hashtags,
    };

    return jsonEncode(postData);
  }
}

/// نمایش bottom sheet انتخاب کاربران
void showUserSelectionBottomSheet(BuildContext context, PublicPostModel post) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => UserSelectionBottomSheet(post: post),
  );
}
