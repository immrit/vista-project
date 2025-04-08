import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import '../../../model/message_model.dart';
import '../../../provider/Chat_provider.dart.dart';

import '../../Exeption/app_exceptions.dart';
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
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  MessageModel? _replyToMessage;
  // bool _isBlocked = false;
  bool _isCurrentUserBlocked = false;
  bool _isOtherUserBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userBlockStatusProvider(widget.otherUserId));
    });
    timeago.setLocaleMessages('fa', timeago.FaMessages());

    Future.microtask(() {
      ref
          .read(messageNotifierProvider.notifier)
          .markAsRead(widget.conversationId);
      ref.read(userOnlineNotifierProvider).updateOnlineStatus();
      _checkOnlineStatus();
    });
  }

  Future<void> _checkBlockStatus() async {
    try {
      final chatService = ref.read(chatServiceProvider);

      // بررسی آیا کاربر جاری کاربر مقابل را مسدود کرده است
      _isOtherUserBlocked = await chatService.isUserBlocked(widget.otherUserId);

      // بررسی آیا کاربر مقابل کاربر جاری را مسدود کرده است
      _isCurrentUserBlocked =
          await chatService.isCurrentUserBlockedBy(widget.otherUserId);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('خطا در بررسی وضعیت مسدودیت: $e');
    }
  }

  Widget _buildBlockedBanner() {
    if (_isCurrentUserBlocked) {
      return BlockedUserBanner(
        message:
            ' ارسال پیام مجاز نیست \n مسدود شده اید ${widget.otherUserName} شما توسط',
      );
    } else if (_isOtherUserBlocked) {
      return BlockedUserBanner(
        message: '  را مسدود کرده‌اید  ${widget.otherUserName} شما',
      );
    }
    return const SizedBox.shrink();
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

  void _toggleEmojiPicker() {
    if (_messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _showEmojiPicker = true);
        }
      });
    } else {
      setState(() => _showEmojiPicker = !_showEmojiPicker);
    }
  }

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
    _messageFocusNode.dispose();
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

  void _setReplyMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
      _messageFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _sendMessage() async {
    if (_isCurrentUserBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('شما مسدود شده‌اید و نمی‌توانید پیام ارسال کنید')),
      );
      return;
    }
    // بررسی وضعیت مسدودیت قبل از ارسال
    final chatService = ref.read(chatServiceProvider);
    final isCurrentUserBlocked =
        await chatService.isUserBlocked(widget.otherUserId);

    if (isCurrentUserBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'شما توسط ${widget.otherUserName} مسدود شده‌اید و نمی‌توانید پیام ارسال کنید')),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null) return;

    _messageController.clear();

    String? attachmentUrl;
    String? attachmentType;

    if (_selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        attachmentUrl = await _uploadImage(_selectedImage!);
        attachmentType = 'image';
      } catch (e) {
        String errorMessage = 'ارسال پیام ناموفق بود';
        if (e is AppException) {
          errorMessage = e.userFriendlyMessage;
        } else {
          errorMessage = 'خطای نامشخص. لطفاً دوباره امتحان کنید';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
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

    try {
      final handler = ref.read(safeMessageHandlerProvider);
      handler.sendMessage(
        conversationId: widget.conversationId,
        content: message,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        replyToMessageId: _replyToMessage?.id,
        replyToContent: _replyToMessage?.content,
        replyToSenderName: _replyToMessage?.senderName,
      );

      setState(() {
        _replyToMessage = null;
      });

      _messageController.clear();

      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      String errorMessage = 'خطای نامشخص';
      if (e is AppException) {
        errorMessage = e.userFriendlyMessage;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('در حال جستجوی "$query"...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showBlockUserDialog(BuildContext context) {
    final isBlocked = _isOtherUserBlocked;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBlocked
            ? 'رفع مسدودیت ${widget.otherUserName}'
            : 'مسدود کردن ${widget.otherUserName}'),
        content: Text(isBlocked
            ? 'آیا از رفع مسدودیت ${widget.otherUserName} اطمینان دارید؟'
            : 'آیا از مسدود کردن ${widget.otherUserName} اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final chatService = ref.read(chatServiceProvider);

                if (isBlocked) {
                  await chatService.unblockUser(widget.otherUserId);
                } else {
                  await chatService.blockUser(widget.otherUserId);
                }

                if (mounted) {
                  Navigator.pop(context);
                  await _checkBlockStatus(); // بررسی مجدد وضعیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isBlocked
                            ? '${widget.otherUserName} با موفقیت رفع مسدودیت شد'
                            : '${widget.otherUserName} با موفقیت مسدود شد')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isBlocked
                            ? 'خطا در رفع مسدودیت کاربر'
                            : 'خطا در مسدود کردن کاربر')),
                  );
                }
              }
            },
            child: Text(
              isBlocked ? 'رفع مسدودیت' : 'مسدود کردن',
              style: TextStyle(color: isBlocked ? Colors.green : Colors.red),
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
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = lastSeen.toUtc().add(tehranOffset);
    final now = DateTime.now();
    final difference = now.difference(tehranTime);

    if (difference.inDays == 0) {
      return 'امروز ${DateFormat('HH:mm').format(tehranTime)}';
    } else if (difference.inDays == 1) {
      return 'دیروز ${DateFormat('HH:mm').format(tehranTime)}';
    } else if (difference.inDays < 7) {
      final weekday = _getDayOfWeekInPersian(tehranTime.weekday);
      return '$weekday ${DateFormat('HH:mm').format(tehranTime)}';
    } else {
      return DateFormat('yyyy/MM/dd - HH:mm').format(tehranTime);
    }
  }

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

  void _showDeleteMessageDialog(BuildContext context, MessageModel message) {
    final isMe = message.senderId == supabase.auth.currentUser!.id;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

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
                    String errorMessage = 'خطا در حذف پیام';
                    if (error is AppException) {
                      errorMessage = error.userFriendlyMessage;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMessage)),
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

  void _showClearConversationDialog(BuildContext context) {
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

                  ref
                      .read(messageNotifierProvider.notifier)
                      .deleteAllMessages(widget.conversationId,
                          forEveryone: bothSides)
                      .then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تاریخچه گفتگو با موفقیت پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }).catchError((error) {
                    String errorMessage = 'خطا در پاکسازی گفتگو';
                    if (error is AppException) {
                      errorMessage = error.userFriendlyMessage;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMessage)),
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

  void _showUnblockUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رفع مسدودیت ${widget.otherUserName}'),
        content: Text(
            'آیا می‌خواهید ${widget.otherUserName} را از حالت مسدود خارج کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(userBlockNotifierProvider.notifier)
                    .unblockUser(widget.otherUserId);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${widget.otherUserName} رفع مسدود شد')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در رفع مسدودیت')),
                  );
                }
              }
            },
            child: Text('رفع مسدودیت', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (isKeyboardVisible && _showEmojiPicker) {
      _showEmojiPicker = false;
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
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey));
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
          IconButton(
            icon: Icon(Icons.delete_outline),
            tooltip: 'پاکسازی تاریخچه گفتگو',
            onPressed: () => _showClearConversationDialog(context),
          ),
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
                  _isOtherUserBlocked
                      ? _showUnblockUserDialog(context)
                      : _showBlockUserDialog(context);
                  break;
                case 'report':
                  _showReportUserDialog(context);
                  break;
                case 'profile':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                          userId: widget.otherUserId,
                          username: widget.otherUserName)));
                  break;
              }
            },
            itemBuilder: (context) => [
              // PopupMenuItem(
              //   value: 'search',
              //   child: Row(
              //     children: [
              //       Icon(Icons.search,
              //           color: Theme.of(context).brightness == Brightness.dark
              //               ? Colors.white70
              //               : Colors.black87),
              //       SizedBox(width: 12),
              //       Text('جستجو در پیام‌ها'),
              //     ],
              //   ),
              // ),
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
                    Icon(_isOtherUserBlocked ? Icons.lock_open : Icons.block,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87),
                    SizedBox(width: 12),
                    Text(_isOtherUserBlocked ? 'رفع مسدودیت' : 'مسدود کردن'),
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
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('پیامی وجود ندارد. اولین پیام را ارسال کنید!'),
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
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.signal_wifi_off,
                        color: Colors.grey,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'اتصال اینترنت برقرار نیست',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'پیام‌ها در حال حاضر قابل نمایش نیستند',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(
                            messagesStreamProvider(widget.conversationId)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('تلاش مجدد'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isCurrentUserBlocked || _isOtherUserBlocked)
            _buildBlockedBanner(),
          if (!_isCurrentUserBlocked && !_isOtherUserBlocked)
            _buildMessageInput(),
        ],
      ),
    ));
  }

  Widget _buildMessageInput() {
    // ابتدا وضعیت مسدودیت را بررسی کنید
    final isCurrentUserBlocked = ref
        .watch(
          userBlockStatusProvider(widget.otherUserId),
        )
        .maybeWhen(
          data: (isBlocked) => isBlocked,
          orElse: () => false,
        );

    final isOtherUserBlocked = ref
        .watch(
          userBlockStatusProvider(supabase.auth.currentUser!.id),
        )
        .maybeWhen(
          data: (isBlocked) => isBlocked,
          orElse: () => false,
        );

    // if (isCurrentUserBlocked || isOtherUserBlocked) {
    //   return BlockedUserBanner(
    //     isCurrentUserBlocked: isCurrentUserBlocked,
    //     userName: widget.otherUserName,
    //   );
    // }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // نمایش پیام در حال پاسخ
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'در پاسخ به ${_replyToMessage!.senderName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyToMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // دکمه انتخاب تصویر
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
              ),
              // دکمه ایموجی
              IconButton(
                onPressed: _toggleEmojiPicker,
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                ),
              ),
              // ورودی پیام
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'پیام خود را بنویسید...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[100]
                        : Colors.grey[800],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              // دکمه ارسال
              IconButton(
                onPressed: _isUploading ? null : _sendMessage,
                icon: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
          // نمایش تصویر انتخاب شده
          if (_selectedImage != null)
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
      BuildContext context, MessageModel message, bool isMe) {
    final brightness = Theme.of(context).brightness;
    final isLightMode = brightness == Brightness.light;

    final myMessageColor = isLightMode
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary.withOpacity(0.8);

    final otherMessageColor =
        isLightMode ? Colors.grey[300] : Color(0xFF383838);

    final myTextColor = isLightMode ? Colors.white : Colors.black;
    final otherTextColor = isLightMode ? Colors.black87 : Colors.white;

    final myTimeColor = isLightMode ? Colors.white70 : Colors.black87;
    final otherTimeColor = isLightMode ? Colors.grey[700] : Colors.grey[300];

    return Slidable(
      enabled: true,
      key: ValueKey(message.id),
      startActionPane: isMe
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _setReplyMessage(message),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.reply,
                  label: 'پاسخ',
                ),
              ],
            ),
      endActionPane: isMe
          ? ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _setReplyMessage(message),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.reply,
                  label: 'پاسخ',
                ),
              ],
            )
          : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: isMe ? myMessageColor : otherMessageColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.replyToMessageId != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black12
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyToSenderName ?? 'کاربر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          message.replyToContent ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (message.attachmentUrl != null &&
                          message.attachmentUrl!.isNotEmpty &&
                          message.attachmentType == 'image')
                        GestureDetector(
                          onTap: () {},
                          child: ClipRRect(),
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      return timeago.format(time, locale: 'fa');
    } else {
      return '${time.year}/${time.month}/${time.day}';
    }
  }
}

class BlockedUserBanner extends StatelessWidget {
  final String message;

  const BlockedUserBanner({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(top: BorderSide(color: Colors.red.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
