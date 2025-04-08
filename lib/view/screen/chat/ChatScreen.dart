import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../model/message_model.dart';
import '../../../provider/Chat_provider.dart.dart';

import '../../util/time_utils.dart';
import '/main.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  bool _isDisposed = false;
  final FocusNode _messageFocusNode = FocusNode(); // اضافه کردن FocusNode

  bool _showEmojiPicker = false;
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());

    // علامت‌گذاری مکالمه به عنوان خوانده شده
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(messageNotifierProvider.notifier)
          .markAsRead(widget.conversationId);

      // به‌روزرسانی وضعیت آنلاین کاربر فعلی
      ref.read(userOnlineNotifierProvider).updateOnlineStatus();

      // لاگ وضعیت آنلاین
      _checkOnlineStatus();
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;

    if (selection.baseOffset == -1) {
      _messageController.text = text + emoji.emoji;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length + emoji.emoji.length),
      );
    } else {
      final newText = text.replaceRange(
        selection.baseOffset,
        selection.extentOffset,
        emoji.emoji,
      );
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.baseOffset + emoji.emoji.length),
      );
    }
  }

  // اضافه کردن متد برای تغییر وضعیت نمایش ایموجی پیکر
  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

// تابع برای تست وضعیت آنلاین
  Future<void> _checkOnlineStatus() async {
    final chatService = ref.read(chatServiceProvider);
    final isOnline = await chatService.isUserOnline(widget.otherUserId);
    final lastOnline = await chatService.getUserLastOnline(widget.otherUserId);

    print('====== تست وضعیت آنلاین ======');
    print('کاربر: ${widget.otherUserName}');
    print('آنلاین است: $isOnline');
    print('آخرین فعالیت: $lastOnline');
    print('==============================');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose(); // اضافه کردن dispose برای FocusNode
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File file) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final fileName =
          '${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response = await supabase.storage
          .from('chat_attachments')
          .upload(fileName, file);

      final imageUrl =
          supabase.storage.from('chat_attachments').getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در آپلود تصویر: $e')),
      );
      return null;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _sendMessage() async {
    if (!mounted) return;

    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null) return;

    _messageController.clear();

    String? attachmentUrl;
    String? attachmentType;

    // اگر تصویری انتخاب شده باشد
    if (_selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        attachmentUrl = await _uploadImage(_selectedImage!);
        attachmentType = 'image';
      } catch (e) {
        print('خطا در آپلود تصویر: $e');
      } finally {
        if (mounted) {
          setState(() {
            _selectedImage = null;
            _isUploading = false;
          });
        }
      }

      if (!mounted) return;
    }

    // ارسال پیام با استفاده از SafeMessageHandler
    try {
      final handler = ref.read(safeMessageHandlerProvider);
      handler.sendMessage(
        conversationId: widget.conversationId,
        content: message,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      // اسکرول به پایین
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پیام: $e')),
        );
      }
    }
  }

  void _showSearchDialog(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
        title: Text(
          'جستجو در گفتگو',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              onChanged: (value) {
                searchQuery = value;
              },
              decoration: InputDecoration(
                hintText: 'متن مورد نظر را وارد کنید...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: isLightMode ? Colors.grey[100] : Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                if (searchQuery.isNotEmpty) {
                  Navigator.pop(context);
                  _searchInMessages(searchQuery);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: isLightMode ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (searchQuery.isNotEmpty) {
                _searchInMessages(searchQuery);
              }
            },
            child: Text(
              'جستجو',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _searchInMessages(String query) {
    // نمایش پیغام در حال جستجو
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('در حال جستجوی "$query"...'),
        duration: Duration(seconds: 1),
      ),
    );

    // در اینجا، می‌توانید کد مربوط به جستجو در پیام‌ها را پیاده‌سازی کنید
    // مثلاً می‌توانید از پرووایدر messagesProvider استفاده کنید و پیام‌ها را فیلتر کنید

    // نمونه کد برای پیاده‌سازی در آینده:
    // final messages = ref.read(messagesProvider(widget.conversationId)).value ?? [];
    // final filteredMessages = messages.where((msg) => msg.content.contains(query)).toList();

    // اگر پیامی یافت شد، به آن اسکرول کنید
    // if (filteredMessages.isNotEmpty) {
    //   _scrollToMessage(filteredMessages.first);
    // }
  }

  void _showBlockUserDialog(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
        title: Text(
          'مسدود کردن کاربر',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
          ),
        ),
        content: Text(
          'آیا از مسدود کردن ${widget.otherUserName} اطمینان دارید؟ این کاربر دیگر قادر به ارسال پیام به شما نخواهد بود.',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: isLightMode ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // بلاک کردن کاربر با استفاده از نوتیفایر
              ref
                  .read(userBlockNotifierProvider.notifier)
                  .blockUser(widget.otherUserId)
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.otherUserName} مسدود شد'),
                    action: SnackBarAction(
                      label: 'لغو',
                      onPressed: () {
                        // لغو بلاک
                        ref
                            .read(userBlockNotifierProvider.notifier)
                            .unblockUser(widget.otherUserId);
                      },
                    ),
                  ),
                );

                // بازگشت به صفحه مکالمات
                Navigator.pop(context);
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در مسدود کردن کاربر: $error')),
                );
              });
            },
            child: Text(
              'مسدود کردن',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final reportReasonController = TextEditingController();
    String selectedReason = 'محتوای نامناسب';

    final reportReasons = [
      'محتوای نامناسب',
      'آزار و اذیت',
      'اسپم',
      'جعل هویت',
      'سایر موارد'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
          title: Text(
            'گزارش کاربر',
            style: TextStyle(
              color: isLightMode ? Colors.black87 : Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دلیل گزارش:',
                style: TextStyle(
                  color: isLightMode ? Colors.black87 : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              // لیست دلایل گزارش
              Container(
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.grey[100] : Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: isLightMode ? Colors.white : Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  style: TextStyle(
                    color: isLightMode ? Colors.black87 : Colors.white,
                  ),
                  items: reportReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedReason = value;
                      });
                    }
                  },
                ),
              ),

              SizedBox(height: 16),
              Text(
                'توضیحات بیشتر:',
                style: TextStyle(
                  color: isLightMode ? Colors.black87 : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: reportReasonController,
                decoration: InputDecoration(
                  hintText: 'توضیحات اختیاری...',
                  filled: true,
                  fillColor: isLightMode ? Colors.grey[100] : Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  color: isLightMode ? Colors.black87 : Colors.white,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'انصراف',
                style: TextStyle(
                  color: isLightMode ? Colors.grey[800] : Colors.grey[300],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final additionalInfo = reportReasonController.text.trim();
                Navigator.pop(context);

                // ارسال گزارش با استفاده از نوتیفایر
                ref
                    .read(userReportNotifierProvider.notifier)
                    .reportUser(
                      userId: widget.otherUserId,
                      reason: selectedReason,
                      additionalInfo:
                          additionalInfo.isEmpty ? null : additionalInfo,
                    )
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('گزارش شما با موفقیت ارسال شد')),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در ارسال گزارش: $error')),
                  );
                });
              },
              child: Text(
                'ارسال گزارش',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    // تبدیل به زمان محلی (تهران)
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = lastSeen.toUtc().add(tehranOffset);
    final now = DateTime.now();
    final difference = now.difference(tehranTime);

    // امروز، فقط ساعت نمایش داده شود
    if (difference.inDays == 0) {
      return 'امروز ${DateFormat('HH:mm').format(tehranTime)}';
    }
    // دیروز
    else if (difference.inDays == 1) {
      return 'دیروز ${DateFormat('HH:mm').format(tehranTime)}';
    }
    // کمتر از یک هفته
    else if (difference.inDays < 7) {
      final weekday = _getDayOfWeekInPersian(tehranTime.weekday);
      return '$weekday ${DateFormat('HH:mm').format(tehranTime)}';
    }
    // بیشتر از یک هفته
    else {
      return DateFormat('yyyy/MM/dd - HH:mm').format(tehranTime);
    }
  }

// تبدیل شماره روز هفته به نام فارسی
  String _getDayOfWeekInPersian(int weekday) {
    switch (weekday) {
      case 1:
        return 'دوشنبه';
      case 2:
        return 'سه‌شنبه';
      case 3:
        return 'چهارشنبه';
      case 4:
        return 'پنج‌شنبه';
      case 5:
        return 'جمعه';
      case 6:
        return 'شنبه';
      case 7:
        return 'یکشنبه';
      default:
        return '';
    }
  }

  // void _showDeleteConfirmation(BuildContext context) {
  //   final isLightMode = Theme.of(context).brightness == Brightness.light;
  //   bool bothSides = false;

  //   showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setState) {
  //         return AlertDialog(
  //           backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
  //           title: Text(
  //             'پاکسازی تاریخچه گفتگو',
  //             style: TextStyle(
  //               color: isLightMode ? Colors.black87 : Colors.white,
  //             ),
  //           ),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'آیا مطمئن هستید که می‌خواهید تاریخچه گفتگو با ${otherUserName} را پاک کنید؟ این عمل قابل بازگشت نیست.',
  //                 style: TextStyle(
  //                   color: isLightMode ? Colors.black87 : Colors.white70,
  //                 ),
  //               ),
  //               SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   Checkbox(
  //                     value: bothSides,
  //                     activeColor: Theme.of(context).colorScheme.primary,
  //                     onChanged: (value) {
  //                       setState(() {
  //                         bothSides = value ?? false;
  //                       });
  //                     },
  //                   ),
  //                   Expanded(
  //                     child: Text(
  //                       'پاکسازی دوطرفه (برای هر دو کاربر)',
  //                       style: TextStyle(
  //                         color: isLightMode ? Colors.black87 : Colors.white70,
  //                         fontSize: 14,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               if (bothSides)
  //                 Container(
  //                   padding: EdgeInsets.all(8),
  //                   margin: EdgeInsets.only(top: 8),
  //                   decoration: BoxDecoration(
  //                     color: Colors.red.withOpacity(0.1),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(Icons.warning, color: Colors.red, size: 16),
  //                       SizedBox(width: 8),
  //                       Expanded(
  //                         child: Text(
  //                           'در این حالت، پیام‌ها برای هر دو طرف حذف می‌شوند!',
  //                           style: TextStyle(
  //                             color: Colors.red,
  //                             fontSize: 12,
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: Text(
  //                 'انصراف',
  //                 style: TextStyle(
  //                   color: isLightMode ? Colors.grey[800] : Colors.grey[300],
  //                 ),
  //               ),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(context);

  //                 // نمایش loading snackbar
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   SnackBar(
  //                     content: Row(
  //                       children: [
  //                         SizedBox(
  //                           width: 20,
  //                           height: 20,
  //                           child: CircularProgressIndicator(
  //                             strokeWidth: 2,
  //                             valueColor:
  //                                 AlwaysStoppedAnimation<Color>(Colors.white),
  //                           ),
  //                         ),
  //                         SizedBox(width: 12),
  //                         Text('در حال پاکسازی گفتگو...'),
  //                       ],
  //                     ),
  //                     duration: Duration(seconds: 1),
  //                   ),
  //                 );

  //                 // استفاده از Consumer برای دسترسی به ref
  //                 final consumer =
  //                     context.findAncestorWidgetOfExactType<ConsumerWidget>();
  //                 if (consumer != null) {
  //                   final provider = ProviderScope.containerOf(context)
  //                       .read(messageNotifierProvider.notifier);
  //                   provider
  //                       .clearConversation(conversationId, bothSides: bothSides)
  //                       .then((_) {
  //                     // نمایش پیام موفقیت آمیز
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: Text('تاریخچه گفتگو پاک شد'),
  //                         backgroundColor: Colors.green,
  //                       ),
  //                     );

  //                     // بازگشت به صفحه قبل
  //                     Navigator.of(context).pop();
  //                   }).catchError((error) {
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: Text('خطا در پاکسازی گفتگو: $error'),
  //                         backgroundColor: Colors.red,
  //                       ),
  //                     );
  //                   });
  //                 }
  //               },
  //               child: Text(
  //                 'پاکسازی',
  //                 style: TextStyle(color: Colors.red),
  //               ),
  //             ),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  // }

  void _showDeleteMessageDialog(BuildContext context, MessageModel message) {
    final isMe = message.senderId == supabase.auth.currentUser!.id;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    // اگر پیام متعلق به کاربر دیگر باشد، امکان حذف وجود ندارد
    if (!isMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فقط پیام‌های خودتان را می‌توانید حذف کنید'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool forEveryone = false;

          return AlertDialog(
            backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
            title: Text(
              'حذف پیام',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آیا مطمئن هستید که می‌خواهید این پیام را حذف کنید؟',
                  style: TextStyle(
                    color: isLightMode ? Colors.black87 : Colors.white70,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: forEveryone,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          forEveryone = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'حذف برای همه',
                        style: TextStyle(
                          color: isLightMode ? Colors.black87 : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                if (forEveryone)
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'در این حالت، پیام برای هر دو طرف حذف می‌شود!',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'انصراف',
                  style: TextStyle(
                    color: isLightMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);

                  // نمایش loading snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('در حال حذف پیام...'),
                        ],
                      ),
                      duration: Duration(milliseconds: 500),
                    ),
                  );

                  ref
                      .read(messageNotifierProvider.notifier)
                      .deleteMessage(message.id, forEveryone: forEveryone)
                      .then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('پیام حذف شد'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطا در حذف پیام: $error'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                },
                child: Text(
                  'حذف',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // پاکسازی تاریخچه گفتگو با نمایش دیالوگ تایید
  void _showClearConversationDialog(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    bool bothSides = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
          title: Text(
            'پاکسازی تاریخچه گفتگو',
            style: TextStyle(
              color: isLightMode ? Colors.black87 : Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'آیا مطمئن هستید که می‌خواهید تاریخچه گفتگو با ${widget.otherUserName} را پاک کنید؟ این عمل قابل بازگشت نیست.',
                style: TextStyle(
                  color: isLightMode ? Colors.black87 : Colors.white70,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: bothSides,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) {
                      setState(() {
                        bothSides = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'پاکسازی دوطرفه (برای هر دو کاربر)',
                      style: TextStyle(
                        color: isLightMode ? Colors.black87 : Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (bothSides)
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'در این حالت، پیام‌ها برای هر دو طرف حذف می‌شوند!',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'انصراف',
                style: TextStyle(
                  color: isLightMode ? Colors.grey[800] : Colors.grey[300],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                // نمایش loading snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('در حال پاکسازی گفتگو...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );

                // پاکسازی گفتگو
                ref
                    .read(messageNotifierProvider.notifier)
                    .clearConversation(widget.conversationId,
                        bothSides: bothSides)
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تاریخچه گفتگو پاک شد'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  // بروزرسانی لیست پیام‌ها
                  ref.invalidate(messagesStreamProvider(widget.conversationId));
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطا در پاکسازی گفتگو: $error'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                });
              },
              child: Text(
                'پاکسازی',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));

    // اضافه کردن متغیر برای تشخیص نمایش کیبورد
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    // اگر کیبورد باز است و ایموجی پیکر هم باز است، ایموجی پیکر را ببند
    if (isKeyboardVisible && _showEmojiPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showEmojiPicker = false;
        });
      });
    }
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          elevation: 1,
          titleSpacing: 0,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1A1A1A)
              : Colors.white,
          iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
          title: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.otherUserId}',
                child: Material(
                  type: MaterialType.transparency,
                  child: GestureDetector(
                    onTap: () {
                      // نمایش تصویر پروفایل در اندازه بزرگ
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.otherUserAvatar ?? '',
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                          'assets/images/default_avatar.png'),
                                  height: 250,
                                  width: 250,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text('بستن',
                                      style: TextStyle(color: Colors.black87)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.otherUserAvatar != null &&
                              widget.otherUserAvatar!.isNotEmpty
                          ? NetworkImage(widget.otherUserAvatar!)
                          : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final isOnlineAsync = ref.watch(
                            userOnlineStatusStreamProvider(widget.otherUserId));

                        return isOnlineAsync.when(
                          data: (isOnline) {
                            if (isOnline) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'آنلاین',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              final lastOnlineAsync = ref.watch(
                                  userLastOnlineProvider(widget.otherUserId));
                              return lastOnlineAsync.when(
                                data: (lastOnline) {
                                  return Text(
                                    lastOnline != null
                                        ? TimeUtils.formatLastSeen(lastOnline)
                                        : 'آفلاین',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  );
                                },
                                loading: () => Text('در حال بارگذاری...',
                                    style: TextStyle(fontSize: 12)),
                                error: (_, __) => Text('آفلاین',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              );
                            }
                          },
                          loading: () => Text('در حال بارگذاری...',
                              style: TextStyle(fontSize: 12)),
                          error: (error, _) {
                            print('خطا در دریافت وضعیت آنلاین: $error');
                            return Text('آفلاین',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey));
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // دکمه پاکسازی گفتگو
            IconButton(
              icon: Icon(Icons.delete_outline),
              tooltip: 'پاکسازی تاریخچه گفتگو',
              onPressed: () => _showClearConversationDialog(context),
            ),
            // منوی بیشتر
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              tooltip: 'گزینه‌های بیشتر',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'search':
                    _showSearchDialog(context);
                    break;
                  case 'block':
                    _showBlockUserDialog(context);
                    break;
                  case 'report':
                    _showReportUserDialog(context);
                    break;
                  case 'profile':
                    // نمایش پروفایل کاربر
                    Navigator.pushNamed(context, '/profile',
                        arguments: {'userId': widget.otherUserId});
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87),
                      SizedBox(width: 12),
                      Text('جستجو در پیام‌ها'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87),
                      SizedBox(width: 12),
                      Text('مشاهده پروفایل'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87),
                      SizedBox(width: 12),
                      Text('مسدود کردن'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_problem_outlined,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87),
                      SizedBox(width: 12),
                      Text('گزارش کاربر'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // پیام‌ها
            Expanded(
              child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child:
                            Text('پیامی وجود ندارد. اولین پیام را ارسال کنید!'),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe =
                            message.senderId == supabase.auth.currentUser!.id;

                        return _buildMessageItem(context, message, isMe);
                      },
                    );
                  },
                  loading: () => Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: Theme.of(context).primaryColor,
                          size: 50,
                        ),
                      ),
                  error: (error, stack) {
                    print(error);
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text('خطا: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.refresh(
                                messagesProvider(widget.conversationId)),
                            child: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    );
                  }),
            ),

            // نمایش تصویر انتخاب شده
            if (_selectedImage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.grey[200],
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // بخش نوشتن پیام
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1A1A1A)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black38
                        : Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ردیف دکمه‌ها و فیلد متن
                  // ردیف ارسال پیام
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // دکمه انتخاب تصویر
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF292929)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: Icon(
                            Icons.photo_library_outlined,
                            color: _isUploading
                                ? Theme.of(context).disabledColor
                                : Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          onPressed: _isUploading ? null : _pickImage,
                          splashRadius: 24,
                        ),
                      ),

                      // دکمه ایموجی
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF292929)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: _showEmojiPicker
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[200]
                                    : Colors.black54,
                            size: 24,
                          ),
                          onPressed: _toggleEmojiPicker,
                          splashRadius: 24,
                        ),
                      ),

                      // فیلد متن
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF2D2D2D)
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            scrollController: _scrollController,
                            focusNode: _messageFocusNode, // اضافه کردن این خط

                            decoration: InputDecoration(
                              hintText: 'پیام خود را بنویسید...',
                              hintStyle: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 15,
                            ),
                            maxLines: 5,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() {
                                  _showEmojiPicker = false;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      // دکمه ارسال
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF2D2D2D)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.send_rounded,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[200]
                                      : Colors.black,
                                ),
                                onPressed: _sendMessage,
                                splashRadius: 24,
                              ),
                      ),
                    ],
                  ),

                  // نمایش ایموجی پیکر
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          try {
                            final text = _messageController.text;
                            final selection = _messageController.selection;

                            final newText = text.replaceRange(
                              selection.baseOffset,
                              selection.extentOffset,
                              emoji.emoji,
                            );

                            _messageController.text = newText;
                            _messageController.selection =
                                TextSelection.collapsed(
                              offset: selection.baseOffset + emoji.emoji.length,
                            );
                          } catch (e) {
                            print('خطا در افزودن ایموجی: $e');
                          }
                        },
                        scrollController: _scrollController,
                        config: Config(
                          height: 250,
                          checkPlatformCompatibility: true,
                          viewOrderConfig: const ViewOrderConfig(),
                          emojiViewConfig: EmojiViewConfig(
                            emojiSizeMax: 28 *
                                (foundation.defaultTargetPlatform ==
                                        TargetPlatform.iOS
                                    ? 1.2
                                    : 1.0),
                          ),
                          skinToneConfig: const SkinToneConfig(),
                          categoryViewConfig: const CategoryViewConfig(),
                          bottomActionBarConfig: const BottomActionBarConfig(),
                          searchViewConfig: const SearchViewConfig(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(
      BuildContext context, MessageModel message, bool isMe) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isLightMode ? Colors.white : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isLightMode ? Colors.grey[300] : Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (message.content.isNotEmpty)
                  _buildOptionItem(
                    context,
                    title: 'کپی متن',
                    icon: Icons.copy_outlined,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('متن پیام کپی شد'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                _buildOptionItem(
                  context,
                  title: 'پاسخ به پیام',
                  icon: Icons.reply,
                  onTap: () {
                    Navigator.pop(context);
                    // setState(() {
                    //   _replyingTo = message;
                    // });
                    FocusScope.of(context).requestFocus(_messageFocusNode);
                  },
                ),
                _buildOptionItem(
                  context,
                  title: 'پاکسازی تاریخچه گفتگو',
                  icon: Icons.delete_outline,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context);
                  },
                ),
                if (isMe)
                  _buildOptionItem(
                    context,
                    title: 'حذف پیام',
                    icon: Icons.delete_outline,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteMessageDialog(context, message);
                    },
                  ),
                if (!isMe)
                  _buildOptionItem(
                    context,
                    title: 'گزارش پیام',
                    icon: Icons.report_problem_outlined,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      // کد گزارش پیام
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('قابلیت گزارش پیام در حال پیاده‌سازی است'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
        title: Text(
          'پاکسازی تاریخچه گفتگو',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
          ),
        ),
        content: Text(
          'آیا از پاکسازی تمام پیام‌های این گفتگو اطمینان دارید؟ این عمل قابل بازگشت نیست.',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: isLightMode ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // پاکسازی تمام پیام‌های گفتگو
              ref
                  .read(messageNotifierProvider.notifier)
                  .deleteAllMessages(widget.conversationId)
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تاریخچه گفتگو پاکسازی شد'),
                  ),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطا در پاکسازی گفتگو: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            },
            child: Text(
              'پاکسازی',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

// متد کپی کردن متن پیام
  void _copyMessageToClipboard(BuildContext context, MessageModel message) {
    Clipboard.setData(ClipboardData(text: message.content)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('متن پیام کپی شد'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

// متد نمایش گزینه‌های حذف پیام
  void _showDeleteMessageConfirmation(
      BuildContext context, MessageModel message) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
        title: Text(
          'حذف پیام',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
          ),
        ),
        content: Text(
          'آیا از حذف این پیام اطمینان دارید؟',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: isLightMode ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // حذف پیام
              ref
                  .read(messageNotifierProvider.notifier)
                  .deleteMessage(message.id)
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('پیام حذف شد')),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در حذف پیام: $error')),
                );
              });
            },
            child: Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

// متد ساخت آیتم‌های منو
  Widget _buildOptionItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? (isLightMode ? Colors.red[50] : Color(0xFF3A1414))
                    : (isLightMode ? Colors.grey[100] : Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : (isLightMode ? Colors.grey[800] : Colors.grey[300]),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.red
                      : (isLightMode ? Colors.black87 : Colors.white),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(
      BuildContext context, MessageModel message, bool isMe) {
    final brightness = Theme.of(context).brightness;
    final isLightMode = brightness == Brightness.light;

    // رنگ‌های حباب پیام براساس حالت روشن/تاریک و فرستنده
    final myMessageColor = isLightMode
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary.withOpacity(0.8);

    final otherMessageColor =
        isLightMode ? Colors.grey[300] : Color(0xFF383838);

    // رنگ متن با کنتراست مناسب
    final myTextColor = isLightMode ? Colors.white : Colors.black;
    final otherTextColor = isLightMode ? Colors.black87 : Colors.white;

    // رنگ اطلاعات اضافی مثل ساعت پیام
    final myTimeColor = isLightMode ? Colors.white70 : Colors.black87;
    final otherTimeColor = isLightMode ? Colors.grey[700] : Colors.grey[300];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: GestureDetector(
          onLongPress: () {
            _showMessageOptions(context, message, isMe);
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              margin: EdgeInsets.zero,
              color: isMe ? myMessageColor : otherMessageColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                  bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                ),
              ),
              elevation: isLightMode ? 1 : 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // اگر پیام دارای پیوست است (مثلاً تصویر)
                    if (message.attachmentUrl != null &&
                        message.attachmentUrl!.isNotEmpty &&
                        message.attachmentType == 'image')
                      GestureDetector(
                        onTap: () {
                          // کد موجود برای نمایش تصویر
                        },
                        child: ClipRRect(
                            // کد موجود برای تصویر
                            ),
                      ),

                    // متن پیام (اگر موجود باشد)
                    if (message.content.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachmentUrl != null ? 8 : 0,
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? myTextColor : otherTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    // زمان پیام و وضعیت خوانده شدن
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? myTimeColor : otherTimeColor,
                            ),
                          ),
                          SizedBox(width: 4),
                          // وضعیت خوانده شدن (فقط برای پیام‌های من)
                          if (isMe)
                            Icon(
                              message.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.isRead
                                  ? Colors.green
                                  : (isMe ? myTimeColor : otherTimeColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays < 1) {
      // امروز: فقط زمان نمایش داده شود
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      // هفته اخیر: استفاده از timeago
      return timeago.format(time, locale: 'fa');
    } else {
      // بیش از یک هفته: تاریخ کامل
      return '${time.year}/${time.month}/${time.day}';
    }
  }
}

class ChatOptionsBottomSheet extends ConsumerWidget {
  final String otherUserId;
  final String otherUserName;
  final String conversationId;

  const ChatOptionsBottomSheet({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
    required this.conversationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isLightMode ? Colors.grey[300] : Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionItem(
              context,
              title: 'مشاهده پروفایل',
              icon: Icons.person_outline,
              onTap: () {
                Navigator.pop(context);
                // اینجا کد مربوط به نمایش پروفایل کاربر را قرار دهید
              },
            ),
            _buildOptionItem(
              context,
              title: 'جستجو در پیام‌ها',
              icon: Icons.search,
              onTap: () {
                Navigator.pop(context);
                // اینجا کد مربوط به جستجو در پیام‌ها را قرار دهید
              },
            ),
            _buildOptionItem(
              context,
              title: 'پاکسازی تاریخچه گفتگو',
              icon: Icons.delete_outline,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref);
              },
            ),
            _buildOptionItem(
              context,
              title: 'گزارش کاربر',
              icon: Icons.report_problem_outlined,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                // اینجا کد مربوط به گزارش کاربر را قرار دهید
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? (isLightMode ? Colors.red[50] : Color(0xFF3A1414))
                    : (isLightMode ? Colors.grey[100] : Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : (isLightMode ? Colors.grey[800] : Colors.grey[300]),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.red
                      : (isLightMode ? Colors.black87 : Colors.white),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    bool bothSides = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isLightMode ? Colors.white : Color(0xFF1A1A1A),
            title: Text(
              'پاکسازی تاریخچه گفتگو',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آیا مطمئن هستید که می‌خواهید تاریخچه گفتگو با $otherUserName را پاک کنید؟ این عمل قابل بازگشت نیست.',
                  style: TextStyle(
                    color: isLightMode ? Colors.black87 : Colors.white70,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: bothSides,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) {
                        setState(() {
                          bothSides = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'پاکسازی دوطرفه (برای هر دو کاربر)',
                        style: TextStyle(
                          color: isLightMode ? Colors.black87 : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (bothSides)
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'در این حالت، پیام‌ها برای هر دو طرف حذف می‌شوند!',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'انصراف',
                  style: TextStyle(
                    color: isLightMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);

                  // نمایش loading snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('در حال پاکسازی گفتگو...'),
                        ],
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  // اینجا عملیات حذف با استفاده از messageNotifierProvider انجام می‌شود
                  // ما باید این متد را در کلاس MessageNotifier پیاده‌سازی کنیم
                  ref
                      .read(messageNotifierProvider.notifier)
                      .deleteAllMessages(conversationId, forEveryone: bothSides)
                      .then((_) {
                    // نمایش پیام موفقیت‌آمیز
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تاریخچه گفتگو با موفقیت پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }).catchError((error) {
                    // نمایش خطا
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطا در پاکسازی گفتگو: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                },
                child: Text(
                  'پاکسازی',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
