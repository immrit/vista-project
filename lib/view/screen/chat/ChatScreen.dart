import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart';
import '../../../services/uploadImageChatService.dart';
import '../../Exeption/app_exceptions.dart';
import '../../util/time_utils.dart';
import '../../util/widgets.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../../DB/message_cache_service.dart';
import '../../../services/ChatService.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../widgets/web files/image_downloader.dart';
import '/main.dart';
import 'chat_input_box.dart';

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
  Uint8List? _selectedImageBytes; // برای وب
  String? _selectedImageName; // برای وب
  bool _isUploading = false;
  bool _isDisposed = false;
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  MessageModel? _replyToMessage;
  bool _isCurrentUserBlocked = false;
  bool _isOtherUserBlocked = false;
  bool _showScrollToBottom = false;
  double _uploadProgress = 0.0; // درصد پیشرفت آپلود عکس

  bool _isSending = false;
  final MessageCacheService _messageCache =
      MessageCacheService(); // اضافه کردن این خط

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

    // علامت‌گذاری پیام‌ها به عنوان خوانده شده هنگام ورود به صفحه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final safeHandler = ref.read(safeMessageHandlerProvider);
      safeHandler.markAsRead(widget.conversationId);
      print(
          'علامت‌گذاری پیام‌های مکالمه ${widget.conversationId} به عنوان خوانده شده');
    });
    // هنگام ورود به صفحه چت، conversationId فعال را تنظیم کن
    ChatService.activeConversationId = widget.conversationId;

    // اضافه کردن لیسنر برای مدیریت بهتر کیبورد
    WidgetsBinding.instance.addObserver(
      _KeyboardVisibilityObserver(
        onShow: () {
          if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
        },
        onHide: () {
          // اگر کیبورد بسته شد و ایموجی پیکر نمایش داده نشده، فوکس را از دست بدهیم
          if (!_showEmojiPicker) _messageFocusNode.unfocus();
        },
      ),
    );

    // پیش‌لود کش برای عملکرد سریع‌تر
    _preloadCache();
  }

  Future<void> _preloadCache() async {
    await MessageCacheService().getConversationMessages(widget.conversationId);
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
    // هنگام خروج از صفحه چت، conversationId فعال را پاک کن
    if (ChatService.activeConversationId == widget.conversationId) {
      ChatService.activeConversationId = null;
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = pickedFile.name;
            _selectedImage = null;
          });
          print('Web Image selected: ${_selectedImageName}'); // Debug log
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog('خطا در انتخاب تصویر');
    }
  }

  Future<String?> _uploadImage(dynamic fileOrBytes) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      String? imageUrl;
      if (kIsWeb && fileOrBytes is Uint8List && _selectedImageName != null) {
        imageUrl = await ChatImageUploadService.uploadChatImageWeb(
          fileOrBytes,
          _selectedImageName!,
          widget.conversationId,
        );
      } else if (fileOrBytes is File) {
        imageUrl = await ChatImageUploadService.uploadChatImage(
          fileOrBytes,
          widget.conversationId,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      }
      return imageUrl;
    } catch (e) {
      await _showErrorDialog('خطا در آپلود تصویر: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // نمایش دیالوگ خطا
  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطا', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('باشه'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _setReplyMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
      _messageFocusNode.requestFocus();
    });
    // اسکرول خودکار به بالا را حذف کردیم
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _sendMessage() async {
    if (_isCurrentUserBlocked) return;

    final message = _messageController.text.trim();
    if (message.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null) return;

    // پاک کردن محتوای پیام و تصویر قبل از ارسال
    final tempMessage = message;
    final tempImage = _selectedImage;
    final tempImageBytes = _selectedImageBytes;
    final tempImageName = _selectedImageName;
    final tempReplyMessage = _replyToMessage;

    // پاک کردن فوری فیلدها
    setState(() {
      _messageController.clear();
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _replyToMessage = null;
    });

    try {
      // ارسال پیام
      await ref.read(messageNotifierProvider.notifier).sendMessage(
            conversationId: widget.conversationId,
            content: tempMessage,
            attachmentUrl: tempImage?.path ??
                (tempImageBytes != null ? 'temp_image' : null),
            attachmentType:
                (tempImage != null || tempImageBytes != null) ? 'image' : null,
            replyToMessageId: tempReplyMessage?.id,
            replyToContent: tempReplyMessage?.content,
            replyToSenderName: tempReplyMessage?.senderName,
          );
    } catch (e) {
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

  // void _scrollToFirstUnread(List<MessageModel> messages) async {
  //   final currentUserId = supabase.auth.currentUser?.id;
  //   final firstUnreadIndex = messages
  //       .lastIndexWhere((msg) => !msg.isRead && msg.senderId != currentUserId);

  //   if (firstUnreadIndex != -1 && _scrollController.hasClients) {
  //     // چون لیست reverse است، باید به اندیس معکوس اسکرول کنیم
  //     final position =
  //         (messages.length - 1 - firstUnreadIndex) * 72.0; // تقریبی
  //     await Future.delayed(const Duration(milliseconds: 300));
  //     _scrollController.animateTo(
  //       position,
  //       duration: const Duration(milliseconds: 400),
  //       curve: Curves.easeInOut,
  //     );
  //   }
  // }

  void _toggleEmojiKeyboard() {
    if (_showEmojiPicker) {
      // اگر ایموجی پیکر باز است، آن را ببند و فوکوس را به TextField بده
      setState(() => _showEmojiPicker = false);
      FocusScope.of(context).requestFocus(_messageFocusNode);
    } else {
      // اگر کیبورد باز است، آن را ببند و بعد ایموجی پیکر را باز کن
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _showEmojiPicker = true);
        });
      } else {
        setState(() => _showEmojiPicker = true);
      }
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (isKeyboardVisible && _showEmojiPicker) {
      _showEmojiPicker = false;
    }

    // --- اضافه شد: گوش دادن به تغییرات استریم پیام‌ها و بروزرسانی UI ---
    ref.watch(messagesStreamProvider(widget.conversationId));

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
                          : AssetImage(
                                  'lib/view/util/images/default-avatar.jpg')
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
            IconButton(
              icon: Icon(Icons.delete_forever),
              tooltip: 'حذف پیام‌های قدیمی',
              onPressed: () async {
                final oneMonthAgo = DateTime.now().subtract(Duration(days: 30));
                await ref.read(deleteOldMessagesProvider(oneMonthAgo).future);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('پیام‌های قدیمی حذف شدند')),
                );
              },
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
                  child: ref
                          .watch(conversationMessagesProvider(
                              widget.conversationId))
                          .isEmpty
                      ? const Center(
                          child: Text(
                              'پیامی وجود ندارد. اولین پیام را ارسال کنید!'))
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: ref
                              .watch(conversationMessagesProvider(
                                  widget.conversationId))
                              .length,
                          itemBuilder: (context, index) {
                            final message = ref.watch(
                                conversationMessagesProvider(
                                    widget.conversationId))[index];
                            final isMe = message.senderId ==
                                supabase.auth.currentUser?.id;
                            // جداکننده تاریخ
                            bool showDateDivider = false;
                            final msgDate = DateTime(message.createdAt.year,
                                message.createdAt.month, message.createdAt.day);

                            // اگر این پیام اولین پیام از یک روز است (در لیست معکوس)
                            if (index ==
                                ref
                                        .watch(conversationMessagesProvider(
                                            widget.conversationId))
                                        .length -
                                    1) {
                              showDateDivider = true;
                            } else {
                              final prevMsg = ref.watch(
                                  conversationMessagesProvider(
                                      widget.conversationId))[index + 1];
                              if (!_isSameDay(
                                  message.createdAt, prevMsg.createdAt)) {
                                showDateDivider = true;
                              }
                            }
                            // اگر باید جداکننده نمایش داده شود، تاریخ را به صورت فارسی نمایش بده
                            return Column(
                              children: [
                                if (showDateDivider)
                                  _buildDateDivider(message.createdAt),
                                _buildMessageItem(context, message, isMe),
                              ],
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

  // جایگزینی _buildMessageInput با استفاده از ChatInputBox
  Widget _buildMessageInput() {
    return ChatInputBox(
      messageController: _messageController,
      messageFocusNode: _messageFocusNode,
      showEmojiPicker: _showEmojiPicker,
      toggleEmojiPicker: _toggleEmojiKeyboard,
      pickImage: _pickImage,
      sendMessage: _sendMessage,
      onEmojiSelected: _onEmojiSelected,
      isUploading: _isUploading,
      selectedImagePreview:
          _selectedImage != null || (kIsWeb && _selectedImageBytes != null)
              ? _buildImagePreview()
              : null,
      // پارامترهای اختیاری (اگر نیاز دارید)
      isSending: _isSending, // اگر متغیر _isSending دارید
      uploadProgress: _uploadProgress, // اگر progress دارید
      replyToMessage: _replyToMessage?.content, // اگر reply دارید
      replyToUser: _replyToMessage?.senderName,
      onReplyCancel: () {
        setState(() {
          _replyToMessage = null;
        });
      },
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.2,
            ),
            image: DecorationImage(
              image: kIsWeb && _selectedImageBytes != null
                  ? MemoryImage(_selectedImageBytes!)
                  : FileImage(_selectedImage!) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
          child: _isUploading ? _buildUploadProgress() : null,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _buildCloseButton(),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.black.withOpacity(0.5),
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 22),
        onPressed: _isUploading
            ? null
            : () => setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                  _selectedImageName = null;
                }),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
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
    void _showImageViewer(String url) {
      _showFullScreenImage(context, url);
    }

// بخش مربوط به نمایش عکس پیام را اصلاح کنید
    if (message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty &&
        message.attachmentType == 'image') {
      final url = message.attachmentUrl!;

      Widget imageWidget;
      if (url.startsWith('/') && File(url).existsSync()) {
        // تصویر لوکال
        imageWidget = GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(url),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image,
                    size: 40, color: Colors.grey),
              ),
            ),
          ),
        );
      } else if (url.startsWith('http')) {
        // تصویر نتورک
        imageWidget = GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image,
                    size: 40, color: Colors.grey),
              ),
            ),
          ),
        );
      } else {
        imageWidget = const SizedBox.shrink();
      }

      attachmentWidget = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: imageWidget,
      );
    }
    // پیام موقت: رنگ متفاوت یا شفافیت
    final bool isTemp = !message.isSent && message.id.startsWith('temp_');
    final bool isFailed = isTemp && message.retryCount >= 3;
    final double opacity = isTemp ? 0.6 : 1.0;
    final Color? tempColor = isTemp
        ? (isMe
            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
            : Colors.grey[400]?.withOpacity(0.5))
        : null;

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
              child: Opacity(
                opacity: opacity,
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color:
                      tempColor ?? (isMe ? myMessageColor : otherMessageColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight:
                          isMe ? Radius.circular(4) : Radius.circular(16),
                      bottomLeft:
                          isMe ? Radius.circular(16) : Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.replyToMessageId != null)
                        Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                                  textDirection:
                                      getTextDirection(message.content),
                                  child: Text(
                                    message.content,
                                    style: TextStyle(
                                      color:
                                          isMe ? myTextColor : otherTextColor,
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
                                      color: isMe
                                          ? Colors.white24
                                          : Colors.black12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatMessageHour(message.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            isMe ? myTimeColor : otherTimeColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  if (isMe)
                                    // فقط اگر پیام توسط کاربر فعلی ارسال شده و isSent=false و id پیام temp است، ساعت و دکمه ارسال مجدد نمایش بده
                                    isFailed
                                        ? Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                size: 14,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 2),
                                              GestureDetector(
                                                onTap: () async {
                                                  await _retrySendMessage(
                                                      message);
                                                },
                                                child: Icon(
                                                  Icons.refresh,
                                                  size: 16,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          )
                                        : (!message.isSent &&
                                                message.id.startsWith('temp_'))
                                            ? Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: isLightMode
                                                    ? Colors.white24
                                                    : Colors.black,
                                              )
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
        ));
  }

  // ارسال مجدد پیام موقت (retry)
/*************  ✨ Windsurf Command ⭐  *************/
  /// ارسال مجدد پیام موقت (retry)
  ///
  /// فقط پیام‌هایی که ارسال نشده‌اند و فایل تصویرشان پاک نشده است
  /// را ارسال مجدد می‌کند. اگر فایل تصویر پاک شده بود، خطا می‌دهد.
  ///
/*******  b7959514-a546-4fae-a56c-be1f32b5247e  *******/
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // دکمه اشتراک‌گذاری
                // IconButton(
                //   icon: Icon(Icons.share, color: Colors.white),
                //   onPressed: () {
                //     if (imageUrl.startsWith('http')) {
                //       Share.share(imageUrl);
                //     } else {
                //       // Share.shareXFiles([imageUrl]);
                //     }
                //   },
                // ),
                // دکمه دانلود
                IconButton(
                  icon: Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    if (imageUrl.startsWith('http')) {
                      final status = await Permission.storage.request();
                      if (status.isGranted) {
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final fileName =
                            "image_{DateTime.now().millisecondsSinceEpoch}.jpg";
                        final path = "{directory.path}/fileName";

                        try {
                          final response = await http.get(Uri.parse(imageUrl));
                          final file = File(path);
                          await file.writeAsBytes(response.bodyBytes);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تصویر دانلود شد')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطا در دانلود تصویر')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            body: Center(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  // اگر کاربر به سمت بالا یا پایین کشید، صفحه بسته شود
                  if (details.velocity.pixelsPerSecond.dy.abs() > 200) {
                    Navigator.pop(context);
                  }
                },
                child: PhotoView(
                  imageProvider: imageUrl.startsWith('http')
                      ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                      : FileImage(File(imageUrl)),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded /
                                (event.expectedTotalBytes ?? 1),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildImageAttachment(String imageUrl) {
    // اگر فایل لوکال وجود دارد، مستقیم نمایش بده
    if (imageUrl.startsWith('/') && File(imageUrl).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          width: 200,
          height: 200,
        ),
      );
    }

    // اگر لینک اینترنتی است، از سیستم دانلود و کش استفاده کن
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
          // اگر هنوز دانلود نشده، پیش‌نمایش و دکمه دانلود نمایش بده
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
    // تبدیل زمان به ساعت تهران (UTC+3:30)
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = time.toUtc().add(tehranOffset);
    return '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';
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

class ImageFullscreenViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const ImageFullscreenViewer(
      {super.key, required this.imageUrl, required this.heroTag});

  Future<void> _shareImage(BuildContext context) async {
    try {
      if (kIsWeb) {
        // وب: فقط url رو share کن (دانلود مستقیم ممکن نیست)
        Share.share(imageUrl);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempPath = '{tempDir.path}/shared_image.jpg';
        final file = File(tempPath);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(tempPath)]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اشتراک‌گذاری: e')),
      );
    }
  }

  Future<void> _downloadImage(BuildContext context, String imageUrl) async {
    if (kIsWeb) {
      downloadImageOnWeb(imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دانلود آغاز شد')),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            color: Colors.white,
            onPressed: () => _downloadImage(context, imageUrl),
            tooltip: 'دانلود تصویر',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            color: Colors.white,
            onPressed: () => _shareImage(context),
            tooltip: 'اشتراک‌گذاری',
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
          ),
        ),
      ),
    );
  }
}

// کلاس کمکی برای مدیریت Keyboard Visibility
class _KeyboardVisibilityObserver extends WidgetsBindingObserver {
  final VoidCallback onShow;
  final VoidCallback onHide;
  bool _isKeyboardVisible = false;

  _KeyboardVisibilityObserver({required this.onShow, required this.onHide});

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (_isKeyboardVisible != isKeyboardVisible) {
      _isKeyboardVisible = isKeyboardVisible;
      if (isKeyboardVisible) {
        onShow();
      } else {
        onHide();
      }
    }
  }
}

// کلاس کمکی برای ارسال پیام
class MessageSender {
  final WidgetRef ref;
  final String conversationId;
  final String message;
  final File? selectedImage;
  final Uint8List? selectedImageBytes;
  final String? selectedImageName;
  final MessageModel? replyToMessage;
  final Function(double)? onProgress;

  MessageSender({
    required this.ref,
    required this.conversationId,
    required this.message,
    this.selectedImage,
    this.selectedImageBytes,
    this.selectedImageName,
    this.replyToMessage,
    this.onProgress,
  });

  Future<void> send() async {
    final chatService = ref.read(chatServiceProvider);
    final messageCache = MessageCacheService();

    String? attachmentUrl;
    String? attachmentType;

    // آپلود تصویر با مدیریت پیشرفت
    if (selectedImage != null ||
        (selectedImageBytes != null && selectedImageName != null)) {
      attachmentUrl = await _uploadImage();
      attachmentType = 'image';
    }

    // ایجاد پیام موقت
    final tempMessage = await _createTempMessage(attachmentUrl, attachmentType);
    await messageCache.cacheMessage(tempMessage);

    // ارسال پیام به سرور
    try {
      final isOnline = await chatService.isDeviceOnline();
      final sentMessage = isOnline
          ? await chatService.sendMessage(
              conversationId: conversationId,
              content: message,
              attachmentUrl: attachmentUrl,
              attachmentType: attachmentType,
              replyToMessageId: replyToMessage?.id,
              replyToContent: replyToMessage?.content,
              replyToSenderName: replyToMessage?.senderName,
            )
          : await chatService.sendOfflineMessage(
              conversationId: conversationId,
              content: message,
              attachmentUrl: attachmentUrl,
              attachmentType: attachmentType,
              replyToMessageId: replyToMessage?.id,
              replyToContent: replyToMessage?.content,
              replyToSenderName: replyToMessage?.senderName,
            );

      // جایگزینی پیام موقت با پیام واقعی
      await messageCache.replaceTempMessage(
        conversationId,
        tempMessage.id,
        sentMessage,
      );
    } catch (e) {
      await messageCache.markMessageAsFailed(conversationId, tempMessage.id);
      throw e;
    }
  }

  Future<String?> _uploadImage() async {
    if (kIsWeb && selectedImageBytes != null && selectedImageName != null) {
      return await ChatImageUploadService.uploadChatImageWeb(
        selectedImageBytes!,
        selectedImageName!,
        conversationId,
      );
    } else if (selectedImage != null) {
      return await ChatImageUploadService.uploadChatImage(
        selectedImage!,
        conversationId,
        onProgress: onProgress,
      );
    }
    return null;
  }

  Future<MessageModel> _createTempMessage(
      String? attachmentUrl, String? attachmentType) async {
    final currentUser = supabase.auth.currentUser!;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    return MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUser.id,
      content: message,
      createdAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      isRead: false,
      isSent: false,
      senderName: currentUser.userMetadata?['username'] ?? 'من',
      senderAvatar: currentUser.userMetadata?['avatar_url'],
      isMe: true,
      replyToMessageId: replyToMessage?.id,
      replyToContent: replyToMessage?.content,
      replyToSenderName: replyToMessage?.senderName,
    );
  }
}
