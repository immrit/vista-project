import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '/main.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import '../model/publicPostModel.dart';
import '../provider/provider.dart';
import '../view/screen/PublicPosts/profileScreen.dart';
import '../view/screen/support.dart';
import 'themes.dart';

class topText extends StatelessWidget {
  topText({
    super.key,
    required this.text,
  });

  String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 15),
        child: Text(
          text,
          style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

Widget CustomButtonWelcomePage(
    Color backgrundColor, String text, Color colorText, dynamic click) {
  return GestureDetector(
    onTap: click,
    child: Container(
      width: 180,
      height: 65,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25), color: backgrundColor),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
              color: colorText, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}

extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(textDirection: TextDirection.rtl, message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).snackBarTheme.backgroundColor,
      ),
    );
  }
}

Widget customTextField(String hintText, TextEditingController controller,
    dynamic validator, bool obscureText, TextInputType keyboardType) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              width: .7,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
  );
}

Widget customButton(dynamic ontap, String text, final WidgetRef ref) {
  final currentTheme = ref.watch(themeProvider); // دریافت تم جاری

  return GestureDetector(
    onTap: ontap,
    child: Container(
      width: 350,
      height: 50,
      decoration: BoxDecoration(
          color: currentTheme.brightness == Brightness.dark
              ? Colors.white
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(15)),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          textAlign: TextAlign.center,
          text,
          style: TextStyle(
            fontSize: 20,
            color: currentTheme.brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
      ),
    ),
  );
}

Widget ProfileFields(String name, IconData icon, dynamic onclick) {
  return GestureDetector(
    onTap: onclick,
    child: Column(
      children: [
        SizedBox(
            width: double.infinity,
            height: 45,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListTile(
                leading: Icon(
                  icon,
                ),
                title: Text(
                  name,
                ),
              ),
            )),
        const Divider(indent: 0, endIndent: 59),
      ],
    ),
  );
}

Widget addNotesTextFiels(
    String name,
    int lines,
    TextEditingController controller,
    double fontSize,
    FontWeight fontWeight,
    param5,
    {int? maxLength}) {
  return Container(
    padding: const EdgeInsets.all(20),
    child: Directionality(
      textDirection: getDirectionality(controller.text),
      child: TextField(
        maxLines: null, // تغییر از lines به null
        minLines: lines, // اضافه کردن این خط
        keyboardType: TextInputType.multiline, // اضافه کردن این خط
        textInputAction: TextInputAction.newline, // اضافه کردن این خط
        textAlign: getTextAlignment(controller.text),
        maxLength: maxLength,
        controller: controller,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        scrollPhysics: const NeverScrollableScrollPhysics(),
        decoration: InputDecoration(
            hintText: name,
            border: InputBorder.none,
            hintStyle: TextStyle(fontSize: 20.sp)),
      ),
    ),
  );
}

final picker = ImagePicker();

Future<void> uploadProfilePicture() async {
  // انتخاب عکس از گالری
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    File file = File(pickedFile.path);

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      // آپلود عکس به باکت
      final fileName = 'public/$userId/profile-pic.png';
      final response = await Supabase.instance.client.storage
          .from('user-profile-pics')
          .upload(fileName, file);

      print('خطا در آپلود عکس: $response');
    }
  }
}

//CustomDrawer

Drawer CustomDrawer(AsyncValue<Map<String, dynamic>?> getprofile,
    ThemeData currentcolor, BuildContext context, WidgetRef ref) {
  void saveThemeToHive(String theme) async {
    var box = Hive.box('settings');
    await box.put('selectedTheme', theme);

    final themeNotifier = ref.watch(themeProvider.notifier);
  }

  return Drawer(
    width: 0.6.sw,
    child: Column(
      children: <Widget>[
        DrawerHeader(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: getprofile.when(
              data: (getprofile) {
                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                      color: currentcolor.appBarTheme.backgroundColor),
                  currentAccountPicture: CircleAvatar(
                    radius: 30,
                    backgroundImage: getprofile!['avatar_url'] != null
                        ? NetworkImage(getprofile['avatar_url'].toString())
                        : const AssetImage(
                            'lib/util/images/default-avatar.jpg'),
                  ),
                  margin: const EdgeInsets.only(bottom: 0),
                  currentAccountPictureSize: const Size(65, 65),
                  accountName: Row(
                    children: [
                      Text(
                        '${getprofile['username']}',
                        style: TextStyle(
                            color: currentcolor.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      if (getprofile['is_verified'])
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 16),
                    ],
                  ),
                  accountEmail: Text("${supabase.auth.currentUser!.email}",
                      style: TextStyle(
                          color: currentcolor.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)),
                );
              },
              error: (error, stack) {
                final errorMsg = error.toString() == 'User is not logged in'
                    ? 'کاربر وارد سیستم نشده است، لطفاً ورود کنید.'
                    : 'خطا در دریافت اطلاعات کاربر، لطفاً دوباره تلاش کنید.';

                return Center(child: Text(errorMsg));
              },
              loading: () => const Center(child: CircularProgressIndicator())),
        ),
        SwitchListTile(
          title: const Text('حالت شب/روز'),
          value: ref.watch(themeProvider).brightness == Brightness.dark,
          onChanged: (bool isDark) {
            // تغییر تم
            final themeNotifier = ref.read(themeProvider.notifier);

            if (isDark) {
              themeNotifier.state = darkTheme;
              saveThemeToHive('dark');
            } else {
              themeNotifier.state = lightTheme;
              saveThemeToHive('light');
            }
          },
          secondary: Icon(
            ref.watch(themeProvider).brightness == Brightness.dark
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
          activeColor: Colors.black,
          activeTrackColor: Colors.white10,
        ),

        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text(
            'تنظیمات',
          ),
          onTap: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text(
            'پشتیبانی',
          ),
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SupportPage()));
          },
        ),
        // ListTile(
        //   leading: const Icon(Icons.person_add),
        //   title: const Text(
        //     'دعوت از دوستان',
        //   ),
        //   onTap: () {
        //     const String inviteText =
        //         'دوست عزیز سلام! من از ویستا نوت برای ذخیره یادداشت هام و ارتباط با کلی رفیق جدید استفاده میکنم! \n پیشنهاد میکنم همین الان از بازار نصبش کنی😉:  https://cafebazaar.ir/app/com.example.vista_notes2/ ';
        //     Share.share(inviteText);
        //   },
        // ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text(
            'خروج',
          ),
          onTap: () {
            supabase.auth.signOut();
            Navigator.pushReplacementNamed(context, '/welcome');
          },
        ),
      ],
    ),
  );
}

//report function

class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({super.key, required this.post});

  final PublicPostModel post;

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  // لیست دلایل گزارش
  final List<String> reportReasons = [
    'محتوای نامناسب',
    'هرزنگاری',
    'توهین آمیز',
    'اسپم',
    'محتوای تبلیغاتی',
    'سایر موارد'
  ];

  late TextEditingController _additionalDetailsController;
  // متغیرهای حالت
  String _selectedReason = '';

  @override
  void dispose() {
    _additionalDetailsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _additionalDetailsController = TextEditingController();
  }

  // متد ارسال گزارش
  void _submitReport() async {
    try {
      // دریافت سرویس سوپابیس از پرووایدر
      final supabaseService = ref.read(supabaseServiceProvider);

      // بررسی انتخاب دلیل
      if (_selectedReason.isEmpty) {
        _showSnackBar('لطفاً دلیل گزارش را انتخاب کنید', isError: true);
        return;
      }

      // ارسال گزارش
      await supabaseService.insertReport(
        postId: widget.post.id,
        reportedUserId: widget.post.userId,
        reason: _selectedReason,
        additionalDetails: _selectedReason == 'سایر موارد'
            ? _additionalDetailsController.text.trim()
            : null,
      );
      // بستن دیالوگ و نمایش پیام موفقیت
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('گزارش شما با موفقیت ثبت شد');
      }
    } catch (e) {
      // نمایش خطا
      if (mounted) {
        _showSnackBar('خطا در ثبت گزارش: $e', isError: true);
      }
    }
  }

  // متد نمایش اسنک بار
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        'گزارش پست',
        style: theme.textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'دلیل گزارش پست را انتخاب کنید:',
              style: theme.textTheme.bodyMedium,
            ),
            // لیست رادیویی دلایل گزارش
            ...reportReasons.map((reason) => RadioListTile<String>(
                  title: Text(
                    reason,
                    style: theme.textTheme.bodyMedium,
                  ),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value!;
                    });
                  },
                  activeColor: theme.colorScheme.secondary,
                )),

            // فیلد توضیحات اضافی برای 'سایر موارد'
            if (_selectedReason == 'سایر موارد')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: _additionalDetailsController,
                  decoration: InputDecoration(
                    hintText: 'جزئیات بیشتر را وارد کنید',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
      actions: [
        // دکمه انصراف
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),

        // دکمه ارسال گزارش
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
          ),
          onPressed: _selectedReason.isNotEmpty ? _submitReport : null,
          child: const Text('ثبت گزارش'),
        ),
      ],
    );
  }
}

//jeneral text field

bool isPersian(String text) {
  // بررسی می‌کند آیا متن دارای حروف فارسی است یا نه
  final RegExp persianRegExp = RegExp(r'[\u0600-\u06FF]');
  return persianRegExp.hasMatch(text);
}

TextAlign getTextAlignment(String text) {
  return isPersian(text) ? TextAlign.right : TextAlign.left;
}

TextDirection getDirectionality(String text) {
  return isPersian(text) ? TextDirection.rtl : TextDirection.ltr;
}

void showCommentsBottomSheet(
    BuildContext context, String postId, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CommentsBottomSheet(postId: postId),
  );
}

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentsBottomSheet({
    required this.postId,
    super.key,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController commentController = TextEditingController();
  String? replyToCommentId;
  List<UserModel> mentionedUsers = [];
  final String currentUserId = supabase.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildCommentsSection(),
                  ],
                ),
              ),
              SafeArea(
                child: _buildCommentInputArea(
                  context,
                  ref.watch(mentionNotifierProvider),
                ),
              ),
            ],
          ),
        );
      },
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
    // Create a map of comments for easier lookup
    Map<String, CommentModel> commentMap = {
      for (var comment in comments) comment.id: comment
    };

    // Build the reply tree structure
    List<CommentModel> rootComments = [];
    for (var comment in comments) {
      if (comment.parentCommentId == null) {
        rootComments.add(comment);
      } else {
        var parent = commentMap[comment.parentCommentId!];
        if (parent != null) {
          parent.replies.add(comment);
        }
      }
    }

    // Sort root comments by creation date (newest first)
    rootComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rootComments.length,
      itemBuilder: (context, index) {
        final rootComment = rootComments[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentItem(rootComment),
            if (rootComment.replies.isNotEmpty)
              _buildRepliesSection(rootComment.replies),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  Widget _buildRepliesSection(List<CommentModel> replies) {
    // Sort replies by creation date (oldest first)
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Container(
      margin: const EdgeInsets.only(left: 16), // تغییر مارجین به سمت راست
      padding: const EdgeInsets.only(left: 16), // اضافه کردن پدینگ
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            // تغییر بوردر به سمت راست
            color: Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: replies.map((reply) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommentItem(reply),
              if (reply.replies.isNotEmpty) _buildRepliesSection(reply.replies),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineComment(CommentModel comment, bool isRoot) {
    final theme = Theme.of(context);
    final timelineColor = theme.brightness == Brightness.dark
        ? Colors.grey[700]
        : Colors.grey[300];

    return TimelineTile(
      nodePosition: 0, // Changed from 0.1 to 0 to remove indentation
      node: TimelineNode(
        indicator: DotIndicator(
          color: timelineColor,
          size: 16, // Reduced size for better appearance
        ),
        startConnector: isRoot
            ? null
            : SolidLineConnector(
                color: timelineColor,
              ),
        endConnector: comment.replies.isEmpty
            ? null
            : SolidLineConnector(
                color: timelineColor,
              ),
      ),
      contents: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentItem(comment),
            if (comment.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  children: comment.replies
                      .map((reply) => _buildTimelineComment(reply, false))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 8.0, horizontal: 8.0), // کاهش پدینگ افقی
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: comment.avatarUrl.isEmpty
                    ? const AssetImage('lib/util/images/default-avatar.jpg')
                    : NetworkImage(comment.avatarUrl) as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (comment.isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified,
                                color: Colors.blue, size: 16),
                          ),
                        Text(
                          ' · ${formatDateTimeToJalali(comment.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        _buildCommentActions(comment),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Comment content
                    Directionality(
                      textDirection: getDirectionality(comment.content),
                      child: RichText(
                        text: TextSpan(
                          children: _buildCommentTextSpans(
                              comment, theme.brightness == Brightness.dark),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Interaction buttons
                    Row(
                      children: [
                        _buildInteractionButton(
                          icon: Icons.reply_outlined,
                          label: 'پاسخ',
                          onTap: () {
                            setState(() {
                              replyToCommentId = comment.id;
                              commentController.text = '@${comment.username} ';
                              commentController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: commentController.text.length),
                              );
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color ?? Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color ?? Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
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

  Widget _buildCommentActions(CommentModel comment) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (context) {
        return [
          if (comment.userId == currentUserId) ...[
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined),
                SizedBox(width: 8),
                Text('گزارش'),
              ],
            ),
          ),
        ];
      },
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('حذف نظر'),
                content: const Text('آیا از حذف این نظر مطمئن هستید؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف'),
                  ),
                  TextButton(
                    onPressed: () {
                      _deleteComment(context, ref, comment.id, widget.postId);
                      Navigator.pop(context, true);
                    },
                    child:
                        const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              // اینجا عملیات حذف کامنت انجام می‌شود
              // await deleteComment(comment.id);
            }
            break;
          case 'report':
            // اینجا عملیات گزارش کامنت انجام می‌شود
            break;
        }
      },
    );
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
                  backgroundImage: user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : const AssetImage('lib/util/images/default-avatar.jpg')
                          as ImageProvider,
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
    final atIndex = text.lastIndexOf('@');

    if (atIndex == -1 || atIndex == text.length - 1) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
      return;
    }

    final mentionPart = text.substring(atIndex + 1);

    if (mentionPart.trim().isEmpty) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
    } else {
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

      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Colors.blue.shade400,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final username = match.group(1);
              if (username != null) {
                final userId = await getUserIdByUsername(username);
                if (userId != null) {
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

  Future<String?> getUserIdByUsername(String username) async {
    final response = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();

    if (response['id'] != null) {
      return response['id'];
    } else {
      return null;
    }
  }

  TextDirection getDirectionality(String content) {
    return content.startsWith('@') ? TextDirection.ltr : TextDirection.rtl;
  }

  String formatDateTimeToJalali(DateTime dateTime) {
    final gregorian = Gregorian.fromDateTime(dateTime);
    final jalali = gregorian.toJalali();

    // Get current time
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // If less than 24 hours
    if (difference.inHours < 24) {
      if (difference.inMinutes < 1) {
        return 'همین الان';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} دقیقه پیش';
      } else {
        return '${difference.inHours} ساعت پیش';
      }
    }
    // If less than 7 days
    else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    }
    // If in current year
    else {
      String month = persianMonth(jalali.month);
      String hour = dateTime.hour.toString().padLeft(2, '0');
      String minute = dateTime.minute.toString().padLeft(2, '0');

      return '${jalali.day} $month${now.year != dateTime.year ? ' ${jalali.year}' : ''} • $hour:$minute';
    }
  }

  String persianMonth(int month) {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند'
    ];
    return months[month - 1];
  }
  // String _formatDate(DateTime date) {
  //   return DateFormat('yyyy/MM/dd HH:mm').format(date);
  // }
}

//report profile dialog
class ReportProfileDialog extends StatefulWidget {
  const ReportProfileDialog({super.key, required this.userId});

  final String userId; // شناسه پروفایل کاربری که قرار است گزارش شود

  @override
  _ReportProfileDialogState createState() => _ReportProfileDialogState();
}

class _ReportProfileDialogState extends State<ReportProfileDialog> {
  TextEditingController additionalDetailsController = TextEditingController();
  final List<String> reportReasons = [
    'محتوای نامناسب',
    'هرزنگاری',
    'توهین آمیز',
    'اسپم',
    'محتوای تبلیغاتی',
    'سایر موارد',
  ];

  String selectedReason = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('گزارش تخلف'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لطفاً دلیل گزارش را انتخاب کنید:'),
            ...reportReasons.map((reason) {
              return RadioListTile<String>(
                title: Text(reason),
                value: reason,
                groupValue: selectedReason,
                onChanged: (String? value) {
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
          child: const Text('لغو'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        Consumer(
          builder: (context, ref, child) => TextButton(
            child: const Text('گزارش'),
            onPressed: () async {
              if (selectedReason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لطفاً دلیل گزارش را انتخاب کنید'),
                  ),
                );
                return;
              }

              try {
                await ref.read(reportProfileServiceProvider).reportProfile(
                      userId: widget.userId,
                      reporterId: ref.read(authProvider)?.id ?? '',
                      reason: selectedReason,
                      additionalDetails:
                          additionalDetailsController.text.isEmpty
                              ? null
                              : additionalDetailsController.text,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('پروفایل با موفقیت گزارش شد.'),
                  ),
                );
              } catch (e) {
                print('خطا در گزارش پروفایل: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('خطا در گزارش پروفایل.'),
                  ),
                );
              }

              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}

class PostImageViewer extends StatelessWidget {
  final String imageUrl;

  const PostImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: MediaQuery.of(context).size.width,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: imageUrl,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HashtagText extends StatelessWidget {
  final String text;
  final Function(String) onHashtagTap;

  const HashtagText({
    super.key,
    required this.text,
    required this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    List<TextSpan> textSpans = [];

    // جداسازی کلمات متن
    final words = text.split(' ');

    for (var word in words) {
      if (word.startsWith('#')) {
        // اگر کلمه با # شروع شود، آن را به عنوان هشتگ قابل کلیک می‌سازیم
        textSpans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => onHashtagTap(word),
          ),
        );
      } else {
        // کلمات معمولی
        textSpans.add(TextSpan(text: '$word '));
      }
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: textSpans,
      ),
    );
  }
}

class HashtagExtractor {
  static List<String> extractHashtags(String text) {
    final hashtagRegExp = RegExp(r'#\w+');
    return hashtagRegExp
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }
}
