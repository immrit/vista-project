import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../model/publicPostModel.dart';
import '/main.dart';
import '/view/screen/PublicPosts/profileScreen.dart';
import '../../../model/CommentModel.dart';
import '../../../model/UserModel.dart';
import '../../../provider/provider.dart';

class PostDetailsPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailsPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends ConsumerState<PostDetailsPage> {
  late TextEditingController commentController;
  String? replyToCommentId;
  final List<UserModel> mentionedUsers = [];

  @override
  void initState() {
    super.initState();
    commentController = TextEditingController();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postAsyncValue = ref.watch(postProvider(widget.postId));
    final mentionNotifier = ref.watch(mentionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات پست'),
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            postAsyncValue.when(
              data: (post) => _buildPostDetails(context, post),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('خطا در بارگذاری پست: $error')),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCommentInputArea(context, mentionNotifier),
    );
  }

  // Widget _buildPostImages(PublicPostModel post) {
  //   if (post.imageUrl == null || post.imageUrl!.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 10),
  //     child: GestureDetector(
  //       onTap: () => _showImageDialog(context, post.imageUrl!),
  //       child: ClipRRect(
  //         borderRadius: BorderRadius.circular(8),
  //         child: Image.network(
  //           post.imageUrl!,
  //           fit: BoxFit.cover,
  //           height: 200,
  //           width: double.infinity,
  //           errorBuilder: (context, error, stackTrace) {
  //             return Container(
  //               height: 200,
  //               width: double.infinity,
  //               color: Colors.grey[300],
  //               child: const Center(
  //                 child:
  //                     Icon(Icons.error_outline, size: 40, color: Colors.grey),
  //               ),
  //             );
  //           },
  //           loadingBuilder: (context, child, loadingProgress) {
  //             if (loadingProgress == null) return child;
  //             return Container(
  //               height: 200,
  //               width: double.infinity,
  //               color: Colors.grey[100],
  //               child: Center(
  //                 child: CircularProgressIndicator(
  //                   value: loadingProgress.expectedTotalBytes != null
  //                       ? loadingProgress.cumulativeBytesLoaded /
  //                           loadingProgress.expectedTotalBytes!
  //                       : null,
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildPostImages(PublicPostModel post) {
  //   if (post.imageUrl == null || post.imageUrl!.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 10),
  //     child: FutureBuilder<Size>(
  //       future: _getImageDimensions(post.imageUrl!),
  //       builder: (context, snapshot) {
  //         if (snapshot.connectionState == ConnectionState.waiting) {
  //           return Container(
  //             width: double.infinity,
  //             height: 200,
  //             color: Colors.grey[100],
  //             child: const Center(child: CircularProgressIndicator()),
  //           );
  //         }

  //         if (snapshot.hasError || !snapshot.hasData) {
  //           return Container(
  //             width: double.infinity,
  //             height: 200,
  //             color: Colors.grey[300],
  //             child: const Center(
  //               child: Icon(Icons.error_outline, size: 40, color: Colors.grey),
  //             ),
  //           );
  //         }

  //         double screenWidth = MediaQuery.of(context).size.width -
  //             20; // پدینگ را در نظر می‌گیریم
  //         double imageRatio = snapshot.data!.width / snapshot.data!.height;
  //         double displayHeight = screenWidth / imageRatio;

  //         return ClipRRect(
  //           borderRadius: BorderRadius.circular(15),
  //           child: Image.network(
  //             post.imageUrl!,
  //             width: screenWidth,
  //             height: displayHeight,
  //             fit: BoxFit.contain,
  //             errorBuilder: (context, error, stackTrace) {
  //               return Container(
  //                 width: screenWidth,
  //                 height: 200,
  //                 color: Colors.grey[300],
  //                 child: const Center(
  //                   child:
  //                       Icon(Icons.error_outline, size: 40, color: Colors.grey),
  //                 ),
  //               );
  //             },
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  // Future<Size> _getImageDimensions(String imageUrl) async {
  //   final Completer<Size> completer = Completer();
  //   final Image image = Image.network(imageUrl);

  //   image.image.resolve(const ImageConfiguration()).addListener(
  //         ImageStreamListener(
  //           (ImageInfo info, bool _) {
  //             completer.complete(Size(
  //               info.image.width.toDouble(),
  //               info.image.height.toDouble(),
  //             ));
  //           },
  //           onError: (dynamic exception, StackTrace? stackTrace) {
  //             completer.completeError(exception);
  //           },
  //         ),
  //       );

  //   return completer.future;
  // }

  Widget _buildPostImages(PublicPostModel post) {
    if (post.imageUrl == null || post.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: FutureBuilder<Size>(
        future: _getImageDimensions(post.imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.error_outline, size: 40, color: Colors.grey),
              ),
            );
          }

          double screenWidth = MediaQuery.of(context).size.width - 20;
          double imageRatio = snapshot.data!.width / snapshot.data!.height;
          double displayHeight = screenWidth / imageRatio;

          return GestureDetector(
            onTap: () => _showZoomableImage(context, post.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                width: screenWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: screenWidth,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error_outline,
                          size: 40, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String imageUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // اضافه کردن دکمه دانلود
              // Positioned(
              //   top: MediaQuery.of(context).padding.top + 10,
              //   left: 10,
              //   child: IconButton(
              //     icon: const Icon(
              //       Icons.download,
              //       color: Colors.white,
              //       size: 30,
              //     ),
              //     onPressed: () {
              //       // اینجا کد دانلود عکس را اضافه کنید
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //           content: Text('دانلود تصویر شروع شد'),
              //           duration: Duration(seconds: 2),
              //         ),
              //       );
              //     },
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Size> _getImageDimensions(String imageUrl) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.network(imageUrl);

    image.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              completer.complete(Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              ));
            },
            onError: (dynamic exception, StackTrace? stackTrace) {
              completer.completeError(exception);
            },
          ),
        );

    return completer.future;
  }

  // void _showImageDialog(BuildContext context, String imageUrl) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return Dialog(
  //         backgroundColor: Colors.transparent,
  //         child: Stack(
  //           alignment: Alignment.center,
  //           children: [
  //             InteractiveViewer(
  //               panEnabled: true,
  //               boundaryMargin: const EdgeInsets.all(20),
  //               minScale: 0.5,
  //               maxScale: 4,
  //               child: Image.network(
  //                 imageUrl,
  //                 fit: BoxFit.contain,
  //                 errorBuilder: (context, error, stackTrace) {
  //                   return Container(
  //                     color: Colors.grey[300],
  //                     child: const Center(
  //                       child: Icon(Icons.error_outline,
  //                           size: 50, color: Colors.white),
  //                     ),
  //                   );
  //                 },
  //               ),
  //             ),
  //             Positioned(
  //               top: 0,
  //               right: 0,
  //               child: Material(
  //                 color: Colors.transparent,
  //                 child: IconButton(
  //                   icon:
  //                       const Icon(Icons.close, color: Colors.white, size: 30),
  //                   onPressed: () => Navigator.of(context).pop(),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showImageDialog(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMultipleImages(List<String> images) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Container(
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => _showImageDialog(context, images[index]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostDetails(BuildContext context, dynamic post) {
    final jalaliDate = Jalali.fromDateTime(post.createdAt.toLocal());
    final formattedDate =
        '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostCard(post, formattedDate),
          const SizedBox(height: 16),
          _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post, String formattedDate) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(post.content, style: const TextStyle(fontSize: 18)),
            ),
            _buildPostImages(post), // اضافه کردن این خط
            const SizedBox(height: 10),
            _buildLikeRow(post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(dynamic post) {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: post.avatarUrl.isEmpty
              ? const AssetImage('lib/util/images/default-avatar.jpg')
              : NetworkImage(post.avatarUrl) as ImageProvider<Object>?,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 5),
                if (post.isVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
              ],
            ),
            Text(
              _formatDate(post.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final jalaliDate = Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  Widget _buildLikeRow(dynamic post) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : null,
          ),
          onPressed: () async {
            setState(() {
              post.isLiked = !post.isLiked;
              post.likeCount += post.isLiked ? 1 : -1;
            });
            await ref.read(supabaseServiceProvider).toggleLike(
                  postId: post.id,
                  ownerId: post.userId,
                  ref: ref,
                );
          },
        ),
        Text('${post.likeCount}'),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final commentsAsyncValue = ref.watch(commentsProvider(widget.postId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'نظرات:',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: Colors.grey, height: 1, endIndent: 75, indent: 25),
        const SizedBox(height: 10),
        commentsAsyncValue.when(
          data: (comments) => comments.isEmpty
              ? const Center(child: Text('هنوز کامنتی وجود ندارد'))
              : _buildCommentTree(comments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('خطا در بارگذاری کامنت‌ها: $error')),
        ),
      ],
    );
  }

  Widget _buildCommentTree(List<CommentModel> comments) {
    // ساختاردهی ریپلای‌ها در نقشه
    Map<String, CommentModel> commentMap = {
      for (var comment in comments) comment.id: comment
    };

    for (var comment in comments) {
      if (comment.parentCommentId != null) {
        var parent = commentMap[comment.parentCommentId!];
        if (parent != null) {
          parent.replies.add(comment);
        }
      }
    }

    // فقط کامنت‌های والد را نمایش دهید
    return Column(
      children: comments
          .where((comment) => comment.parentCommentId == null)
          .expand(_buildTree)
          .toList(),
    );
  }

  List<Widget> _buildTree(CommentModel comment) {
    return [
      _buildCommentItem(comment),
      if (comment.replies.isNotEmpty)
        ExpansionTile(
          title: Text(
            'نمایش ${comment.replies.length} پاسخ',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 13,
            ),
          ),
          children: comment.replies.expand(_buildTree).toList(),
        ),
    ];
  }

  Widget _buildCommentItem(CommentModel comment) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر کامنت
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: comment.avatarUrl.isEmpty
                      ? const AssetImage('lib/util/images/default-avatar.jpg')
                      : NetworkImage(comment.avatarUrl) as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (comment.isVerified)
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 16),
                        ],
                      ),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // آیکون‌های اکشن
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder: (context) => [
                    if (comment.userId != supabase.auth.currentUser?.id)
                      PopupMenuItem(
                        value: 'report',
                        child: const Row(
                          children: [
                            Icon(Icons.flag, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'گزارش',
                            ),
                          ],
                        ),
                        onTap: () {
                          _showReportDialog(context, ref, comment,
                              supabase.auth.currentUser!.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                      onTap: () {
                        _deleteComment(context, ref, comment.id, widget.postId);
                        // Navigator.of(context).pop();
                      },
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'reply') {
                      setState(() {
                        replyToCommentId = comment.id;
                      });
                    }
                  },
                ),
              ],
            ),

            // متن کامنت
            const SizedBox(height: 10),
            Directionality(
              textDirection: getDirectionality(comment.content),
              child: RichText(
                text: TextSpan(
                  children: _buildCommentTextSpans(
                      comment, theme.brightness == Brightness.dark),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // گزینه ریپلای
            TextButton(
              onPressed: () {
                setState(() {
                  replyToCommentId = comment.id;
                  commentController.text = '@${comment.username} ';
                  commentController.selection = TextSelection.fromPosition(
                    TextPosition(offset: commentController.text.length),
                  );
                });
              },
              child: const Text('پاسخ'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendComment() async {
    final content = commentController.text.trim();
    final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

    if (content.isNotEmpty) {
      try {
        await ref.read(commentNotifierProvider.notifier).addComment(
            postId: widget.postId,
            content: content,
            postOwnerId: supabase.auth.currentUser!.id,
            mentionedUserIds: mentionedUserIds,
            parentCommentId: replyToCommentId,
            ref: ref);
        commentController.clear();
        replyToCommentId = null;
        mentionedUsers.clear();
        ref.invalidate(commentsProvider(widget.postId));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال کامنت: $e')),
        );
      }
    }
  }

  Widget _buildCommentInputArea(
      BuildContext context, List<UserModel> mentionNotifier) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mentionNotifier.isNotEmpty)
                _buildMentionList(mentionNotifier),
              _buildTextField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentionList(List<UserModel> mentionNotifier) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mentionNotifier.length,
        itemBuilder: (context, index) {
          final user = mentionNotifier[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onMentionTap(user),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundImage: user.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(user.avatarUrl!) as ImageProvider
                      : const AssetImage('lib/util/images/default-avatar.jpg'),
                ),
                label: Text(user.username),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: commentController,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelText: 'کامنت خود را بنویسید...',
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          onPressed: _sendComment,
        ),
      ),
      onChanged: _onTextChanged,
    );
  }

  void _onTextChanged(String text) {
    // بررسی وجود @ در متن
    final atIndex = text.lastIndexOf('@');

    // اگر @ پیدا نشد یا بعد از آن کاراکتری وجود ندارد
    if (atIndex == -1 || atIndex == text.length - 1) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
      return;
    }

    // استخراج بخش مرتبط با منشن
    final mentionPart = text.substring(atIndex + 1);

    // اگر بخش منشن خالی است، لیست را پاک کنید
    if (mentionPart.trim().isEmpty) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
    } else {
      // جستجوی کاربران قابل منشن
      ref
          .read(mentionNotifierProvider.notifier)
          .searchMentionableUsers(mentionPart);
    }
  }

  void _onMentionTap(UserModel user) {
    final currentText = commentController.text;
    final mentionPart = currentText.split('@').last;
    final newText =
        currentText.replaceFirst('@$mentionPart', '@${user.username} ');

    commentController.text = newText;
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );

    if (!mentionedUsers.any((u) => u.id == user.id)) {
      mentionedUsers.add(user);
    }

    ref.read(mentionNotifierProvider.notifier).clearMentions();
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref,
    String commentId,
    String postId,
  ) async {
    try {
      await ref
          .read(commentNotifierProvider.notifier)
          .deleteComment(commentId, ref);
      ref.invalidate(commentsProvider(postId));

      // به دلیل زمان‌بری احتمالی async، از `mounted` برای چک وضعیت ویجت استفاده کنید
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کامنت با موفقیت حذف شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف کامنت: $e')),
        );
      }
    }
  }

  Future<void> _showReportDialog(BuildContext context, WidgetRef ref,
      CommentModel comment, String currentUserId) async {
    String selectedReason = '';
    TextEditingController additionalDetailsController = TextEditingController();

    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('گزارش تخلف'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('لطفاً دلیل گزارش را انتخاب کنید:'),
                    ...[
                      'محتوای نامناسب',
                      'هرزنگاری',
                      'توهین آمیز',
                      'اسپم',
                      'محتوای تبلیغاتی',
                      'سایر موارد'
                    ].map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) {
                          setState(() {
                            selectedReason = value!;
                          });
                        },
                      );
                    }),
                    if (selectedReason == 'سایر موارد')
                      TextField(
                        controller: additionalDetailsController,
                        decoration: const InputDecoration(
                          hintText: 'جزئیات بیشتر را وارد کنید',
                        ),
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyLarge?.color,
                  ),
                  child: const Text('لغو'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  child: const Text('گزارش'),
                  onPressed: () {
                    if (selectedReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لطفاً دلیل گزارش را انتخاب کنید'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref.read(reportCommentServiceProvider).reportComment(
              commentId: comment.id,
              reporterId: currentUserId,
              reason: selectedReason,
              additionalDetails: selectedReason == 'سایر موارد'
                  ? additionalDetailsController.text.trim()
                  : null,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کامنت با موفقیت گزارش شد.'),
          ),
        );
      } catch (e) {
        print('خطا در گزارش تخلف: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در گزارش کامنت.'),
          ),
        );
      }
    }
  }

  List<TextSpan> _buildCommentTextSpans(CommentModel comment, bool isDarkMode) {
    final List<TextSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');

    final matches = mentionRegex.allMatches(comment.content);
    int lastIndex = 0;

    for (final match in matches) {
      // متن قبل از منشن
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: comment.content.substring(lastIndex, match.start),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        );
      }

      // استایل منشن
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Colors.blue.shade400,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final username = match.group(1); // استخراج نام کاربری
              if (username != null) {
                // دریافت userId از پایگاه داده یا API بر اساس username
                final userId = await getUserIdByUsername(username);
                if (userId != null) {
                  // ناوبری به پروفایل کاربر
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        username: username,
                        userId: userId,
                      ),
                    ),
                  );
                }
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    // متن باقی مانده
    if (lastIndex < comment.content.length) {
      spans.add(
        TextSpan(
          text: comment.content.substring(lastIndex),
          style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87, fontSize: 15),
        ),
      );
    }

    return spans;
  }

// یک متد برای جلب userId از پایگاه داده بر اساس username
  Future<String?> getUserIdByUsername(String username) async {
    // فرض کنید از Supabase برای جلب userId استفاده می‌کنید
    final response = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();

    if (response['id'] != null) {
      return response['id'];
    } else {
      return null; // اگر کاربر یافت نشد
    }
  }

  TextDirection getDirectionality(String content) {
    return content.startsWith('@') ? TextDirection.ltr : TextDirection.rtl;
  }
}
