import '../../security/logging_utility.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Vista/provider/comment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/CommentModel.dart';
import 'package:Vista/features/posts/navigation/content_routes.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import '../widgets/comment_input_field.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postTitle;
  final int initialCommentsCount;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postTitle,
    this.initialCommentsCount = 0,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String? _replyingToCommentId;
  String? _replyingToUsername;
  bool _isSubmittingComment = false;

  late AnimationController _sheetAnimationController;
  late Animation<double> _sheetAnimation;

  @override
  void initState() {
    super.initState();

    _sheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sheetAnimation = CurvedAnimation(
      parent: _sheetAnimationController,
      curve: Curves.easeOutCubic,
    );

    _sheetAnimationController.forward();

    // بارگذاری بیشتر کامنت‌ها هنگام رسیدن به انتها
    _scrollController.addListener(_onScroll);
    // اضافه کردن لیسنر برای آپدیت دکمه ارسال
    _commentController.addListener(_onCommentTextChanged);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(commentsProvider(widget.postId).notifier).loadComments();
    }
  }

  // متد برای بازسازی ویجت هنگام تغییر متن کامنت
  void _onCommentTextChanged() {
    if (mounted) {
      // بررسی اینکه ویجت هنوز در درخت ویجت‌ها وجود دارد
      setState(() {
        // این فراخوانی باعث می‌شود ویجت بازسازی شده و وضعیت دکمه ارسال به‌روز شود
      });
    }
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _commentController.removeListener(_onCommentTextChanged); // حذف لیسنر
    _commentController.dispose();
    _sheetAnimationController.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmittingComment) return;

    setState(() {
      _isSubmittingComment = true;
    });

    final previousReplyingTo = _replyingToCommentId;

    // Clear UI immediately (Optimistic UI)
    _commentController.clear();
    _cancelReply();
    FocusScope.of(context).unfocus();

    try {
      final currentUser = ref.read(activeUserProvider);
      final notifier = ref.read(commentsProvider(widget.postId).notifier);
      final success = await notifier.addComment(
        content,
        parentCommentId: previousReplyingTo,
        userId: currentUser?.id,
        username: currentUser?.username,
        avatarUrl: '',
      );

      if (!success) {
        // Restore text if failed
        _commentController.text = content;

        // Get the error message from the provider state
        final error = ref.read(commentsProvider(widget.postId)).error;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    error ?? 'خطا در ارسال کامنت. لطفا دوباره تلاش کنید.')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsState = ref.watch(commentsProvider(widget.postId));
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _sheetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _sheetAnimation.value) * 50),
          child: Opacity(
            opacity: _sheetAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(theme, commentsState),
            Expanded(
              child: _buildCommentsContent(commentsState, theme),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: CommentInputField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                replyingToCommentId: _replyingToCommentId,
                replyingToUsername: _replyingToUsername,
                onCancelReply: _cancelReply,
                onSubmit: _submitComment,
                isSubmitting: _isSubmittingComment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, CommentsState commentsState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظرات',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCommentsContent(CommentsState state, ThemeData theme) {
    if (state.isLoading && state.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(commentsProvider(widget.postId).notifier)
                  .loadComments(refresh: true),
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز نظری ثبت نشده\nاولین نفری باشید که نظر می‌دهد!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(commentsProvider(widget.postId).notifier)
              .loadComments(refresh: true);
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: state.comments.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.comments.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final comment = state.comments[index];
            return CommentItem(
              comment: comment,
              onReply: _startReply,
              postId: widget.postId,
            );
          },
        ));
  }
}

// ویجت نمایش کامنت منفرد
class CommentItem extends ConsumerStatefulWidget {
  final CommentModel comment;
  final Function(String commentId, String username) onReply;
  final String postId;
  final bool isReply;
  final bool hasLineAbove;
  final bool hasLineBelow;

  const CommentItem({
    super.key,
    required this.comment,
    required this.onReply,
    required this.postId,
    this.isReply = false,
    this.hasLineAbove = false,
    this.hasLineBelow = false,
  });

  @override
  ConsumerState<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<CommentItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  int _loadedRepliesCount = 1;

  // Add this controller
  final TextEditingController _editController = TextEditingController();
  bool _isEditing = false;
  final bool _isSavingEdit = false;

  List<CommentModel> _getFlattenedReplies(CommentModel root) {
    final List<CommentModel> flat = [];
    void flatten(CommentModel c) {
      for (var reply in c.replies) {
        flat.add(reply);
        flatten(reply);
      }
    }

    flatten(root);
    return flat;
  }

  void _loadMoreReplies() {
    if (_loadedRepliesCount <= 1) {
      ref
          .read(commentsProvider(widget.postId).notifier)
          .loadReplies(widget.comment.id);
    }
    setState(() {
      if (_loadedRepliesCount == 1) {
        _loadedRepliesCount = 10;
      } else {
        _loadedRepliesCount += 10;
      }
    });
  }

  void _hideReplies() {
    setState(() {
      _loadedRepliesCount = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _editController.dispose();
    super.dispose();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  Widget _buildVerificationBadge(CommentModel comment) {
    return VerificationBadgeIcon(
      isVerified: comment.isVerified,
      verificationType: comment.verificationType,
      role: comment.role,
      size: 16,
    );
  }

  // Add this method to handle edit mode
  void _startEditing() async {
    try {
      // بررسی دسترسی ویرایش بر اساس اطلاعات خود کامنت (که شامل اطلاعات پروفایل نویسنده است)
      final isVerifiedByTick = widget.comment.isVerified;
      final hasSpecialTick =
          widget.comment.verificationType == VerificationType.blackTick ||
              widget.comment.verificationType == VerificationType.goldTick ||
              widget.comment.verificationType == VerificationType.blueTick;

      if (!isVerifiedByTick && !hasSpecialTick) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.verified, color: Colors.amber),
                SizedBox(width: 8),
                Text('ویژه کاربران پریمیوم'),
              ],
            ),
            content:
                Text('برای ویرایش کامنت‌ها نیاز به اکانت تایید شده دارید.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('بعداً'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/premium');
                },
                child: Text('پریمیوم شوید'),
              ),
            ],
          ),
        );
        return;
      }

      setState(() {
        _editController.text = widget.comment.content;
        _isEditing = true;
      });
    } catch (e) {
      logInfo('Error starting edit: $e');
    }
  }

  // Add this method to save edited comment
  Future<void> _saveEdit() async {
    if (_editController.text.trim().isEmpty) return;

    final notifier = ref.read(commentsProvider(widget.postId).notifier);
    final result = await notifier.updateComment(
      widget.comment.id,
      _editController.text.trim(),
      parentCommentId: widget.comment.parentCommentId,
    );

    if (result && mounted) {
      setState(() {
        _isEditing = false;
      });
    } else if (mounted) {
      // Show error message
      final error = ref.read(commentsProvider(widget.postId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(error ?? 'خطا در ویرایش کامنت. لطفا دوباره تلاش کنید.')),
      );
    }
  }

  Widget _buildEditingField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input field container with animation
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _editController,
            maxLines: null,
            autofocus: true,
            cursorColor: theme.colorScheme.primary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textDirection: getDirection(_editController.text),
            decoration: InputDecoration(
              hintText: 'ویرایش نظر خود...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons with fade animation
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isEditing ? 1.0 : 0.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _editController.text = widget.comment.content;
                    _isEditing = false;
                  });
                },
                icon: const Icon(Icons.close),
                label: const Text('انصراف'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saveEdit,
                icon: const Icon(Icons.check),
                label: const Text('ثبت تغییرات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(activeUserProvider)?.id;
    final isOwner = currentUserId == widget.comment.userId;
    final commentsState = ref.watch(commentsProvider(widget.postId));

    final currentComment = commentsState.comments.firstWhere(
      (c) => c.id == widget.comment.id,
      orElse: () => widget.comment,
    );
    final flatReplies = widget.isReply
        ? <CommentModel>[]
        : _getFlattenedReplies(currentComment);
    final shownReplies = flatReplies.take(_loadedRepliesCount).toList();
    final bool showThreadLineBelowRoot = shownReplies.isNotEmpty;
    final isLoading = commentsState.loadingReplies[widget.comment.id] ?? false;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (widget.hasLineAbove)
                Positioned(
                  top: 0,
                  bottom: null,
                  right: 35,
                  child: Container(
                    width: 2,
                    height: 12, // padding top
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              if (widget.hasLineBelow || showThreadLineBelowRoot)
                Positioned(
                  top: 52, // 12 padding top + 40 avatar size
                  bottom: 0,
                  right: 35,
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              Container(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 12, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // آواتار
                    Padding(
                      padding: EdgeInsets.only(
                          right: widget.isReply ? 4 : 0,
                          left: widget.isReply ? 4 : 0),
                      child: GestureDetector(
                        onTap: () {
                          ContentNavigation.pushProfile(
                            context,
                            userId: widget.comment.userId,
                            username: widget.comment.username,
                          );
                        },
                        child: CircleAvatar(
                          radius: widget.isReply ? 16 : 20,
                          backgroundImage: widget.comment.avatarUrl.isEmpty
                              ? const AssetImage(
                                  'lib/utils/images/default-avatar.jpg')
                              : CachedNetworkImageProvider(
                                  widget.comment.avatarUrl) as ImageProvider,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // محتوای کامنت
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // هدر
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    ContentNavigation.pushProfile(
                                      context,
                                      userId: widget.comment.userId,
                                      username: widget.comment.username,
                                    );
                                  },
                                  child: Text(
                                    widget.comment.username,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildVerificationBadge(widget.comment),
                              if (isOwner) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.7),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // متن کامنت
                          if (_isEditing)
                            _buildEditingField(theme)
                          else
                            Directionality(
                              textDirection:
                                  getDirection(widget.comment.content),
                              child: Text(
                                widget.comment.content,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // دکمه‌های عملکرد
                          Row(
                            children: [
                              Text(
                                _getTimeAgo(widget.comment.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // پاسخ
                              InkWell(
                                onTap: () => widget.onReply(
                                  widget.comment.id,
                                  widget.comment.username,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Text(
                                  'پاسخ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 16),
                                InkWell(
                                  onTap: _startEditing,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Text(
                                    'ویرایش',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],

                              const Spacer(),

                              // منوی بیشتر
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'edit':
                                      _startEditing();
                                      break;
                                    case 'delete':
                                      final notifier = ref.read(
                                          commentsProvider(widget.postId)
                                              .notifier);
                                      final success =
                                          await notifier.deleteComment(
                                        widget.comment.id,
                                        parentCommentId:
                                            widget.comment.parentCommentId,
                                      );
                                      if (!success && mounted) {
                                        final error = ref
                                            .read(
                                                commentsProvider(widget.postId))
                                            .error;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(error ??
                                                  'خطا در حذف کامنت. لطفا دوباره تلاش کنید.')),
                                        );
                                      }
                                      break;
                                  }
                                },
                                itemBuilder: (context) {
                                  final canEdit = widget.comment.isVerified ||
                                      [
                                        VerificationType.blackTick,
                                        VerificationType.goldTick,
                                        VerificationType.blueTick
                                      ].contains(
                                          widget.comment.verificationType);
                                  return [
                                    if (isOwner) ...[
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                size: 18,
                                                color: canEdit
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme.onSurface
                                                        .withValues(
                                                            alpha: 0.3)),
                                            const SizedBox(width: 8),
                                            Text('ویرایش',
                                                style: TextStyle(
                                                    color: canEdit
                                                        ? null
                                                        : theme.colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.3))),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('حذف',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      const PopupMenuItem(
                                        value: 'report',
                                        child: Row(
                                          children: [
                                            Icon(Icons.report, size: 18),
                                            SizedBox(width: 8),
                                            Text('گزارش'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ];
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!widget.isReply) ...[
            if (shownReplies.isNotEmpty) ...[
              ...shownReplies.asMap().entries.map((entry) {
                final index = entry.key;
                final reply = entry.value;
                final isLast = index == shownReplies.length - 1;
                return CommentItem(
                  comment: reply,
                  onReply: widget.onReply,
                  postId: widget.postId,
                  isReply: true,
                  hasLineAbove: true,
                  hasLineBelow: !isLast && !isLoading,
                );
              }),
            ],

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (shownReplies.isEmpty && _loadedRepliesCount > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'هنوز پاسخی وجود ندارد',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // دکمه مشاهده پاسخ‌های بیشتر
            if (currentComment.replies.isNotEmpty || flatReplies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 64, top: 4, bottom: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      if (_loadedRepliesCount == 0 ||
                          _loadedRepliesCount < flatReplies.length) {
                        _loadMoreReplies();
                      } else {
                        _hideReplies();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 1,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _loadedRepliesCount == 0
                                ? 'مشاهده ${flatReplies.isNotEmpty ? flatReplies.length : currentComment.replies.length} پاسخ'
                                : _loadedRepliesCount < flatReplies.length
                                    ? 'مشاهده ${flatReplies.length - _loadedRepliesCount} پاسخ دیگر'
                                    : 'پنهان کردن پاسخ‌ها',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// تابع برای نمایش باتم شیت
void showCommentsBottomSheet2(
  BuildContext context, {
  required String postId,
  required String postTitle,
  int initialCommentsCount = 0,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CommentsBottomSheet(
      postId: postId,
      postTitle: postTitle,
      initialCommentsCount: initialCommentsCount,
    ),
  );
}

// تابع کمکی برای تشخیص راست‌چین یا چپ‌چین بودن متن
TextDirection getDirection(String text) {
  // اگر متن شامل کاراکترهای فارسی/عربی باشد، راست‌چین است
  final rtlRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
  return rtlRegex.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
}
