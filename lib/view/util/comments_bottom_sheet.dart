import 'package:Vista/provider/comment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../model/CommentModel.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postTitle;
  final int initialCommentsCount;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.postTitle,
    this.initialCommentsCount = 0,
  }) : super(key: key);

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
    if (content.isEmpty) return;

    final notifier = ref.read(commentsProvider(widget.postId).notifier);
    final success = await notifier.addComment(content,
        parentCommentId: _replyingToCommentId);

    if (success) {
      _commentController.clear();
      _cancelReply();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال کامنت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsState = ref.watch(commentsProvider(widget.postId));

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
            // هندل و هدر
            _buildHeader(theme),

            // محتوای کامنت‌ها
            Expanded(
              child: _buildCommentsContent(commentsState, theme),
            ),

            // باکس ارسال کامنت
            _buildCommentInputBox(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // هندل
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // عنوان
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظرات (${widget.initialCommentsCount})',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Consumer(
                    //   builder: (context, ref, child) {
                    //     final commentsCount =
                    //         ref.watch(commentsCountProvider(widget.postId));
                    //     return commentsCount.when(
                    //       data: (count) => Text(
                    //         '$count کامنت',
                    //         style: theme.textTheme.bodyMedium?.copyWith(
                    //           color:
                    //               theme.colorScheme.onSurface.withOpacity(0.6),
                    //         ),
                    //       ),
                    //       loading: () => Text(
                    //         '${widget.initialCommentsCount} کامنت',
                    //         style: theme.textTheme.bodyMedium?.copyWith(
                    //           color:
                    //               theme.colorScheme.onSurface.withOpacity(0.6),
                    //         ),
                    //       ),
                    //       error: (_, __) => const SizedBox.shrink(),
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref
                      .read(commentsProvider(widget.postId).notifier)
                      .loadComments(refresh: true);
                },
                icon: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsContent(CommentsState state, ThemeData theme) {
    if (state.isLoading && state.comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(commentsProvider(widget.postId).notifier)
                    .loadComments(refresh: true);
              },
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
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز کامنتی ثبت نشده',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اولین نفری باشید که کامنت می‌گذارد!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
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
          padding: const EdgeInsets.only(top: 8),
          itemCount: state.comments.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.comments.length) {
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

  Widget _buildCommentInputBox(ThemeData theme) {
    final commentsState = ref.watch(commentsProvider(widget.postId));

    // دریافت اطلاعات کاربر جاری
    final currentUser = Supabase.instance.client.auth.currentUser;
    final avatarUrl = currentUser?.userMetadata?['avatar_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // نمایش در حال ریپلای
          if (_replyingToCommentId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'در حال پاسخ به @$_replyingToUsername',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelReply,
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // باکس ورودی
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // آواتار کاربر فعلی
                avatarUrl != null && avatarUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(avatarUrl),
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.1),
                      )
                    : CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                const SizedBox(width: 12),

                // فیلد متنی
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: _replyingToCommentId != null
                            ? 'پاسخ خود را بنویسید...'
                            : 'کامنت خود را بنویسید...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // دکمه ارسال
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: commentsState.isAddingComment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: _commentController.text.trim().isEmpty
                              ? null
                              : _submitComment, // Ensure this calls `_submitComment`
                          icon: Icon(
                            Icons.send,
                            color: _commentController.text.trim().isEmpty
                                ? theme.colorScheme.onSurface.withOpacity(0.3)
                                : theme.colorScheme.primary,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // فضای امن پایین
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ویجت نمایش کامنت منفرد
class CommentItem extends ConsumerStatefulWidget {
  final CommentModel comment;
  final Function(String commentId, String username) onReply;
  final String postId;
  final bool isReply;

  const CommentItem({
    Key? key,
    required this.comment,
    required this.onReply,
    required this.postId,
    this.isReply = false,
  }) : super(key: key);

  @override
  ConsumerState<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<CommentItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _showReplies = false;

  // Add this controller
  final TextEditingController _editController = TextEditingController();
  bool _isEditing = false;

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

  void _toggleReplies() {
    setState(() {
      _showReplies = !_showReplies;
    });

    if (_showReplies) {
      // هر بار که کاربر روی نمایش ریپلای‌ها کلیک می‌کند، آنها را بارگذاری کنید
      ref
          .read(commentsProvider(widget.postId).notifier)
          .loadReplies(widget.comment.id);
    }
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

  Widget _buildVerificationBadge(VerificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case VerificationType.goldTick:
        icon = Icons.verified;
        color = Colors.amber;
        break;
      case VerificationType.blueTick: // Added case for blueTick
        icon = Icons.verified;
        color = Colors.blue;
        break;
      case VerificationType.blackTick:
        icon = Icons.verified;
        color = Colors.black87;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(
      icon,
      size: 16,
      color: color,
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
                  Navigator.pushNamed(context, '/verification-store');
                },
                child: Text('خرید اشتراک'),
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
      print('Error starting edit: $e');
    }
  }

  // Add this method to save edited comment
  Future<void> _saveEdit() async {
    if (_editController.text.trim().isEmpty) return;

    final result = await ref
        .read(commentsProvider(widget.postId).notifier)
        .updateComment(widget.comment.id, _editController.text);

    if (result && mounted) {
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == widget.comment.userId;

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
      child: Container(
        margin: EdgeInsets.only(
          // right: widget.isReply ? 48 : 0, // حذف مارجین راست برای جلوگیری از کاهش عرض پاسخ‌ها
          bottom: 8,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // آواتار
                  CircleAvatar(
                    radius: widget.isReply ? 16 : 20,
                    backgroundImage: widget.comment.avatarUrl != null
                        ? NetworkImage(widget.comment.avatarUrl!)
                        : null,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: widget.comment.avatarUrl == null
                        ? Icon(
                            Icons.person,
                            size: widget.isReply ? 16 : 20,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // محتوای کامنت
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // هدر (نام کاربری و زمان)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${widget.comment.username}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildVerificationBadge(
                                widget.comment.verificationType),
                            const SizedBox(width: 8),
                            Text(
                              _getTimeAgo(widget.comment.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // متن کامنت
                        if (_isEditing)
                          Column(
                            children: [
                              TextField(
                                controller: _editController,
                                maxLines: null,
                                autofocus: true,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = false;
                                      });
                                    },
                                    child: Text('لغو'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _saveEdit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    ),
                                    child: Text('ثبت تغییرات'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Text(
                            widget.comment.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 8),

                        // دکمه‌های عملکرد
                        Row(
                          children: [
                            // دکمه پاسخ (حالا برای همه کامنت‌ها نمایش داده می‌شود)
                            InkWell(
                              onTap: () => widget.onReply(
                                widget.comment.id,
                                widget.comment.username,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'پاسخ',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // دکمه نمایش/پنهان کردن پاسخ‌ها (برای هر کامنتی که پاسخ دارد)
                            if (widget.comment.replies.isNotEmpty)
                              InkWell(
                                onTap: _toggleReplies,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showReplies
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.comment.replies.length} پاسخ',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const Spacer(),

                            // منوی بیشتر
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'edit':
                                    _startEditing();
                                    break;
                                  case 'delete':
                                    ref
                                        .read(commentsProvider(widget.postId)
                                            .notifier)
                                        .deleteComment(widget.comment.id);
                                    break;

                                  case 'report':
                                    // TODO: پیاده‌سازی گزارش
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                // بررسی مستقیم از متادیتای کاربر برای دسترسی به ویرایش
                                // استفاده از اطلاعات خود کامنت
                                final isVerifiedByTick =
                                    widget.comment.isVerified;
                                final hasSpecialTick =
                                    widget.comment.verificationType ==
                                            VerificationType.blackTick ||
                                        widget.comment.verificationType ==
                                            VerificationType.goldTick ||
                                        widget.comment.verificationType ==
                                            VerificationType.blueTick;
                                final canEdit =
                                    isVerifiedByTick || hasSpecialTick;

                                return [
                                  if (isOwner) ...[
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: canEdit
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withOpacity(0.3),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'ویرایش',
                                            style: TextStyle(
                                              color: canEdit
                                                  ? null
                                                  : theme.colorScheme.onSurface
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                          if (!canEdit) ...[
                                            // نمایش آیکون وریفای اگر کاربر اجازه ویرایش ندارد
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.verified,
                                              size: 14,
                                              color:
                                                  Colors.amber.withOpacity(0.5),
                                            ),
                                          ],
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
                                              style:
                                                  TextStyle(color: Colors.red)),
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

            // نمایش پاسخ‌ها
            if (_showReplies) // نمایش پاسخ‌ها برای هر کامنتی که قابلیت باز شدن دارد
              Consumer(
                builder: (context, ref, child) {
                  final commentsState =
                      ref.watch(commentsProvider(widget.postId));
                  final isLoading =
                      commentsState.loadingReplies[widget.comment.id] ?? false;

                  // پیدا کردن کامنت فعلی با ریپلای‌های به‌روز
                  final currentComment = commentsState.comments.firstWhere(
                    (c) => c.id == widget.comment.id,
                    orElse: () => widget.comment,
                  );

                  if (isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  if (currentComment.replies.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'هنوز پاسخی وجود ندارد',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    children: currentComment.replies
                        .map((reply) => CommentItem(
                              comment: reply,
                              onReply: widget.onReply,
                              postId: widget.postId,
                              isReply: true,
                            ))
                        .toList(),
                  );
                },
              ),
          ],
        ),
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
