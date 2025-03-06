// import 'package:Vista/main.dart';
// import 'package:Vista/model/UserModel.dart';
// import 'package:Vista/provider/provider.dart';
// import 'package:Vista/util/widgets.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:shamsi_date/shamsi_date.dart';

// import '../model/CommentModel.dart';

// class CommentsBottomSheet extends ConsumerStatefulWidget {
//   final String postId;

//   const CommentsBottomSheet({
//     required this.postId,
//     super.key,
//   });

//   @override
//   ConsumerState<CommentsBottomSheet> createState() =>
//       _CommentsBottomSheetState();
// }

// class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet>
//     with TickerProviderStateMixin {
//   // کنترلرهای اصلی
//   final TextEditingController commentController = TextEditingController();
//   final FocusNode commentFocusNode = FocusNode();
//   ScrollController scrollController = ScrollController();

//   // متغیرهای حالت
//   String? replyToCommentId;
//   String? replyToUsername;
//   String? editingCommentId;
//   List<UserModel> mentionedUsers = [];

//   // استفاده از id کاربر فعلی
//   final String currentUserId = supabase.auth.currentUser!.id;
//   final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

//   // کنترلر انیمیشن
//   late AnimationController _loadingAnimationController;

//   @override
//   void initState() {
//     super.initState();
//     _loadingAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     )..repeat();

//     // فوکوس کردن روی فیلد نظر بعد از لود
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       commentFocusNode.requestFocus();
//     });
//   }

//   @override
//   void dispose() {
//     commentController.dispose();
//     commentFocusNode.dispose();
//     scrollController.dispose();
//     _loadingAnimationController.dispose();
//     super.dispose();
//   }

//   // عملکرد برای اسکرول به پایین لیست
//   void _scrollToBottom() {
//     if (scrollController.hasClients) {
//       scrollController.animateTo(
//         scrollController.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   Widget _buildInteractionButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     String size = 'normal',
//     Color? color,
//   }) {
//     final theme = Theme.of(context);
//     final double iconSize = size == 'small' ? 16 : 20;
//     final double fontSize = size == 'small' ? 12 : 14;
//     final buttonColor = color ?? theme.colorScheme.primary;

//     return TextButton.icon(
//       onPressed: onTap,
//       style: TextButton.styleFrom(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//       ),
//       icon: Icon(icon, size: iconSize, color: buttonColor),
//       label: Text(
//         label,
//         style: TextStyle(fontSize: fontSize, color: buttonColor),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return GestureDetector(
//       onTap: () => FocusScope.of(context).unfocus(),
//       child: DraggableScrollableSheet(
//         initialChildSize: 0.9,
//         minChildSize: 0.5,
//         maxChildSize: 0.95,
//         builder: (context, scrollController) {
//           this.scrollController = scrollController;
//           return Container(
//             decoration: BoxDecoration(
//               color: theme.scaffoldBackgroundColor,
//               borderRadius:
//                   const BorderRadius.vertical(top: Radius.circular(20)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 10,
//                   spreadRadius: 0,
//                 )
//               ],
//             ),
//             child: Column(
//               children: [
//                 // Handle bar
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   child: Container(
//                     width: 40,
//                     height: 5,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[400],
//                       borderRadius: BorderRadius.circular(2.5),
//                     ),
//                   ),
//                 ),

//                 // Header with title and stats
//                 _buildCommentsHeader(),

//                 // Comments content
//                 Expanded(
//                   child: RefreshIndicator(
//                     onRefresh: () async {
//                       ref.invalidate(commentsProvider(widget.postId));
//                     },
//                     child: ListView(
//                       controller: scrollController,
//                       physics: const AlwaysScrollableScrollPhysics(),
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       children: [
//                         _buildCommentsSection(),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Bottom input area
//                 SafeArea(
//                   child: _buildCommentInputArea(
//                     context,
//                     ref.watch(mentionNotifierProvider),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // ساخت هدر با آمار نظرات
//   Widget _buildCommentsHeader() {
//     final commentsAsyncValue = ref.watch(commentsProvider(widget.postId));
//     final theme = Theme.of(context);

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: theme.scaffoldBackgroundColor,
//         border: Border(
//           bottom: BorderSide(
//             color: theme.dividerColor.withOpacity(0.3),
//             width: 1,
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.chat_bubble_outline),
//           const SizedBox(width: 8),
//           const Directionality(
//             textDirection: TextDirection.rtl,
//             child: Text(
//               'نظرات',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ),
//           const Spacer(),
//           commentsAsyncValue.whenOrNull(
//                 data: (comments) => Text(
//                   '${comments.length} نظر',
//                   style: TextStyle(
//                     color: theme.colorScheme.primary,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ) ??
//               const SizedBox.shrink(),
//         ],
//       ),
//     );
//   }

//   Widget _buildCommentsSection() {
//     final commentsAsyncValue = ref.watch(commentsProvider(widget.postId));
//     final theme = Theme.of(context);

//     return commentsAsyncValue.when(
//       data: (comments) => comments.isEmpty
//           ? _buildEmptyCommentsView()
//           : _buildCommentTree(comments),
//       loading: () => Center(
//         child: Padding(
//           padding: const EdgeInsets.all(32.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               RotationTransition(
//                 turns: Tween(begin: 0.0, end: 1.0)
//                     .animate(_loadingAnimationController),
//                 child: Icon(
//                   Icons.chat_bubble_outline,
//                   size: 40,
//                   color: theme.colorScheme.primary.withOpacity(0.5),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'در حال بارگذاری نظرات...',
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             ],
//           ),
//         ),
//       ),
//       error: (error, stack) => Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
//               const SizedBox(height: 8),
//               Text(
//                 'خطا در بارگذاری نظرات',
//                 style: theme.textTheme.titleMedium?.copyWith(
//                   color: Colors.red[400],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed: () =>
//                     ref.invalidate(commentsProvider(widget.postId)),
//                 icon: const Icon(Icons.refresh),
//                 label: const Text('تلاش مجدد'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: theme.colorScheme.primaryContainer,
//                   foregroundColor: theme.colorScheme.onPrimaryContainer,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyCommentsView() {
//     final theme = Theme.of(context);

//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 40.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               Icons.chat_bubble_outline,
//               size: 60,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'هنوز نظری ثبت نشده است.',
//               style: theme.textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'اولین نفری باشید که نظر می‌دهید!',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: () => commentFocusNode.requestFocus(),
//               icon: const Icon(Icons.add_comment),
//               label: const Text('نوشتن نظر'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: theme.colorScheme.primary,
//                 foregroundColor: theme.colorScheme.onPrimary,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 12,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCommentTree(List<CommentModel> comments) {
//     // جدا کردن کامنت‌های اصلی و پاسخ‌ها
//     final rootComments =
//         comments.where((c) => c.parentCommentId == null).toList();

//     // مرتب‌سازی کامنت‌های اصلی بر اساس زمان ایجاد (جدیدترین اول)
//     rootComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

//     return ListView.separated(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: rootComments.length,
//       separatorBuilder: (context, index) =>
//           const Divider(height: 1, thickness: 0.5),
//       itemBuilder: (context, index) {
//         final rootComment = rootComments[index];

//         // پیدا کردن تمام پاسخ‌های مربوط به این کامنت
//         final replies = comments
//             .where((c) => c.parentCommentId == rootComment.id)
//             .toList()
//           ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildCommentItem(rootComment),
//             if (replies.isNotEmpty) _buildRepliesSection(replies, comments),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildRepliesSection(
//       List<CommentModel> directReplies, List<CommentModel> allComments) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 28.0),
//       child: Container(
//         margin: const EdgeInsets.only(right: 8),
//         padding: const EdgeInsets.only(right: 8),
//         decoration: BoxDecoration(
//           border: Border(
//             right: BorderSide(
//               color: Colors.grey.withOpacity(0.3),
//               width: 2,
//             ),
//           ),
//         ),
//         child: ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: directReplies.length,
//           itemBuilder: (context, index) {
//             return _buildCommentItem(directReplies[index], isReply: true);
//           },
//         ),
//       ),
//     );
//   }

//   List<TextSpan> _buildCommentTextSpans(CommentModel comment, bool isDarkMode) {
//     // Add your logic to build text spans here
//     return [
//       TextSpan(
//         text: comment.content,
//         style: TextStyle(
//           color: isDarkMode ? Colors.white : Colors.black,
//         ),
//       ),
//     ];
//   }

//   Widget _buildCommentItem(CommentModel comment, {bool isReply = false}) {
//     final theme = Theme.of(context);
//     final bool isEditing = editingCommentId == comment.id;
//     final bool isOwnComment = comment.userId == currentUserId;
//     String persianMonth(int month) {
//       const months = [
//         'فروردین',
//         'اردیبهشت',
//         'خرداد',
//         'تیر',
//         'مرداد',
//         'شهریور',
//         'مهر',
//         'آبان',
//         'آذر',
//         'دی',
//         'بهمن',
//         'اسفند'
//       ];
//       return months[month - 1];
//     }

//     String formatDateTimeToJalali(DateTime dateTime) {
//       final gregorian = Gregorian.fromDateTime(dateTime);
//       final jalali = gregorian.toJalali();

//       // Get current time
//       final now = DateTime.now();
//       final difference = now.difference(dateTime);

//       // If less than 24 hours
//       if (difference.inHours < 24) {
//         if (difference.inMinutes < 1) {
//           return 'همین الان';
//         } else if (difference.inHours < 1) {
//           return '${difference.inMinutes} دقیقه پیش';
//         } else {
//           return '${difference.inHours} ساعت پیش';
//         }
//       }
//       // If less than 7 days
//       else if (difference.inDays < 7) {
//         return '${difference.inDays} روز پیش';
//       }
//       // If in current year
//       else {
//         String month = persianMonth(jalali.month);
//         String hour = dateTime.hour.toString().padLeft(2, '0');
//         String minute = dateTime.minute.toString().padLeft(2, '0');

//         return '${jalali.day} $month${now.year != dateTime.year ? ' ${jalali.year}' : ''} • $hour:$minute';
//       }
//     }

//     return Container(
//       margin:
//           EdgeInsets.symmetric(vertical: 8.0, horizontal: isReply ? 0 : 8.0),
//       decoration: BoxDecoration(
//         color: isOwnComment
//             ? theme.colorScheme.primaryContainer.withOpacity(0.15)
//             : null,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Avatar with verification badge
//           Stack(
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   // اینجا می‌توانید به پروفایل کاربر هدایت کنید
//                 },
//                 child: Hero(
//                   tag: 'avatar-${comment.userId}',
//                   child: CircleAvatar(
//                     radius: isReply ? 16 : 20,
//                     backgroundImage: comment.avatarUrl.isEmpty
//                         ? const AssetImage('lib/util/images/default-avatar.jpg')
//                         : CachedNetworkImageProvider(comment.avatarUrl)
//                             as ImageProvider,
//                   ),
//                 ),
//               ),
//               if (comment.isVerified)
//                 Positioned(
//                   right: 0,
//                   bottom: 0,
//                   child: Container(
//                     padding: const EdgeInsets.all(2),
//                     decoration: BoxDecoration(
//                       color: theme.scaffoldBackgroundColor,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.verified,
//                       color: Colors.blue,
//                       size: isReply ? 12 : 14,
//                     ),
//                   ),
//                 ),
//             ],
//           ),

//           const SizedBox(width: 8),

//           // Comment content
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Header with username and actions
//                 Row(
//                   children: [
//                     GestureDetector(
//                       onTap: () {
//                         // اینجا می‌توانید به پروفایل کاربر هدایت کنید
//                       },
//                       child: Text(
//                         comment.username,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: isReply ? 14 : 15,
//                           color: theme.colorScheme.primary,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       ' · ${formatDateTimeToJalali(comment.createdAt)}',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: isReply ? 12 : 14,
//                       ),
//                     ),
//                     if (isOwnComment)
//                       Padding(
//                         padding: const EdgeInsets.only(right: 4),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: theme.colorScheme.primary.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text(
//                             'شما',
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: theme.colorScheme.primary,
//                             ),
//                           ),
//                         ),
//                       ),
//                     const Spacer(),
//                     _buildCommentActions(comment),
//                   ],
//                 ),

//                 // Comment text or editing field
//                 if (isEditing)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8.0),
//                     child: TextField(
//                       controller: commentController,
//                       decoration: InputDecoration(
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         contentPadding: const EdgeInsets.all(12),
//                       ),
//                       maxLines: 3,
//                       autofocus: true,
//                     ),
//                   )
//                 else
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4.0),
//                     child: Directionality(
//                       textDirection: getDirectionality(comment.content),
//                       child: RichText(
//                         text: TextSpan(
//                           children: _buildCommentTextSpans(
//                               comment, theme.brightness == Brightness.dark),
//                           style: TextStyle(
//                             fontSize: isReply ? 14 : 15,
//                             height: 1.4,
//                             color: theme.textTheme.bodyLarge?.color,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),

//                 // Interaction buttons
//                 if (!isEditing)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 4.0),
//                     child: Row(
//                       children: [
//                         _buildInteractionButton(
//                           icon: Icons.favorite_border,
//                           label: '۲۵',
//                           onTap: () {
//                             // عملیات لایک
//                           },
//                           size: isReply ? 'small' : 'normal',
//                         ),
//                         _buildInteractionButton(
//                           icon: Icons.reply_outlined,
//                           label: 'پاسخ',
//                           onTap: () {
//                             setState(() {
//                               replyToCommentId = comment.id;
//                               replyToUsername = comment.username;
//                               commentController.text = '@${comment.username} ';
//                               commentController.selection =
//                                   TextSelection.fromPosition(
//                                 TextPosition(
//                                     offset: commentController.text.length),
//                               );
//                               commentFocusNode.requestFocus();
//                             });
//                           },
//                           size: isReply ? 'small' : 'normal',
//                         ),
//                         if (isOwnComment)
//                           _buildInteractionButton(
//                             icon: Icons.edit_outlined,
//                             label: 'ویرایش',
//                             onTap: () {
//                               setState(() {
//                                 editingCommentId = comment.id;
//                                 commentController.text = comment.content;
//                                 commentController.selection =
//                                     TextSelection.fromPosition(
//                                   TextPosition(
//                                       offset: commentController.text.length),
//                                 );
//                               });
//                             },
//                             size: isReply ? 'small' : 'normal',
//                             color: Colors.orange,
//                           ),
//                       ],
//                     ),
//                   )
//                 else
//                   // Save/Cancel buttons for editing
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       TextButton.icon(
//                         onPressed: () {
//                           setState(() {
//                             editingCommentId = null;
//                             commentController.clear();
//                           });
//                         },
//                         icon: const Icon(Icons.close),
//                         label: const Text('انصراف'),
//                         style: TextButton.styleFrom(
//                           foregroundColor: Colors.red,
//                         ),
//                       ),
//                       ElevatedButton.icon(
//                         onPressed: () => _updateComment(comment.id),
//                         icon: const Icon(Icons.check),
//                         label: const Text('ذخیره'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: theme.colorScheme.primary,
//                           foregroundColor: theme.colorScheme.onPrimary,
//                         ),
//                       ),
//                     ],
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ویرایش کامنت
//   void _updateComment(String commentId) async {
//     final content = commentController.text.trim();
//     if (content.isEmpty) return;

//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('در حال ذخیره تغییرات...')),
//       );

//       // اینجا عملیات ویرایش کامنت را اضافه کنید
//       // await ref.read(commentNotifierProvider.notifier).updateComment(
//       //       commentId: commentId,
//       //       content: content,
//       //     );

//       commentController.clear();
//       setState(() {
//         editingCommentId = null;
//       });

//       // به‌روزرسانی لیست نظرات
//       ref.invalidate(commentsProvider(widget.postId));

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('نظر با موفقیت ویرایش شد'),
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error updating comment: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//   Future<void> _deleteComment(BuildContext context, WidgetRef ref,
//       String commentId, String postId) async {
//     try {
//       // Add your logic to delete the comment here
//       // Example:
//       // await ref.read(commentNotifierProvider.notifier).deleteComment(commentId);

//       // Refresh comments list
//       ref.invalidate(commentsProvider(postId));
//     } catch (e) {
//       print('Error deleting comment: $e');
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.error_outline, color: Colors.white),
//                 const SizedBox(width: 12),
//                 Expanded(child: Text('خطا در حذف نظر: $e')),
//               ],
//             ),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//         String formatDateTimeToJalali(DateTime dateTime) {
//           // Add your logic to format the DateTime to Jalali here
//           // Example:
//           // final f = Jalali.fromDateTime(dateTime).formatFullDate();
//           // return f;
//           return dateTime.toString(); // Placeholder implementation
//         }
//       }
//     }
//   }

//   void _updateComment(String commentId) async {
//           SnackBar(
//             content: Text('خطا در ویرایش نظر: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   void _sendComment() async {
//     final content = commentController.text.trim();
//     final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

//     if (content.isNotEmpty) {
//       try {
//         // Show loading with a nicer SnackBar
//         final snackBar = SnackBar(
//           content: Row(
//             children: [
//               SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation<Color>(
//                     Theme.of(context).colorScheme.onSurface,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               const Text('در حال ارسال نظر...'),
//             ],
//           ),
//           duration: const Duration(seconds: 60),
//         );
//         ScaffoldMessenger.of(context).showSnackBar(snackBar);

//         print('Sending comment with:');
//         print('Content: $content');
//         print('PostID: ${widget.postId}');
//         print('ParentCommentID: $replyToCommentId');
//         print('MentionedUsers: $mentionedUserIds');

//         final result =
//             await ref.read(commentNotifierProvider.notifier).addComment(
//                   postId: widget.postId,
//                   content: content,
//                   postOwnerId: supabase.auth.currentUser!.id,
//                   mentionedUserIds: mentionedUserIds,
//                   parentCommentId: replyToCommentId,
//                   ref: ref,
//                 );

//         // Clear input and states
//         commentController.clear();
//         setState(() {
//           replyToCommentId = null;
//           replyToUsername = null;
//           mentionedUsers.clear();
//         });

//         // Refresh comments list
//         ref.invalidate(commentsProvider(widget.postId));

//         // اسکرول به پایین لیست با تاخیر
//         Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);

//         // Show success message
//         if (mounted) {
//           ScaffoldMessenger.of(context).clearSnackBars();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Row(
//                 children: [
//                   Icon(Icons.check_circle, color: Colors.green[300]),
//                   const SizedBox(width: 16),
//                   const Text('نظر با موفقیت ثبت شد'),
//                 ],
//               ),
//               duration: const Duration(seconds: 2),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           );
//         }
//       } catch (e) {
//         print('Error sending comment: $e');
//         // Show error
//         if (mounted) {
//           ScaffoldMessenger.of(context).clearSnackBars();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Row(
//                 children: [
//                   const Icon(Icons.error, color: Colors.white),
//                   const SizedBox(width: 16),
//                   Expanded(child: Text('خطا در ارسال نظر: $e')),
//                 ],
//               ),
//               backgroundColor: Colors.red,
//               duration: const Duration(seconds: 4),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           );
//         }
//       }
//     }
//   }

//   Widget _buildCommentActions(CommentModel comment) {
//     final bool isOwnComment = comment.userId == currentUserId;
//     final theme = Theme.of(context);

//     return PopupMenuButton<String>(
//       icon: const Icon(Icons.more_vert, size: 18),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       itemBuilder: (context) {
//         return [
//           if (isOwnComment) ...[
//             PopupMenuItem(
//               value: 'edit',
//               child: Row(
//                 children: [
//                   Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
//                   const SizedBox(width: 12),
//                   Text('ویرایش',
//                       style: TextStyle(color: theme.colorScheme.primary)),
//                 ],
//               ),
//             ),
//             const PopupMenuItem(
//               value: 'delete',
//               child: Row(
//                 children: [
//                   Icon(Icons.delete_outline, color: Colors.red),
//                   SizedBox(width: 12),
//                   Text('حذف', style: TextStyle(color: Colors.red)),
//                 ],
//               ),
//             ),
//           ],
//           PopupMenuItem(
//             value: 'copy',
//             child: Row(
//               children: [
//                 Icon(Icons.copy, color: theme.iconTheme.color),
//                 const SizedBox(width: 12),
//                 const Text('کپی متن'),
//               ],
//             ),
//           ),
//           const PopupMenuItem(
//             value: 'report',
//             child: Row(
//               children: [
//                 Icon(Icons.flag_outlined),
//                 SizedBox(width: 12),
//                 Text('گزارش'),
//               ],
//             ),
//           ),
//         ];
//       },
//       onSelected: (value) async {
//         switch (value) {
//           case 'edit':
//             setState(() {
//               editingCommentId = comment.id;
//               commentController.text = comment.content;
//               commentController.selection = TextSelection.fromPosition(
//                 TextPosition(offset: commentController.text.length),
//               );
//             });
//             break;
//           case 'delete':
//             final confirm = await showDialog<bool>(
//               context: context,
//               builder: (context) => AlertDialog(
//                 title: const Text('حذف نظر'),
//                 content: const Text('آیا از حذف این نظر مطمئن هستید؟'),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context, false),
//                     child: const Text('انصراف'),
//                   ),
//                   TextButton(
//                     onPressed: () => Navigator.pop(context, true),
//                     child:
//                         const Text('حذف', style: TextStyle(color: Colors.red)),
//                   ),
//                 ],
//               ),
//             );
//             if (confirm == true) {
//               try {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Row(
//                       children: [
//                         SizedBox(
//                           width: 20,
//                           height: 20,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         ),
//                         SizedBox(width: 12),
//                         Text('در حال حذف نظر...'),
//                       ],
//                     ),
//                     duration: Duration(seconds: 30),
//                   ),
//                 );

//                 await _deleteComment(context, ref, comment.id, widget.postId);

//                 // نمایش پیام موفقیت با انیمیشن
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).clearSnackBars();
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Row(
//                         children: [
//                           Icon(Icons.check_circle, color: Colors.green[300]),
//                           const SizedBox(width: 12),
//                           const Text('نظر با موفقیت حذف شد'),
//                         ],
//                       ),
//                       behavior: SnackBarBehavior.floating,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   );
//                 }
//               } catch (e) {
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).clearSnackBars();
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Row(
//                         children: [
//                           const Icon(Icons.error_outline, color: Colors.white),
//                           const SizedBox(width: 12),
//                           Expanded(child: Text('خطا در حذف نظر: $e')),
//                         ],
//                       ),
//                       backgroundColor: Colors.red,
//                       behavior: SnackBarBehavior.floating,
//                     ),
//                   );
//                 }
//               }
//             }
//             break;
//           case 'copy':
//             await Clipboard.setData(ClipboardData(text: comment.content));
//             if (mounted) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Row(
//                     children: [
//                       const Icon(Icons.copy, color: Colors.white),
//                       const SizedBox(width: 12),
//                       const Text('متن نظر کپی شد'),
//                     ],
//                   ),
//                   behavior: SnackBarBehavior.floating,
//                   duration: const Duration(seconds: 2),
//                 ),
//               );
//             }
//             break;
//           case 'report':
//             await _showReportDialog(context, ref, comment);
//             break;
//         }
//       },
//     );
//   }

//   Future<void> _showReportDialog(
//       BuildContext context, WidgetRef ref, CommentModel comment) async {
//     final theme = Theme.of(context);
//     String selectedReason = '';
//     final TextEditingController additionalDetailsController =
//         TextEditingController();
//     final List<String> reportReasons = [
//       'محتوای نامناسب',
//       'هرزنگاری',
//       'توهین آمیز',
//       'اسپم',
//       'محتوای تبلیغاتی',
//       'سایر موارد'
//     ];

//     final result = await showDialog<Map<String, String>?>(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//               contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//               title: Row(
//                 children: [
//                   Icon(Icons.report_problem_outlined,
//                       color: theme.colorScheme.error),
//                   const SizedBox(width: 8),
//                   Text(
//                     'گزارش نظر',
//                     style: theme.textTheme.titleMedium
//                         ?.copyWith(fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//               content: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // نمایش خلاصه کامنت گزارش شده
//                     Container(
//                       margin: const EdgeInsets.symmetric(vertical: 8),
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color:
//                             theme.colorScheme.surfaceVariant.withOpacity(0.5),
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(
//                           color: theme.colorScheme.outlineVariant,
//                           width: 1,
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'نظر از: ${comment.username}',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w500,
//                               fontSize: 13,
//                               color: theme.colorScheme.onSurfaceVariant,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             comment.content.length > 100
//                                 ? '${comment.content.substring(0, 100)}...'
//                                 : comment.content,
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: theme.colorScheme.onSurfaceVariant,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: Text(
//                         'لطفاً دلیل گزارش را انتخاب کنید:',
//                         style: theme.textTheme.bodyMedium?.copyWith(
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),

//                     // لیست دلایل گزارش
//                     Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color:
//                               theme.colorScheme.outlineVariant.withOpacity(0.5),
//                           width: 1,
//                         ),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Column(
//                         children: reportReasons.map((reason) {
//                           return RadioListTile<String>(
//                             title: Text(
//                               reason,
//                               style: theme.textTheme.bodyMedium,
//                             ),
//                             value: reason,
//                             groupValue: selectedReason,
//                             activeColor: theme.colorScheme.primary,
//                             onChanged: (value) {
//                               setState(() {
//                                 selectedReason = value!;
//                               });
//                             },
//                             contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 4,
//                             ),
//                             dense: true,
//                           );
//                         }).toList(),
//                       ),
//                     ),

//                     // فیلد توضیحات اضافی برای 'سایر موارد'
//                     if (selectedReason == 'سایر موارد')
//                       AnimatedContainer(
//                         duration: const Duration(milliseconds: 300),
//                         margin: const EdgeInsets.only(top: 16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'لطفاً جزئیات بیشتری ارائه دهید:',
//                               style: theme.textTheme.bodyMedium,
//                             ),
//                             const SizedBox(height: 8),
//                             TextField(
//                               controller: additionalDetailsController,
//                               decoration: InputDecoration(
//                                 hintText: 'توضیحات خود را وارد کنید...',
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 contentPadding: const EdgeInsets.all(12),
//                               ),
//                               maxLines: 3,
//                               style: theme.textTheme.bodyMedium,
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 // دکمه انصراف
//                 TextButton(
//                   style: TextButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 8,
//                     ),
//                   ),
//                   onPressed: () => Navigator.pop(context),
//                   child: Text(
//                     'انصراف',
//                     style: TextStyle(color: theme.colorScheme.onSurface),
//                   ),
//                 ),

//                 // دکمه ارسال گزارش
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: theme.colorScheme.primary,
//                     foregroundColor: theme.colorScheme.onPrimary,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 8,
//                     ),
//                   ),
//                   onPressed: selectedReason.isEmpty
//                       ? null
//                       : () {
//                           Navigator.pop(
//                             context,
//                             {
//                               'reason': selectedReason,
//                               'details': additionalDetailsController.text,
//                             },
//                           );
//                         },
//                   child: const Text('ثبت گزارش'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );

//     // پردازش نتیجه دیالوگ
//     if (result != null) {
//       try {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//                 SizedBox(width: 12),
//                 Text('در حال ثبت گزارش...'),
//               ],
//             ),
//           ),
//         );

//         // در اینجا می‌توانید کد مربوط به ارسال گزارش به سرور را اضافه کنید
//         // مثال:
//         // await ref.read(reportProvider.notifier).reportComment(
//         //  commentId: comment.id,
//         //  reason: result['reason']!,
//         //  details: result['details'] ?? '',
//         // );

//         await Future.delayed(const Duration(milliseconds: 1000));

//         if (mounted) {
//           ScaffoldMessenger.of(context).clearSnackBars();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Row(
//                 children: [
//                   Icon(Icons.check_circle, color: Colors.green[300]),
//                   const SizedBox(width: 12),
//                   const Text('گزارش شما با موفقیت ثبت شد'),
//                 ],
//               ),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).clearSnackBars();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Row(
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.white),
//                   const SizedBox(width: 12),
//                   Expanded(child: Text('خطا در ثبت گزارش: $e')),
//                 ],
//               ),
//               backgroundColor: Colors.red,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//       }
//     }
//   }

//   void _onTextChanged(String text) {
//     // Add your logic here for handling text changes
//   }

//   Widget _buildCommentInputArea(BuildContext context, List<UserModel> mentionNotifier) {
//     final theme = Theme.of(context);
//     final bool isReplying = replyToCommentId != null;
//     final bool isTyping = commentController.text.isNotEmpty;

//     return Container(
//       decoration: BoxDecoration(
//         color: theme.scaffoldBackgroundColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, -5),
//           ),
//         ],
//         border: Border(
//           top: BorderSide(
//             color: theme.dividerColor,
//             width: 0.5,
//           ),
//         ),
//       ),
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 12,
//         bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // نمایش باکس پاسخ دادن
//           if (isReplying)
//             GestureDetector(
//               onTap: () {
//                 // یک نمایی مختصر از کامنت را نشان می‌دهد
//               },
//               child: Container(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: theme.colorScheme.primary.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: theme.colorScheme.primary.withOpacity(0.2),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Text(
//                                 'در پاسخ به ',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: theme.colorScheme.onSurface
//                                       .withOpacity(0.7),
//                                 ),
//                               ),
//                               Text(
//                                 replyToUsername ?? "کاربر",
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                   color: theme.colorScheme.primary,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.close, size: 18),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                       onPressed: () {
//                         setState(() {
//                           replyToCommentId = null;
//                           replyToUsername = null;
//                           commentController.text = commentController.text
//                               .replaceFirst(RegExp(r'@\w+\s'), '');
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           // لیست پیشنهادات @mention
//           if (mentionNotifier.isNotEmpty)
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               curve: Curves.easeInOut,
//               margin: const EdgeInsets.only(bottom: 12),
//               height: mentionNotifier.isEmpty ? 0 : 56,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: mentionNotifier.length,
//                 itemBuilder: (context, index) {
//                   final user = mentionNotifier[index];
//                   return Padding(
//                     padding: const EdgeInsets.only(right: 8),
//                     child: Material(
//                       color: theme.colorScheme.surfaceVariant,
//                       borderRadius: BorderRadius.circular(24),
//                       child: InkWell(
//                         borderRadius: BorderRadius.circular(24),
//                         onTap: () => _onMentionTap(user),
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 6,
//                           ),
//                           child: Row(
//                             children: [
//                               CircleAvatar(
//                                 radius: 16,
//                                 backgroundImage: user.avatarUrl != null &&
//                                         user.avatarUrl!.isNotEmpty
//                                     ? CachedNetworkImageProvider(
//                                         user.avatarUrl!)
//                                     : const AssetImage(
//                                             'lib/util/images/default-avatar.jpg')
//                                         as ImageProvider,
//                               ),
//                               const SizedBox(width: 8),
//                               Text(
//                                 user.username,
//                                 style: theme.textTheme.bodyMedium?.copyWith(
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),

//           // فیلد ورودی کامنت
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               // آواتار کاربر فعلی
//               CircleAvatar(
//                 radius: 18,
//                 backgroundImage:
//                     const AssetImage('lib/util/images/default-avatar.jpg'),
//               ),
//               const SizedBox(width: 12),

//               // فیلد متن کامنت
//               Expanded(
//                 child: Container(
//                   constraints: const BoxConstraints(
//                     minHeight: 40,
//                     maxHeight: 120,
//                   ),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Directionality(
//                     textDirection: TextDirection.rtl,
//                     child: TextField(
//                       controller: commentController,
//                       focusNode: commentFocusNode,
//                       maxLines: null,
//                       keyboardType: TextInputType.multiline,
//                       textCapitalization: TextCapitalization.sentences,
//                       style: theme.textTheme.bodyLarge,
//                       decoration: InputDecoration(
//                         hintText: isReplying
//                             ? 'پاسخ خود را بنویسید...'
//                             : 'نظر خود را بنویسید...',
//                         hintStyle: TextStyle(
//                           color: theme.hintColor,
//                           fontSize: 14,
//                         ),
//                         isDense: true,
//                         contentPadding:
//                             const EdgeInsets.fromLTRB(12, 12, 16, 12),
//                         border: InputBorder.none,
//                       ),
//                       onChanged: _onTextChanged,
//                     ),
//                   ),
//                 ),
//               ),

//               // دکمه ارسال
//               const SizedBox(width: 8),
//               Material(
//                 color: isTyping
//                     ? theme.colorScheme.primary
//                     : theme.colorScheme.surfaceVariant,
//                 borderRadius: BorderRadius.circular(24),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(24),
//                   onTap: isTyping ? _sendComment : null,
//                   child: Container(
//                     padding: const EdgeInsets.all(10),
//                     child: Icon(
//                       Icons.send,
//                       size: 20,
//                       color: isTyping
//                           ? theme.colorScheme.onPrimary
//                           : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
