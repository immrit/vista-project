
// void showCommentsBottomSheet(
//     BuildContext context, WidgetRef ref, String postId, String userId) {
//   final commentController = TextEditingController();
//   final commentFocusNode = FocusNode();
//   final mentionedUsers = <UserModel>[];
//   String? replyToCommentId;
//   String? replyToUsername;

//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (context) => StatefulBuilder(
//       builder: (context, setState) {
//         return DraggableScrollableSheet(
//           initialChildSize: 0.75, // شروع از 75% صفحه
//           minChildSize: 0.4, // حداقل 40% صفحه
//           maxChildSize: 0.95, // حداکثر 95% صفحه
//           expand: false,
//           builder: (_, controller) => Column(
//             children: [
//               // Handle bar
//               Container(
//                 margin: const EdgeInsets.symmetric(vertical: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),

//               // Header
//               Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Row(
//                   children: [
//                     Text(
//                       'نظرات',
//                       style: Theme.of(context).textTheme.titleLarge,
//                     ),
//                     const Spacer(),
//                     IconButton(
//                       icon: const Icon(Icons.close),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                   ],
//                 ),
//               ),

//               // Reply indicator with animation
//               AnimatedContainer(
//                 duration: const Duration(milliseconds: 300),
//                 height: replyToUsername != null ? 50 : 0,
//                 child: replyToUsername != null
//                     ? Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         color: Colors.blue.withOpacity(0.1),
//                         child: Row(
//                           children: [
//                             const Icon(Icons.reply, color: Colors.blue),
//                             const SizedBox(width: 8),
//                             Text(
//                               'در پاسخ به: $replyToUsername',
//                               style: const TextStyle(color: Colors.blue),
//                             ),
//                             const Spacer(),
//                             IconButton(
//                               icon: const Icon(Icons.close, color: Colors.blue),
//                               onPressed: () => setState(() {
//                                 replyToCommentId = null;
//                                 replyToUsername = null;
//                                 commentController.clear();
//                               }),
//                             ),
//                           ],
//                         ),
//                       )
//                     : null,
//               ),

//               // Comments list
//               Expanded(
//                 child: Consumer(
//                   builder: (context, ref, _) {
//                     final commentsAsyncValue =
//                         ref.watch(commentsProvider(postId));

//                     return commentsAsyncValue.when(
//                       data: (comments) => comments.isEmpty
//                           ? _buildEmptyState(context)
//                           : RefreshIndicator(
//                               onRefresh: () async {
//                                 ref.invalidate(commentsProvider(postId));
//                               },
//                               child: ListView.builder(
//                                 controller: controller,
//                                 itemCount: comments.length,
//                                 physics: const AlwaysScrollableScrollPhysics(),
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 16),
//                                 itemBuilder: (context, index) {
//                                   final comment = comments[index];
//                                   return AnimatedContainer(
//                                     duration: Duration(milliseconds: 300),
//                                     curve: Curves.easeInOut,
//                                     child: _buildCommentTile(
//                                       context,
//                                       ref,
//                                       comment,
//                                       userId,
//                                       onReply: ({
//                                         required String parentCommentId,
//                                         required String parentUsername,
//                                         required String postId,
//                                       }) {
//                                         setState(() {
//                                           replyToCommentId = parentCommentId;
//                                           replyToUsername = parentUsername;
//                                           commentController.text =
//                                               '@$parentUsername ';
//                                           commentFocusNode.requestFocus();
//                                         });
//                                       },
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                       error: (error, stack) => Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Icon(Icons.error_outline,
//                                 size: 48, color: Colors.red),
//                             const SizedBox(height: 16),
//                             Text('Error: $error'),
//                             TextButton(
//                               onPressed: () =>
//                                   ref.invalidate(commentsProvider(postId)),
//                               child: const Text('تلاش مجدد'),
//                             ),
//                           ],
//                         ),
//                       ),
//                       loading: () => const Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                     );
//                   },
//                 ),
//               ),

//               // Input section
//               Container(
//                 padding: EdgeInsets.fromLTRB(
//                   16,
//                   8,
//                   16,
//                   MediaQuery.of(context).viewInsets.bottom + 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Theme.of(context).cardColor,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 4,
//                       offset: Offset(0, -2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: commentController,
//                         focusNode: commentFocusNode,
//                         textDirection: TextDirection.rtl,
//                         maxLines: null,
//                         decoration: InputDecoration(
//                           hintText: replyToUsername != null
//                               ? 'پاسخ خود را بنویسید...'
//                               : 'نظر خود را بنویسید...',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(20),
//                             borderSide: BorderSide.none,
//                           ),
//                           filled: true,
//                           fillColor:
//                               Theme.of(context).brightness == Brightness.dark
//                                   ? Colors.grey[800]
//                                   : Colors.grey[200],
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 8,
//                           ),
//                         ),
//                         onChanged: (value) => _handleMentionSearch(
//                           ref,
//                           value,
//                           setState,
//                           mentionedUsers,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     IconButton(
//                       icon: const Icon(Icons.send),
//                       // color: Theme.of(context).primaryColor,
//                       onPressed: () {
//                         final content = commentController.text.trim();
//                         if (content.isNotEmpty) {
//                           _sendComment(
//                             context,
//                             ref,
//                             postId,
//                             commentController,
//                             mentionedUsers,
//                             parentCommentId: replyToCommentId,
//                           );
//                           setState(() {
//                             replyToCommentId = null;
//                             replyToUsername = null;
//                             commentController.clear();
//                           });
//                         }
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     ),
//   );
// }

// // Mention Search Handler
// void _handleMentionSearch(WidgetRef ref, String value, StateSetter setState,
//     List<UserModel> mentionedUsers) {
//   if (value.contains('@')) {
//     final mentionPart = value.split('@').last;
//     if (mentionPart.isNotEmpty) {
//       ref
//           .read(mentionNotifierProvider.notifier)
//           .searchMentionableUsers(mentionPart);
//     }
//   } else {
//     ref.read(mentionNotifierProvider.notifier).clearMentions();
//   }
// }

// // Mention Suggestions Widget
// Widget _buildMentionSuggestions(
//   BuildContext context,
//   List<UserModel> mentionUsers,
//   StateSetter setState,
//   TextEditingController commentController,
//   List<UserModel> mentionedUsers,
// ) {
//   return SizedBox(
//     height: 100,
//     child: ListView.builder(
//       scrollDirection: Axis.horizontal,
//       itemCount: mentionUsers.length,
//       itemBuilder: (context, index) {
//         final user = mentionUsers[index];
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 4),
//           child: GestureDetector(
//             onTap: () {
//               // Add mention to comment
//               _addMentionToComment(
//                   commentController, user, setState, mentionedUsers);
//             },
//             child: Chip(
//               avatar: CircleAvatar(
//                 backgroundImage: user.avatarUrl != null
//                     ? NetworkImage(user.avatarUrl!) as ImageProvider
//                     : const AssetImage(defaultAvatarUrl),
//               ),
//               label: Text(user.username),
//             ),
//           ),
//         );
//       },
//     ),
//   );
// }

// // Add Mention to Comment
// void _addMentionToComment(
//   TextEditingController commentController,
//   UserModel user,
//   StateSetter setState,
//   List<UserModel> mentionedUsers,
// ) {
//   final currentText = commentController.text;
//   final mentionPart = currentText.split('@').last;
//   final newText =
//       currentText.replaceFirst('@$mentionPart', '@${user.username} ');

//   commentController.text = newText;
//   commentController.selection =
//       TextSelection.fromPosition(TextPosition(offset: newText.length));

//   setState(() {
//     if (!mentionedUsers.any((u) => u.id == user.id)) {
//       final mentionedUsersSet = <UserModel>{};
//       mentionedUsersSet.add(user);
//       mentionedUsers.clear();
//       mentionedUsers.addAll(mentionedUsersSet);
//     }
//   });
// }

// // Send Comment Method
// void _sendComment(BuildContext context, WidgetRef ref, String postId,
//     TextEditingController commentController, List<UserModel> mentionedUsers,
//     {String? parentCommentId}) async {
//   final content = commentController.text.trim();
//   final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

//   if (content.isNotEmpty) {
//     try {
//       await ref
//           .read(commentNotifierProvider.notifier)
//           .addComment(
//             postId: postId,
//             postOwnerId: supabase.auth.currentUser!.id,
//             content: content, // محتوای کامل کامنت
//             ref: ref,
//             mentionedUserIds: mentionedUserIds,
//             parentCommentId: parentCommentId,
//           )
//           .then((value) {
//         commentController.clear();
//         mentionedUsers.clear();
//       });

//       ref.read(mentionNotifierProvider.notifier).clearMentions();
//       ref.invalidate(commentsProvider(postId));
//     } catch (e) {
//       print('خطا در ارسال کامنت: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('خطا در ارسال کامنت: $e')),
//       );
//     }
//   }
// }

// // Comments List Widget
// Widget _buildEmptyState(BuildContext context) {
//   return Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(
//           Icons.comment_outlined,
//           size: 48,
//           color: Colors.grey[400],
//         ),
//         const SizedBox(height: 16),
//         Text(
//           'هنوز نظری ثبت نشده است',
//           style: TextStyle(
//             color: Colors.grey[600],
//             fontSize: 16,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildCommentsList(BuildContext context, WidgetRef ref,
//     List<CommentModel> comments, String userId) {
//   return ListView.builder(
//     // reverse: false,
//     itemCount: comments.length,
//     itemBuilder: (context, index) {
//       final comment = comments[index];
//       return _buildCommentTile(context, ref, comment, userId, onReply: ({
//         required String parentCommentId,
//         required String parentUsername,
//         required String postId,
//       }) {
//         _showReplyBottomSheet(context, ref, postId,
//             parentCommentId: parentCommentId, parentUsername: parentUsername);
//       });
//     },
//   );
// }

// Widget _buildCommentTile(BuildContext context, WidgetRef ref,
//     CommentModel comment, String currentUserId,
//     {required Function({
//       required String parentCommentId,
//       required String parentUsername,
//       required String postId,
//     }) onReply}) {
//   final theme = Theme.of(context);
//   final isDarkMode = theme.brightness == Brightness.dark;

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       GestureDetector(
//         onTap: () {
//           Navigator.of(context).push(MaterialPageRoute(
//               builder: (context) => ProfileScreen(
//                   userId: comment.userId, username: comment.username)));
//         },
//         child: ListTile(
//           contentPadding:
//               const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           leading: Hero(
//             tag: 'avatar_${comment.id}',
//             child: CircleAvatar(
//               radius: 25,
//               backgroundImage: comment.avatarUrl != null
//                   ? NetworkImage(comment.avatarUrl)
//                   : null,
//               child: comment.avatarUrl == const AssetImage(defaultAvatarUrl)
//                   ? Icon(
//                       Icons.person,
//                       color: isDarkMode ? Colors.white : Colors.black,
//                     )
//                   : null,
//             ),
//           ),
//           title: Row(
//             children: [
//               Text(
//                 comment.username,
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: isDarkMode ? Colors.white70 : Colors.black87,
//                 ),
//               ),
//               const SizedBox(width: 2),
//               if (comment.isVerified)
//                 const Icon(
//                   Icons.verified,
//                   color: Colors.blue,
//                   size: 15,
//                 )
//             ],
//           ),
//           subtitle: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Directionality(
//                 textDirection: getDirectionality(comment.content),
//                 child: RichText(
//                   text: TextSpan(
//                     children:
//                         _buildCommentTextSpans(comment, isDarkMode, context),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     _formatCommentTime(comment.createdAt),
//                     style: theme.textTheme.bodySmall?.copyWith(
//                       color: isDarkMode
//                           ? Colors.grey.shade400
//                           : Colors.grey.shade600,
//                     ),
//                   ),
//                   PopupMenuButton<String>(
//                     onSelected: (value) async {
//                       if (value == 'گزارش تخلف') {
//                         await _showReportDialog(
//                             context, ref, comment, currentUserId);
//                       } else if (value == 'حذف کامنت') {
//                         await _showDeleteConfirmationDialog(
//                                 context, ref, comment)
//                             .then((value) => ref
//                                 .invalidate(commentsProvider(comment.postId)));
//                       }
//                     },
//                     itemBuilder: (BuildContext context) {
//                       List<PopupMenuEntry<String>> menuItems = [
//                         const PopupMenuItem<String>(
//                           value: 'گزارش تخلف',
//                           child: Text('گزارش تخلف'),
//                         )
//                       ];

//                       if (comment.userId == currentUserId ||
//                           comment.postOwnerId == currentUserId) {
//                         menuItems.add(
//                           const PopupMenuItem<String>(
//                             value: 'حذف کامنت',
//                             child: Text('حذف'),
//                           ),
//                         );
//                       }

//                       return menuItems;
//                     },
//                   ),
//                 ],
//               )
//             ],
//           ),
//           trailing: IconButton(
//             icon: const Icon(Icons.reply),
//             onPressed: () {
//               onReply(
//                 parentCommentId: comment.id,
//                 parentUsername: comment.username,
//                 postId: comment.postId,
//               );
//             },
//           ),
//         ),
//       ),

//       // نمایش ریپلای‌ها
//       if (comment.replies.isNotEmpty)
//         ExpansionTile(
//           title: Text(
//             'نمایش ${comment.replies.length} پاسخ',
//             style: const TextStyle(
//               color: Colors.blue,
//               fontSize: 13,
//             ),
//           ),
//           children: comment.replies
//               .map((reply) => _buildCommentTile(
//                       context, ref, reply, currentUserId, onReply: ({
//                     required String parentCommentId,
//                     required String parentUsername,
//                     required String postId,
//                   }) {
//                     onReply(
//                       parentCommentId: reply.id,
//                       parentUsername: reply.username,
//                       postId: reply.postId,
//                     );
//                   }))
//               .toList(),
//         ),

//       Divider(
//         endIndent: 1,
//         indent: 1,
//         color: Theme.of(context).brightness == Brightness.dark
//             ? Colors.white10
//             : Colors.black26, // رنگ متفاوت برای تم روشن
//       )
//     ],
//   );
// }

// void _showReplyBottomSheet(
//   BuildContext context,
//   WidgetRef ref,
//   String postId, {
//   required String parentCommentId,
//   String? parentUsername, // اضافه کردن نام کاربری والد
// }) {
//   final TextEditingController replyController = TextEditingController();
//   final FocusNode replyFocusNode = FocusNode();
//   final List<UserModel> mentionedUsers = [];

//   // اگر نام کاربری والد وجود دارد، اتوماتیک منشن شود
//   if (parentUsername != null) {
//     replyController.text = '@$parentUsername ';
//   }

//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (BuildContext context) {
//       return StatefulBuilder(
//         builder: (context, setState) {
//           return Padding(
//             padding: EdgeInsets.only(
//               bottom: MediaQuery.of(context).viewInsets.bottom,
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // TextField با قابلیت منشن
//                 TextField(
//                   controller: replyController,
//                   focusNode: replyFocusNode,
//                   onChanged: (value) {
//                     _handleMentionSearch(ref, value, setState, mentionedUsers);
//                   },
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     labelText: 'پاسخ خود را بنویسید...',
//                     suffixIcon: IconButton(
//                       icon: const Icon(Icons.send),
//                       onPressed: () {
//                         _sendReply(
//                           context,
//                           ref,
//                           postId,
//                           replyController,
//                           parentCommentId,
//                           mentionedUsers, // ارسال لیست کاربران منشن شده
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//                 Consumer(
//                   builder: (context, ref, _) {
//                     final mentionUsers = ref.watch(mentionNotifierProvider);
//                     return mentionUsers.isNotEmpty
//                         ? _buildMentionSuggestions(context, mentionUsers,
//                             setState, replyController, mentionedUsers)
//                         : const SizedBox.shrink();
//                   },
//                 ),
//               ],
//             ),
//           );
//         },
//       );
//     },
//   );
// }

// // تغییر در تابع _sendReply
// void _sendReply(
//   BuildContext context,
//   WidgetRef ref,
//   String postId,
//   TextEditingController replyController,
//   String parentCommentId,
//   List<UserModel> mentionedUsers,
// ) async {
//   final content = replyController.text.trim();
//   final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

//   if (content.isNotEmpty) {
//     try {
//       await ref
//           .read(commentNotifierProvider.notifier)
//           .addComment(
//               postId: postId,
//               postOwnerId: supabase.auth.currentUser!.id,
//               content: content,
//               parentCommentId: parentCommentId,
//               mentionedUserIds: mentionedUserIds, // اضافه کردن منشن‌ها
//               ref: ref)
//           .then((value) {
//         replyController.clear();
//         mentionedUsers.clear();
//         Navigator.pop(context);
//       });

//       ref.invalidate(commentsProvider(postId));
//     } catch (e) {
//       print('خطا در ارسال پاسخ: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('خطا در ارسال پاسخ: $e')),
//       );
//     }
//   }
// }

// // تابع نمایش دیالوگ گزارش
// Future<void> _showReportDialog(BuildContext context, WidgetRef ref,
//     CommentModel comment, String currentUserId) async {
//   String selectedReason = '';
//   TextEditingController additionalDetailsController = TextEditingController();

//   final confirmed = await showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       return StatefulBuilder(
//         builder: (context, setState) {
//           final theme = Theme.of(context);
//           return AlertDialog(
//             title: const Text('گزارش تخلف'),
//             content: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text('لطفاً دلیل گزارش را انتخاب کنید:'),
//                   ...[
//                     'محتوای نامناسب',
//                     'هرزنگاری',
//                     'توهین آمیز',
//                     'اسپم',
//                     'محتوای تبلیغاتی',
//                     'سایر موارد'
//                   ].map((reason) {
//                     return RadioListTile<String>(
//                       title: Text(reason),
//                       value: reason,
//                       groupValue: selectedReason,
//                       onChanged: (value) {
//                         setState(() {
//                           selectedReason = value!;
//                         });
//                       },
//                     );
//                   }),
//                   if (selectedReason == 'سایر موارد')
//                     TextField(
//                       controller: additionalDetailsController,
//                       decoration: const InputDecoration(
//                         hintText: 'جزئیات بیشتر را وارد کنید',
//                       ),
//                       maxLines: 3,
//                     ),
//                 ],
//               ),
//             ),
//             actions: <Widget>[
//               TextButton(
//                 style: TextButton.styleFrom(
//                   foregroundColor: theme.textTheme.bodyLarge?.color,
//                 ),
//                 child: const Text('لغو'),
//                 onPressed: () {
//                   Navigator.of(context).pop(false);
//                 },
//               ),
//               TextButton(
//                 style: TextButton.styleFrom(
//                   backgroundColor: theme.colorScheme.secondary,
//                   foregroundColor: theme.colorScheme.onSecondary,
//                 ),
//                 child: const Text('گزارش'),
//                 onPressed: () {
//                   if (selectedReason.isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text('لطفاً دلیل گزارش را انتخاب کنید'),
//                       ),
//                     );
//                     return;
//                   }
//                   Navigator.of(context).pop(true);
//                 },
//               ),
//             ],
//           );
//         },
//       );
//     },
//   );

//   if (confirmed == true) {
//     try {
//       await ref.read(reportCommentServiceProvider).reportComment(
//             commentId: comment.id,
//             reporterId: currentUserId,
//             reason: selectedReason,
//             additionalDetails: selectedReason == 'سایر موارد'
//                 ? additionalDetailsController.text.trim()
//                 : null,
//           );

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('کامنت با موفقیت گزارش شد.'),
//         ),
//       );
//     } catch (e) {
//       print('خطا در گزارش تخلف: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('خطا در گزارش کامنت.'),
//         ),
//       );
//     }
//   }
// }

// // تابع نمایش دیالوگ حذف
// Future<void> _showDeleteConfirmationDialog(
//     BuildContext context, WidgetRef ref, CommentModel comment) async {
//   final confirmDelete = await showDialog<bool>(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text('حذف'),
//       content: const Text('آیا از حذف این کامنت اطمینان دارید؟'),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(false),
//           child: Text(
//             'انصراف',
//             style: TextStyle(
//               color: Theme.of(context).brightness == Brightness.dark
//                   ? Colors.white
//                   : Colors.grey[800],
//             ),
//           ),
//         ),
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//           onPressed: () => Navigator.of(context).pop(true),
//           child: Text(
//             'حذف',
//             style: TextStyle(
//                 color: Theme.of(context).brightness == Brightness.dark
//                     ? Colors.white
//                     : Colors.grey[800]),
//           ),
//         ),
//       ],
//     ),
//   );

//   if (confirmDelete == true) {
//     try {
//       // حذف کامنت با استفاده از provider
//       await ref
//           .read(commentNotifierProvider.notifier)
//           .deleteComment(comment.id, ref);

//       // نمایش پیام موفقیت
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('کامنت با موفقیت حذف شد.'),
//         ),
//       );
//     } catch (e) {
//       // نمایش خطا در صورت شکست حذف
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('خطا در حذف کامنت.'),
//         ),
//       );
//     }
//   }
// }

// // Parse comment text to handle mentions
// List<TextSpan> _buildCommentTextSpans(
//     CommentModel comment, bool isDarkMode, BuildContext context) {
//   final List<TextSpan> spans = [];
//   final mentionRegex = RegExp(r'@(\w+)');

//   final matches = mentionRegex.allMatches(comment.content);
//   int lastIndex = 0;

//   for (final match in matches) {
//     // متن قبل از منشن
//     if (match.start > lastIndex) {
//       spans.add(
//         TextSpan(
//           text: comment.content.substring(lastIndex, match.start),
//           style: TextStyle(
//             color: isDarkMode ? Colors.white : Colors.black87,
//           ),
//         ),
//       );
//     }

//     // استایل منشن
//     spans.add(
//       TextSpan(
//         text: match.group(0),
//         style: TextStyle(
//           color: Colors.blue.shade400,
//           fontWeight: FontWeight.bold,
//         ),
//         recognizer: TapGestureRecognizer()
//           ..onTap = () async {
//             final username = match.group(1); // استخراج نام کاربری
//             if (username != null) {
//               // دریافت userId از پایگاه داده یا API بر اساس username
//               final userId = await getUserIdByUsername(username);
//               if (userId != null) {
//                 // ناوبری به پروفایل کاربر
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => ProfileScreen(
//                       username: username,
//                       userId: userId,
//                     ),
//                   ),
//                 );
//               }
//             }
//           },
//       ),
//     );

//     lastIndex = match.end;
//   }

//   // متن باقی مانده
//   if (lastIndex < comment.content.length) {
//     spans.add(
//       TextSpan(
//         text: comment.content.substring(lastIndex),
//         style: TextStyle(
//             color: isDarkMode ? Colors.white : Colors.black87, fontSize: 15),
//       ),
//     );
//   }

//   return spans;
// }

// // یک متد برای جلب userId از پایگاه داده بر اساس username
// Future<String?> getUserIdByUsername(String username) async {
//   // فرض کنید از Supabase برای جلب userId استفاده می‌کنید
//   final response = await supabase
//       .from('profiles')
//       .select('id')
//       .eq('username', username)
//       .single();

//   if (response['id'] != null) {
//     return response['id'];
//   } else {
//     return null; // اگر کاربر یافت نشد
//   }
// }

// // Delete Comment Method
// void _deleteComment(BuildContext context, WidgetRef ref, String commentId,
//     String postId) async {
//   try {
//     await ref
//         .read(commentNotifierProvider.notifier)
//         .deleteComment(commentId, ref);

//     // Optional: Refresh comments list
//     ref.invalidate(commentsProvider(postId));

//     // Optional: Show success message
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('کامنت با موفقیت حذف شد')),
//     );
//   } catch (e) {
//     // Handle error
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('خطا در حذف کامنت: $e')),
//     );
//   }
// }

// // Report Comment Method
// void _reportComment(BuildContext context, CommentModel comment) {
//   showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text('گزارش تخلف'),
//       content: TextField(
//         decoration: const InputDecoration(
//           hintText: 'دلیل گزارش را توضیح دهید',
//         ),
//         maxLines: 3,
//         onChanged: (reason) {
//           // You can implement reporting logic here
//         },
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('انصراف'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             // Implement report submission
//             Navigator.pop(context);
//           },
//           child: const Text('ثبت گزارش'),
//         ),
//       ],
//     ),
//   );
// }

// // Time formatting utility
// String _formatCommentTime(DateTime createdAt) {
//   final now = DateTime.now();
//   final difference = now.difference(createdAt);

//   if (difference.inMinutes < 1) {
//     return 'همین الان';
//   } else if (difference.inHours < 1) {
//     return '${difference.inMinutes} دقیقه پیش';
//   } else if (difference.inDays < 1) {
//     return '${difference.inHours} ساعت پیش';
//   } else if (difference.inDays < 7) {
//     return '${difference.inDays} روز پیش';
//   } else {
//     return '${createdAt.year}/${createdAt.month}/${createdAt.day}';
//   }
// }