import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../model/message_model.dart';
import '../../../provider/Chat_provider.dart.dart';
import '../../../services/uploadImageChatService.dart';
import '../../Exeption/app_exceptions.dart';
import '../../util/time_utils.dart';
import '../../util/widgets.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../../DB/message_cache_service.dart';

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
  bool _isCurrentUserBlocked = false;
  bool _isOtherUserBlocked = false;
  bool _showScrollToBottom = false;

  bool _isSending = false;

  void _toggleEmojiKeyboard() {
    if (_messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _showEmojiPicker = true);
        }
      });
    } else {
      if (_showEmojiPicker) {
        _messageFocusNode.requestFocus();
      }
      setState(() {
        _showEmojiPicker = !_showEmojiPicker;
      });
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursorPosition = selection.isValid ? selection.start : text.length;

    final newText = text.replaceRange(
      cursorPosition,
      selection.isValid ? selection.end : cursorPosition,
      emoji,
    );

    _messageController.text = newText;
    final newPosition = cursorPosition + emoji.length;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: newPosition),
    );
  }

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
    _scrollController.addListener(_handleScrollToBottomBtn);
  }

  Future<void> _checkBlockStatus() async {
    try {
      final chatService = ref.read(chatServiceProvider);

      _isOtherUserBlocked = await chatService.isUserBlocked(widget.otherUserId);
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

  void _handleScrollToBottomBtn() {
    // اگر کاربر از انتهای لیست دور شد، دکمه "رفتن به پایین" را نمایش بده
    if (!_scrollController.hasClients) return;
    final threshold = 200.0;
    final isAtBottom = _scrollController.offset <= threshold;
    if (_showScrollToBottom == isAtBottom) {
      setState(() {
        _showScrollToBottom = !isAtBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageController.dispose();
    _scrollController.removeListener(_handleScrollToBottomBtn);
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
      final imageUrl = await ChatImageUploadService.uploadChatImage(
        file,
        widget.conversationId,
      );

      return imageUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در آپلود تصویر: $e')),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _setReplyMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
      _messageFocusNode.requestFocus();
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

    // --- 1. ساخت پیام موقت و افزودن به کش و UI ---
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final currentUser = supabase.auth.currentUser;
    final now = DateTime.now();
    final tempMessage = MessageModel(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: currentUser?.id ?? '',
      content: message,
      createdAt: now,
      attachmentUrl: _selectedImage?.path,
      attachmentType: _selectedImage != null ? 'image' : null,
      isRead: false,
      isSent: false,
      senderName: currentUser?.userMetadata?['username'] ?? 'من',
      senderAvatar: currentUser?.userMetadata?['avatar_url'],
      isMe: true,
      replyToMessageId: _replyToMessage?.id,
      replyToContent: _replyToMessage?.content,
      replyToSenderName: _replyToMessage?.senderName,
    );
    // ذخیره پیام موقت در کش Hive و حافظه
    await MessageCacheService().cacheMessage(tempMessage);

    setState(() {
      _replyToMessage = null;
      _selectedImage = null;
      // فوراً UI را رفرش کن تا پیام موقت نمایش داده شود
    });

    // اسکرول به پایین
    if (_scrollController.hasClients && mounted) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // --- 2. ارسال پیام به سرور ---
    try {
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

      final isOnline = await chatService.isDeviceOnline();

      MessageModel? sentMessage;
      if (isOnline) {
        sentMessage = await chatService.sendMessage(
          conversationId: widget.conversationId,
          content: message,
          attachmentUrl: attachmentUrl,
          attachmentType: attachmentType,
          replyToMessageId: _replyToMessage?.id,
          replyToContent: _replyToMessage?.content,
          replyToSenderName: _replyToMessage?.senderName,
        );
      } else {
        sentMessage = await chatService.sendOfflineMessage(
          conversationId: widget.conversationId,
          content: message,
          attachmentUrl: attachmentUrl,
          attachmentType: attachmentType,
          replyToMessageId: _replyToMessage?.id,
          replyToContent: _replyToMessage?.content,
          replyToSenderName: _replyToMessage?.senderName,
        );
      }

      // --- 3. جایگزینی پیام موقت با پیام واقعی ---
      if (sentMessage != null) {
        await MessageCacheService().replaceTempMessage(
          widget.conversationId,
          tempId,
          sentMessage,
        );
        // پیام واقعی را از کش مجدداً بخوان و UI را رفرش کن تا وضعیت ساعت به تیک تغییر کند
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // --- 4. اگر خطا رخ داد، وضعیت پیام موقت را به ارسال نشده تغییر بده ---
      await MessageCacheService().markMessageAsFailed(
        widget.conversationId,
        tempId,
      );
      String errorMessage = 'خطای نامشخص';
      if (e is AppException) {
        errorMessage = e.userFriendlyMessage;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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
                  await _checkBlockStatus();
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

  Future<void> _showDeleteMessageDialog(MessageModel message) async {
    if (!mounted) return;

    final isSender = message.senderId == supabase.auth.currentUser?.id;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف پیام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('پیام را چگونه می‌خواهید حذف کنید؟'),
            if (isSender) const SizedBox(height: 8),
            if (isSender)
              Text(
                'توجه: حذف برای همه قابل بازگشت نیست.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message.id, false);
            },
            child: Text('حذف برای من'),
          ),
          if (isSender)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(message.id, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              child: Text('حذف برای همه'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    try {
      await ref
          .read(messageNotifierProvider.notifier)
          .deleteMessage(messageId, forEveryone: forEveryone);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                forEveryone ? 'پیام برای همه حذف شد' : 'پیام برای شما حذف شد'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف پیام: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (isKeyboardVisible && _showEmojiPicker) {
      _showEmojiPicker = false;
    }

    // ابتدا پیام‌های کش شده را نمایش بده، سپس استریم پیام‌ها را گوش بده
    return SafeArea(
      top: false,
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
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<MessageModel>>(
                    future: MessageCacheService()
                        .getConversationMessages(widget.conversationId),
                    builder: (context, snapshot) {
                      final cachedMessages = snapshot.data ?? [];
                      return Consumer(
                        builder: (context, ref, _) {
                          final messagesAsync = ref.watch(
                              messagesStreamProvider(widget.conversationId));
                          return messagesAsync.when(
                            data: (messagesFromServer) {
                              // ترکیب پیام‌های کش شده (موقت) و پیام‌های سرور
                              List<MessageModel> allMessages = [];
                              // پیام‌های موقت: پیام‌هایی که id آنها با temp_ شروع می‌شود یا isSent=false
                              final tempMessages = cachedMessages
                                  .where((m) =>
                                      m.id.startsWith('temp_') ||
                                      m.isSent == false)
                                  .toList();
                              // پیام‌های سرور: پیام‌هایی که id آنها temp_ نیست
                              final serverMessages = messagesFromServer
                                  .where((m) => !m.id.startsWith('temp_'))
                                  .toList();
                              // حذف پیام‌های تکراری (بر اساس id)
                              final tempIds =
                                  tempMessages.map((m) => m.id).toSet();
                              final filteredServerMessages = serverMessages
                                  .where((m) => !tempIds.contains(m.id))
                                  .toList();
                              allMessages = [
                                ...tempMessages,
                                ...filteredServerMessages
                              ];

                              if (allMessages.isEmpty) {
                                return const Center(
                                    child: Text(
                                        'پیامی وجود ندارد. اولین پیام را ارسال کنید!'));
                              }
                              // نمایش پیام‌ها با جداکننده تاریخ
                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                itemCount: allMessages.length,
                                itemBuilder: (context, index) {
                                  final message = allMessages[index];
                                  final isMe = message.senderId ==
                                      supabase.auth.currentUser?.id;
                                  // جداکننده تاریخ
                                  bool showDateDivider = false;
                                  if (index == allMessages.length - 1) {
                                    showDateDivider = true;
                                  } else {
                                    final prevMsg = allMessages[index + 1];
                                    if (!_isSameDay(
                                        message.createdAt, prevMsg.createdAt)) {
                                      showDateDivider = true;
                                    }
                                  }
                                  return Column(
                                    children: [
                                      if (showDateDivider)
                                        _buildDateDivider(message.createdAt),
                                      _buildMessageItem(context, message, isMe),
                                    ],
                                  );
                                },
                              );
                            },
                            loading: () {
                              if (cachedMessages.isNotEmpty) {
                                return ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  itemCount: cachedMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = cachedMessages[index];
                                    final isMe = message.senderId ==
                                        supabase.auth.currentUser?.id;
                                    return _buildMessageItem(
                                        context, message, isMe);
                                  },
                                );
                              }
                              return Center(
                                child: LoadingAnimationWidget.staggeredDotsWave(
                                  color: Theme.of(context).primaryColor,
                                  size: 50,
                                ),
                              );
                            },
                            error: (error, stack) {
                              if (cachedMessages.isNotEmpty) {
                                return ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  itemCount: cachedMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = cachedMessages[index];
                                    final isMe = message.senderId ==
                                        supabase.auth.currentUser?.id;
                                    return _buildMessageItem(
                                        context, message, isMe);
                                  },
                                );
                              }
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
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'پیام‌ها در حال حاضر قابل نمایش نیستند',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => ref.refresh(
                                          messagesStreamProvider(
                                              widget.conversationId)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('تلاش مجدد'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_isCurrentUserBlocked || _isOtherUserBlocked)
                  _buildBlockedBanner(),
                if (!_isCurrentUserBlocked && !_isOtherUserBlocked)
                  _buildMessageInput(),
                if (_showEmojiPicker && !isKeyboardVisible)
                  SizedBox(
                    height: 250,
                    child: EmojiPickerWidget(
                      onEmojiSelected: _onEmojiSelected,
                      onBackspacePressed: () {
                        final text = _messageController.text;
                        if (text.isNotEmpty) {
                          _messageController.text =
                              text.substring(0, text.length - 1);
                        }
                      },
                    ),
                  ),
              ],
            ),
            // دکمه رفتن به پایین
            if (_showScrollToBottom)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _scrollToBottom,
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // جداکننده تاریخ حرفه‌ای با استایل حبابی و بدون تکرار روز هفته
  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final jNow = Jalali.fromDateTime(now);
    final jDate = Jalali.fromDateTime(date);

    String label;
    if (_isSameDay(date, now)) {
      label = 'امروز';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'دیروز';
    } else if (jDate.year == jNow.year) {
      label =
          '${_getPersianWeekDay(jDate.weekDay)}  ${jDate.day.toString().padLeft(2, '0')} ${_getPersianMonth(jDate.month)}';
    } else {
      label =
          '${_getPersianWeekDay(jDate.weekDay)}  ${jDate.day.toString().padLeft(2, '0')} ${_getPersianMonth(jDate.month)} ${jDate.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  String _getPersianWeekDay(int weekDay) {
    switch (weekDay) {
      case 1:
        return 'شنبه';
      case 2:
        return 'یکشنبه';
      case 3:
        return 'دوشنبه';
      case 4:
        return 'سه‌شنبه';
      case 5:
        return 'چهارشنبه';
      case 6:
        return 'پنجشنبه';
      case 7:
        return 'جمعه';
      default:
        return '';
    }
  }

  String _getPersianMonth(int month) {
    switch (month) {
      case 1:
        return 'فروردین';
      case 2:
        return 'اردیبهشت';
      case 3:
        return 'خرداد';
      case 4:
        return 'تیر';
      case 5:
        return 'مرداد';
      case 6:
        return 'شهریور';
      case 7:
        return 'مهر';
      case 8:
        return 'آبان';
      case 9:
        return 'آذر';
      case 10:
        return 'دی';
      case 11:
        return 'بهمن';
      case 12:
        return 'اسفند';
      default:
        return '';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'پاسخ به ${_replyToMessage!.senderName}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          _replyToMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
              ),
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                ),
                onPressed: _toggleEmojiKeyboard,
              ),
              Expanded(
                child: Directionality(
                  textDirection: getTextDirection(_messageController.text),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    onTap: () {
                      if (_showEmojiPicker) {
                        setState(() {
                          _showEmojiPicker = false;
                        });
                      }
                    },
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'پیام خود را بنویسید...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[100]
                              : Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
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

    Widget attachmentWidget = const SizedBox.shrink();

    // نمایش عکس پیام موقت (هنوز آپلود نشده)
    if (message.attachmentUrl != null) {
      if (message.isSent == false && message.attachmentType == 'image') {
        // پیام موقت: عکس از فایل محلی
        attachmentWidget = Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(message.attachmentUrl!),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else if (message.attachmentType?.startsWith('image/') ?? false) {
        // پیام واقعی: عکس از اینترنت
        attachmentWidget = _buildImageAttachment(message.attachmentUrl!);
      }
    }

    return Slidable(
      key: Key(message.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
            foregroundColor: Colors.white,
            onPressed: (_) => _setReplyMessage(message),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.reply, size: 20),
                SizedBox(height: 4),
                Text(
                  'پاسخ',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, message, isMe),
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
                          attachmentWidget,
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
                        // نمایش عکس پیام (موقت یا واقعی)
                        if (message.attachmentUrl != null &&
                            message.attachmentUrl!.isNotEmpty &&
                            message.attachmentType == 'image')
                          attachmentWidget,
                        if (message.content.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: message.attachmentUrl != null ? 8 : 0,
                            ),
                            child: Directionality(
                              textDirection: getTextDirection(message.content),
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  color: isMe ? myTextColor : otherTextColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white24 : Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatMessageHour(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe ? myTimeColor : otherTimeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              if (isMe)
                                // فقط اگر پیام توسط کاربر فعلی ارسال شده و isSent=false و id پیام temp است، ساعت و دکمه ارسال مجدد نمایش بده
                                (!message.isSent &&
                                        message.id.startsWith('temp_'))
                                    ? Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: isLightMode
                                                ? Colors.white24
                                                : Colors.black,
                                          ),
                                          SizedBox(width: 2),
                                          GestureDetector(
                                            onTap: () async {
                                              await _retrySendMessage(message);
                                            },
                                            child: Icon(
                                              Icons.refresh,
                                              size: 16,
                                              color: isLightMode
                                                  ? Colors.white24
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      )
                                    // اگر پیام ارسال شده یا پیام واقعی است، تیک نمایش بده
                                    : Icon(
                                        message.isRead
                                            ? Icons.done_all
                                            : Icons.done,
                                        size: 14,
                                        color: message.isRead
                                            ? Colors.blue
                                            : (isMe
                                                ? myTimeColor
                                                : otherTimeColor),
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
      ),
    );
  }

  // ارسال مجدد پیام موقت (retry)
  Future<void> _retrySendMessage(MessageModel message) async {
    // فقط پیام‌هایی که ارسال نشده‌اند
    if (message.isSent == false) {
      // اگر پیام عکس داشت و فایلش پاک شده بود، خطا بده
      if (message.attachmentType == 'image' &&
          message.attachmentUrl != null &&
          !File(message.attachmentUrl!).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فایل تصویر یافت نشد!')),
        );
        return;
      }
      // ارسال مجدد پیام (تقریباً مشابه _sendMessage)
      String? attachmentUrl;
      String? attachmentType;
      if (message.attachmentType == 'image' && message.attachmentUrl != null) {
        setState(() => _isUploading = true);
        try {
          attachmentUrl = await _uploadImage(File(message.attachmentUrl!));
          attachmentType = 'image';
        } catch (e) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ارسال تصویر ناموفق بود')),
          );
          return;
        }
        setState(() => _isUploading = false);
      }
      final chatService = ref.read(chatServiceProvider);
      try {
        final isOnline = await chatService.isDeviceOnline();
        MessageModel? sentMessage;
        if (isOnline) {
          sentMessage = await chatService.sendMessage(
            conversationId: message.conversationId,
            content: message.content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            replyToMessageId: message.replyToMessageId,
            replyToContent: message.replyToContent,
            replyToSenderName: message.replyToSenderName,
          );
        } else {
          sentMessage = await chatService.sendOfflineMessage(
            conversationId: message.conversationId,
            content: message.content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            replyToMessageId: message.replyToMessageId,
            replyToContent: message.replyToContent,
            replyToSenderName: message.replyToSenderName,
          );
        }
        // جایگزینی پیام موقت با پیام واقعی
        await MessageCacheService().replaceTempMessage(
          message.conversationId,
          message.id,
          sentMessage!,
        );
        // فوراً UI را رفرش کن تا وضعیت ساعت به تیک تغییر کند
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        await MessageCacheService().markMessageAsFailed(
          message.conversationId,
          message.id,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ارسال مجدد پیام ناموفق بود')),
        );
      }
    }
  }

  void _showMessageOptions(
      BuildContext context, MessageModel message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    Icon(Icons.reply, color: Theme.of(context).primaryColor),
                title: Text('پاسخ'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyMessage(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('حذف پیام'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteMessageDialog(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: Colors.blue),
                title: Text('کپی پیام'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('پیام کپی شد')),
                  );
                },
              ),
              if (!isMe)
                ListTile(
                  leading: Icon(Icons.report, color: Colors.orange),
                  title: Text('گزارش پیام'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportMessageDialog(context, message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReportMessageDialog(BuildContext context, MessageModel message) {
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
      builder: (context) => AlertDialog(
        title: Text('گزارش پیام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedReason,
              items: reportReasons.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedReason = value;
                }
              },
              decoration: InputDecoration(
                labelText: 'دلیل گزارش',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: reportReasonController,
              decoration: InputDecoration(
                labelText: 'توضیحات بیشتر (اختیاری)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(userReportNotifierProvider.notifier)
                  .reportUser(
                    userId: message.senderId,
                    reason: selectedReason,
                    additionalInfo: reportReasonController.text.trim(),
                  )
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('گزارش پیام ارسال شد')),
                );
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در ارسال گزارش')),
                );
              });
            },
            child: Text('ارسال گزارش'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadImage(String imageUrl, WidgetRef ref) async {
    final chatService = ref.read(chatServiceProvider);
    final downloadNotifier = ref.read(imageDownloadProvider.notifier);

    downloadNotifier.startDownload(imageUrl);

    try {
      final filePath = await chatService.downloadChatImage(
        imageUrl,
        (progress) {
          downloadNotifier.updateProgress(imageUrl, progress);
        },
      );

      downloadNotifier.setDownloaded(imageUrl, filePath);
    } catch (e) {
      downloadNotifier.setError(imageUrl, 'خطا در دانلود: $e');
    }
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
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
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageAttachment(String imageUrl) {
    return Consumer(
      builder: (context, ref, child) {
        final downloadStateMap = ref.watch(imageDownloadProvider);
        final downloadState =
            downloadStateMap[imageUrl] ?? const ImageDownloadState();

        if (downloadState.isDownloaded && downloadState.path != null) {
          return GestureDetector(
            onTap: () => _showFullScreenImage(context, downloadState.path!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(downloadState.path!),
                fit: BoxFit.cover,
                width: 200,
                height: 200,
              ),
            ),
          );
        } else if (downloadState.isDownloading) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: downloadState.progress,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 10),
                Text(
                  '${(downloadState.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: () {
                    ref.read(imageDownloadProvider.notifier).reset(imageUrl);
                  },
                  child: const Text('لغو'),
                ),
              ],
            ),
          );
        } else {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 40,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _downloadImage(imageUrl, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: const Text('دانلود تصویر'),
                ),
                if (downloadState.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      downloadState.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }

  String _formatMessageHour(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class BlockedUserBanner extends StatelessWidget {
  final String message;

  const BlockedUserBanner({super.key, required this.message});

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

class ChatMessagesShimmer extends StatelessWidget {
  const ChatMessagesShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        reverse: true,
        itemCount: 12,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: index % 2 == 0
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              Container(
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmojiPickerWidget extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspacePressed;

  const EmojiPickerWidget({
    Key? key,
    required this.onEmojiSelected,
    required this.onBackspacePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) => onEmojiSelected(emoji.emoji),
        onBackspacePressed: onBackspacePressed,
        config: Config(
          height: 256,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 *
                (foundation.defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.2
                    : 1.0),
            backgroundColor: Colors.grey,
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: Colors.indigo,
            iconColorSelected: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabIndicatorAnimDuration: const Duration(milliseconds: 300),
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
            buttonColor: Theme.of(context).colorScheme.primary,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: Colors.indigo,
            buttonIconColor: Colors.indigo,
          ),
        ),
      ),
    );
  }
}
