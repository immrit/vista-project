import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/publicPostModel.dart';
import '../../model/ProfileModel.dart';
import '../../provider/chat_provider.dart';
import '../../services/user_friendly_error_handler.dart';

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
  final Set<String> _selectedUsers = {};
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
            'اشتراک‌گذاری',
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
              'اکنون می‌توانید با افراد بیشتری پیام ارسال کنید. پیام‌هایی که به افرادی ارسال می‌شوند که شما را دنبال نمی‌کنند، به صورت درخواست ارسال خواهند شد.',
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
    final conversationsAsync = ref.watch(enrichedConversationsStreamProvider);

    return conversationsAsync.when(
      loading: () => _buildLoadingState(theme),
      error: (error, stack) => _buildErrorState(theme, error.toString()),
      data: (conversations) {
        final filteredConversations = conversations.where((conversation) {
          if (_searchQuery.isEmpty) return true;
          final searchLower = _searchQuery.toLowerCase();
          return conversation.otherUserName
                  ?.toLowerCase()
                  .contains(searchLower) ==
              true;
        }).toList();

        if (filteredConversations.isEmpty) {
          return _buildEmptyState(theme);
        }

        return _buildInstagramStyleGrid(theme, filteredConversations);
      },
    );
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
        return _buildInstagramStyleUserCard(theme, conversation, index);
      },
    );
  }

  Widget _buildInstagramStyleUserCard(
      ThemeData theme, dynamic conversation, int index) {
    final isSelected = _selectedUsers.contains(conversation.otherUserId);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => _toggleUserSelection(conversation),
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
                            ? CachedNetworkImage(
                                imageUrl: conversation.otherUserAvatar,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
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
              onPressed: _isLoading ? null : _sendToSelectedUsers,
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
                      'ارسال به ${_selectedUsers.length} کاربر${_selectedUsers.length > 1 ? '' : ''}',
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

  void _toggleUserSelection(dynamic conversation) {
    setState(() {
      if (_selectedUsers.contains(conversation.otherUserId)) {
        _selectedUsers.remove(conversation.otherUserId);
      } else {
        _selectedUsers.add(conversation.otherUserId);
      }
    });
  }

  Future<void> _sendToSelectedUsers() async {
    if (_isLoading || _selectedUsers.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chatService = ref.read(chatServiceProvider);
      int successCount = 0;

      for (final userId in _selectedUsers) {
        try {
          // ایجاد یا دریافت مکالمه
          final conversationId =
              await chatService.createOrGetConversation(userId);

          // ایجاد محتوای پیام برای پست
          final postContent = _createPostMessageContent(widget.post);

          // ارسال پیام - برای پست‌های ویدیویی، اگر videoUrl خالی هست، از imageUrl (thumbnail) استفاده می‌کنیم
          final attachmentUrl = widget.post.hasVideo
              ? (widget.post.videoUrl ?? widget.post.imageUrl)
              : widget.post.imageUrl;

          // اگر هیچ پیوستی نداریم، اجازه بده فقط متن ارسال شود
          final finalAttachmentUrl =
              (attachmentUrl != null && attachmentUrl.isNotEmpty)
                  ? attachmentUrl
                  : null;
          final attachmentType =
              (widget.post.hasVideo && finalAttachmentUrl != null)
                  ? 'video'
                  : (finalAttachmentUrl != null ? 'image' : null);

          await ref.read(messageNotifierProvider.notifier).sendMessage(
                conversationId: conversationId,
                content: postContent,
                attachmentUrl: finalAttachmentUrl,
                attachmentType: attachmentType,
              );

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
            Text('پست به $count کاربر ارسال شد'),
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

  String _createPostMessageContent(PublicPostModel post) {
    final buffer = StringBuffer();

    // عنوان پست
    buffer.writeln('📝 پست از ${post.username}');

    // آواتار کاربر
    if (post.avatarUrl.isNotEmpty) {
      buffer.writeln('🖼️ آواتار: ${post.avatarUrl}');
    }

    // اطلاعات تایید کاربر
    if (post.verificationType != VerificationType.none) {
      String verificationText = '';
      switch (post.verificationType) {
        case VerificationType.blueTick:
          verificationText = 'blueTick';
          break;
        case VerificationType.goldTick:
          verificationText = 'goldTick';
          break;
        case VerificationType.blackTick:
          verificationText = 'blackTick';
          break;
        default:
          verificationText = 'none';
      }
      buffer.writeln('✅ تایید: $verificationText');
    }

    buffer.writeln();

    // محتوای پست
    buffer.writeln(post.content);
    buffer.writeln();

    // اطلاعات اضافی
    if (post.hasImage) {
      buffer.writeln('🖼️ تصویر ضمیمه شده');
    } else if (post.hasVideo) {
      buffer.writeln('🎥 ویدیو ضمیمه شده');
    }

    if (post.hashtags.isNotEmpty) {
      buffer.writeln('🏷️ ${post.hashtags.join(' ')}');
    }

    buffer.writeln();
    buffer.writeln('🔗 مشاهده در Vista: https://cafevista.ir/post/${post.id}');

    return buffer.toString();
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
