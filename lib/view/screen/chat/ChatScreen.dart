import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
// import 'dart:ui' show ImageFilter;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart';
import '../../../provider/provider.dart';
import '../../../services/audio_recording_service.dart';
import '../../../services/uploadAudioChatService.dart';
import '../../../services/uploadImageChatService.dart';
import '../../../services/wallpaper_cache_service.dart';
import '../../Exeption/app_exceptions.dart';
import '../../util/time_utils.dart';
import '../../util/widgets.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../../DB/message_cache_service_wrapper.dart';
import '../../../DB/unified_cache_system.dart';
import '../../../services/ChatService.dart';
import '../../../services/cache_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../widgets/audio_player_widget.dart';
import '../../widgets/web files/image_downloader.dart';
import '/main.dart';
import 'ChatDetailsScreen.dart';
import 'chat_input_box.dart';
import '../../../security/e2ee_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;
  final bool isNewConversation; // اضافه شد: برای تشخیص مکالمه جدید

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
    this.isNewConversation = false, // مقدار پیش‌فرض false
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  // Tracks which message images are allowed to load inline after user action
  final Set<String> _inlineImageGrants = <String>{};
  final Set<String> _inlineImageLoaded = <String>{};
  final Map<String, double> _inlineImageProgress = <String, double>{};
  // final Map<String, String> _inlineImageLocalPath = <String, String>{};
  // کنترلرهای جدید برای لیست قابل اسکرول
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  final imagePicker = ImagePicker();
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // برای وب
  String? _selectedImageName; // برای وب
  bool _isUploading = false;
  // Removed unused _isDisposed flag
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;

  // اضافه شد: برای ذخیره conversationId پس از ایجاد مکالمه جدید
  String? _localConversationId;

  // (deprecated) placeholder gradient generator – no longer used
  // List<Color> _placeholderColorsFromSeed(String seed) { ... }

  String _buildThumbnailUrl(String url) {
    // Supabase Transform API (fast, low-cost) if path matches
    if (url.contains('/storage/v1/object/public/')) {
      return url.replaceFirst('/object/public/', '/render/image/public/') +
          (url.contains('?') ? '&' : '?') +
          'width=64&quality=20';
    }
    // Generic CDNs that accept width/quality query params
    if (url.contains('coffevista') ||
        url.contains('arvan') ||
        url.contains('cdn')) {
      return url + (url.contains('?') ? '&' : '?') + 'w=64&q=20';
    }
    // Fallback: return original (data usage will be higher). Consider adding a proxy later.
    return url;
  }

  MessageModel? _replyToMessage;

  bool _isCurrentUserBlocked = false;
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _isOtherUserBlocked = false;
  bool _showScrollToBottom = false;
  double _uploadProgress = 0.0; // درصد پیشرفت آپلود عکس
  File? _selectedAudio;
  Uint8List? _selectedAudioBytes; // برای وب
  String? _selectedAudioName; // برای وب
  bool _isRecordingAudio = false;

  bool _isSending = false;

  // کش محلی برای رمزگشایی پیام‌ها جهت بهبود عملکرد
  final Map<String, String> _decryptionCache = {};
  final Map<String, Future<String>> _decryptionFutures = {};
  // cache service instance (lazy read via service when needed)
  // final MessageCacheService _messageCache = MessageCacheService();

  // متغیرهای جدید برای انیمیشن پاسخ به پیام
  Map<String, AnimationController> _messageAnimationControllers = {};
  // Map<String, Animation<double>> _messageSlideAnimations = {};
  Map<String, bool> _messageReplyStates = {};
  // String? _currentlyReplyingToMessageId; // current reply target id

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userBlockStatusProvider(widget.otherUserId));
    });
    timeago.setLocaleMessages('fa', timeago.FaMessages());

    Future.microtask(() {
      // قابلیت خواندن پیام حذف شد
      ref.read(userOnlineNotifierProvider).updateOnlineStatus();
      _checkOnlineStatus();
    });
    _itemPositionsListener.itemPositions.addListener(_handleScrollToBottomBtn);

    // و حذف نوتیفیکیشن‌های مربوط به این مکالمه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId.isNotEmpty) {
        final int notificationId = widget.conversationId.hashCode;
        flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    });

    // هنگام ورود به صفحه چت، conversationId فعال را تنظیم کن
    // فقط اگر مکالمه موجود باشد
    if (widget.conversationId.isNotEmpty) {
      ChatService.activeConversationId = widget.conversationId;
    }

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
    if (widget.conversationId.isNotEmpty) {
      _preloadCache();
    }

    // Precompute E2EE conversation key for faster decrypt
    // فقط اگر مکالمه موجود باشد
    if (widget.conversationId.isNotEmpty) {
      E2EEService.instance.prepareConversationKey(
        conversationId: widget.conversationId,
        otherUserId: widget.otherUserId,
      );
    }

    // فعال‌سازی مکانیزم ارسال پیام‌های آفلاین به محض آنلاین شدن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingMessagesSyncProvider);
    });

    // پیش‌بارگذاری والپیپر برای عملکرد بهتر
    _preloadWallpaper();
  }

  /// رمزگشایی محتوای پیام به صورت شفاف برای کاربر
  Future<String> _decryptMessageContent(
    String content,
    String messageId,
    String senderId,
    DateTime createdAt,
  ) async {
    // اگر محتوا رمزنگاری نشده، مستقیم برگردان
    if (!content.startsWith('e2ee:v1:')) {
      return content;
    }

    // ابتدا کش محلی را چک کن
    if (_decryptionCache.containsKey(messageId)) {
      return _decryptionCache[messageId]!;
    }

    // اگر در حال رمزگشایی این پیام هستیم، از future موجود استفاده کن
    if (_decryptionFutures.containsKey(messageId)) {
      return await _decryptionFutures[messageId]!;
    }

    // یک future برای رمزگشایی ایجاد کن
    final decryptionFuture =
        _performDecryption(content, messageId, senderId, createdAt);
    _decryptionFutures[messageId] = decryptionFuture;

    try {
      final result = await decryptionFuture;
      // نتیجه را در کش محلی ذخیره کن
      _decryptionCache[messageId] = result;
      return result;
    } finally {
      // future را پاک کن
      _decryptionFutures.remove(messageId);
    }
  }

  Future<String> _performDecryption(
    String content,
    String messageId,
    String senderId,
    DateTime createdAt,
  ) async {
    try {
      // ابتدا کش سرویس را چک کن
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final cachedContent =
            await E2EEService.instance.getCachedDecryptedContent(
          messageId: messageId,
          conversationId: widget.conversationId,
          userId: userId,
        );

        if (cachedContent != null && cachedContent.isNotEmpty) {
          return cachedContent;
        }
      }

      // اگر در کش نبود، رمزگشایی کن
      final decrypted = await E2EEService.instance.maybeDecryptWithSender(
        content: content,
        conversationId: widget.conversationId,
        senderId: senderId,
        messageId: messageId,
        userId: userId,
        messageCreatedAt: createdAt,
      );

      // اگر رمزگشایی موفق بود، نتیجه را برگردان
      if (decrypted.isNotEmpty) {
        return decrypted;
      }

      // اگر رمزگشایی شکست خورد، پیام خطا نمایش بده
      return 'پیام رمزنگاری شده (در حال پردازش...)';
    } catch (e) {
      print('[ChatScreen] Error decrypting message $messageId: $e');
      return 'پیام رمزنگاری شده (در حال پردازش...)';
    }
  }

  String _getReplySenderName(MessageModel message) {
    final name = message.replyToSenderName;
    if (name != null && name.trim().isNotEmpty && name != 'کاربر') {
      return name;
    }
    return message.senderName ?? widget.otherUserName;
  }

  /// پیش‌بارگذاری هوشمند والپیپر با سرویس اختصاصی
  Future<void> _preloadWallpaper() async {
    // استفاده از سرویس مدیریت کش والپیپر
    await WallpaperCacheService.preloadWallpapers();
  }

  Future<void> _preloadCache() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null && widget.conversationId.isNotEmpty) {
      await MessageCacheService()
          .getConversationMessages(widget.conversationId, userId);
    }
  }

  // اضافه شد: پیش‌بارگذاری کش برای مکالمه جدید پس از ایجاد
  Future<void> _preloadCacheForNewConversation(String conversationId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await MessageCacheService()
          .getConversationMessages(conversationId, userId);
    }
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
    if (_itemPositionsListener.itemPositions.value.isEmpty) return;

    // بررسی اینکه آیا اولین آیتم (جدیدترین پیام) در صفحه دیده می‌شود یا خیر
    final firstItemVisible = _itemPositionsListener.itemPositions.value
        .any((pos) => pos.index == 0 && pos.itemLeadingEdge >= 0);

    final shouldShow = !firstItemVisible;

    if (_showScrollToBottom != shouldShow) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom() {
    _itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _itemPositionsListener.itemPositions
        .removeListener(_handleScrollToBottomBtn);
    _highlightTimer?.cancel();
    _messageFocusNode.dispose();

    // پاک کردن انیمیشن کنترلرها
    for (var controller in _messageAnimationControllers.values) {
      controller.dispose();
    }
    _messageAnimationControllers.clear();

    // پاک کردن کش رمزگشایی
    _decryptionCache.clear();
    _decryptionFutures.clear();

    // هنگام خروج از صفحه چت، conversationId فعال را پاک کن
    if (ChatService.activeConversationId == widget.conversationId) {
      ChatService.activeConversationId = null;
    }
    super.dispose();
  }

  // متد جدید برای پرش به پیام
  void _jumpToMessage(String messageId) {
    final messages =
        ref.read(conversationMessagesProvider(widget.conversationId));
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      setState(() {
        _highlightedMessageId = messageId;
      });

      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5, // اسکرول به وسط صفحه برای دید بهتر
      );

      // حذف هایلایت بعد از چند ثانیه
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیام مورد نظر در لیست فعلی یافت نشد.')),
      );
    }
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
  }

  // void _cancelReply() {
  //   setState(() {
  //     _replyToMessage = null;
  //   });
  // }

  void _sendMessage() async {
    if (_isCurrentUserBlocked) return;

    final message = _messageController.text.trim();
    if (message.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null &&
        _selectedAudio == null && // اضافه
        _selectedAudioBytes == null) return; // اضافه

    // ذخیره مقادیر موقت
    final tempMessage = message;
    final tempImage = _selectedImage;
    final tempImageBytes = _selectedImageBytes;
    // final tempImageName = _selectedImageName; // unused
    final tempAudio = _selectedAudio; // اضافه
    final tempAudioBytes = _selectedAudioBytes; // اضافه
    // final tempAudioName = _selectedAudioName; // unused
    final tempReplyMessage = _replyToMessage;

    setState(() {
      _isSending = true;
      _messageController.clear();
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedAudio = null; // اضافه
      _selectedAudioBytes = null; // اضافه
      _selectedAudioName = null; // اضافه
      _replyToMessage = null;
    });

    try {
      String conversationId = _localConversationId ?? widget.conversationId;

      // اگر مکالمه جدید است، ابتدا آن را ایجاد کن
      if (widget.isNewConversation && conversationId.isEmpty) {
        try {
          final chatService = ref.read(chatServiceProvider);
          conversationId =
              await chatService.createOrGetConversation(widget.otherUserId);

          // بروزرسانی conversationId محلی برای پیام‌های بعدی
          _localConversationId = conversationId;

          // بروزرسانی ChatService.activeConversationId
          ChatService.activeConversationId = conversationId;

          // پیش‌بارگذاری کش برای مکالمه جدید
          await _preloadCacheForNewConversation(conversationId);

          // آماده‌سازی E2EE برای مکالمه جدید
          try {
            await E2EEService.instance.prepareConversationKey(
              conversationId: conversationId,
              otherUserId: widget.otherUserId,
            );
          } catch (e) {
            print('خطا در آماده‌سازی E2EE: $e');
          }
        } catch (e) {
          print('خطا در ایجاد مکالمه: $e');
          if (mounted) {
            setState(() => _isSending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطا در ایجاد مکالمه: $e')),
            );
          }
          return;
        }
      }

      String? attachmentUrl;
      String? attachmentType;

      // بررسی فایل صوتی (جدید)
      if (tempAudio != null || tempAudioBytes != null) {
        attachmentUrl = await _uploadAudio(tempAudio ?? tempAudioBytes);
        attachmentType = 'audio';
      }
      // بررسی تصویر (موجود)
      else if (tempImage != null || tempImageBytes != null) {
        attachmentUrl = await _uploadImage(tempImage ?? tempImageBytes);
        attachmentType = 'image';
      }

      // ارسال پیام
      await ref.read(messageNotifierProvider.notifier).sendMessage(
            conversationId: conversationId,
            content: tempMessage,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            replyToMessageId: tempReplyMessage?.id,
            replyToContent: tempReplyMessage?.content,
            replyToSenderName: tempReplyMessage?.senderName,
          );

      if (mounted) {
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false; // اضافه کنید
        });
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
              )
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

  // String _formatLastSeen(DateTime lastSeen) {
  //   final tehranOffset = const Duration(hours: 3, minutes: 30);
  //   final tehranTime = lastSeen.toUtc().add(tehranOffset);
  //   final now = DateTime.now();
  //   final difference = now.difference(tehranTime);
  //
  //   if (difference.inDays == 0) {
  //     return 'امروز ${DateFormat('HH:mm').format(tehranTime)}';
  //   } else if (difference.inDays == 1) {
  //     return 'دیروز ${DateFormat('HH:mm').format(tehranTime)}';
  //   } else if (difference.inDays < 7) {
  //     final weekday = _getDayOfWeekInPersian(tehranTime.weekday);
  //     return '$weekday ${DateFormat('HH:mm').format(tehranTime)}';
  //   } else {
  //     return DateFormat('yyyy/MM/dd - HH:mm').format(tehranTime);
  //   }
  // }

  // String _getDayOfWeekInPersian(int weekday) {
  //   switch (weekday) {
  //     case 1:
  //       return 'دوشنبه';
  //     case 2:
  //       return 'سه‌شنبه';
  //     case 3:
  //       return 'چهارشنبه';
  //     case 4:
  //       return 'پنج‌شنبه';
  //     case 5:
  //       return 'جمعه';
  //     case 6:
  //       return 'شنبه';
  //     case 7:
  //       return 'یکشنبه';
  //     default:
  //       return '';
  //   }
  // }

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
                      color: Colors.red.withValues(alpha: 0.1),
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
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final notifier = ref.read(messageNotifierProvider.notifier);

                  navigator.pop();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Row(children: [
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
                      ]),
                      duration: Duration(seconds: 4),
                    ),
                  );

                  notifier
                      .deleteAllMessages(widget.conversationId,
                          forEveryone: bothSides)
                      .then((_) {
                    if (!mounted) return;
                    messenger.removeCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تاریخچه گفتگو با موفقیت پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // After clearing, if the conversation is fully removed (e.g., last participant leaves), pop the screen.
                    // The provider will be updated, and we can check its state.
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        final conversationExists = ref
                                .read(
                                    conversationProvider(widget.conversationId))
                                .hasValue &&
                            ref
                                    .read(conversationProvider(
                                        widget.conversationId))
                                    .value !=
                                null;
                        if (!conversationExists) {
                          navigator.pop();
                        }
                      }
                    });
                  }).catchError((error) {
                    if (!mounted) return;
                    messenger.removeCurrentSnackBar();
                    String errorMessage = 'خطا در پاکسازی گفتگو';
                    if (error is AppException) {
                      errorMessage = error.userFriendlyMessage;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red),
                    );
                  });
                },
                child: const Text(
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
      // کنترلرها و فوکوس
      messageController: _messageController,
      messageFocusNode: _messageFocusNode,

      // رفتارها
      toggleEmojiPicker: _toggleEmojiKeyboard,
      pickImage: _pickImage,
      sendMessage: _sendMessage,
      onEmojiSelected: _onEmojiSelected,
      onReplyCancel: () {
        setState(() {
          _replyToMessage = null;
        });
      },

      // رفتارهای صوتی
      onAudioRecorded: _onAudioRecorded,
      onStartRecording: _startRecording,
      onStopRecording: _stopRecording,
      onImageCancel: _onImageCancel,
      onAudioCancel: _cancelAudioPreview,

      // وضعیت‌ها
      showEmojiPicker: _showEmojiPicker,
      isUploading: _isUploading,
      isSending: _isSending,
      isRecordingAudio: _isRecordingAudio,
      uploadProgress: _uploadProgress,

      // داده‌ها با فرمت جدید
      replyData: _replyToMessage != null
          ? ReplyData(
              message: _replyToMessage!.content,
              user: _replyToMessage!.senderName ?? 'کاربر',
            )
          : null,

      selectedImage:
          (_selectedImage != null || (kIsWeb && _selectedImageBytes != null))
              ? SelectedFile(
                  file: _selectedImage,
                  bytes: kIsWeb ? _selectedImageBytes : null,
                  name: kIsWeb ? _selectedImageName : null,
                  type: 'image',
                )
              : null,

      selectedAudio:
          (_selectedAudio != null || (kIsWeb && _selectedAudioBytes != null))
              ? SelectedFile(
                  file: _selectedAudio,
                  bytes: kIsWeb ? _selectedAudioBytes : null,
                  name: _selectedAudioName,
                  type: 'audio',
                )
              : null,

      customImagePreview:
          (_selectedImage != null || (kIsWeb && _selectedImageBytes != null))
              ? _buildImagePreview()
              : null,
    );
  }

  // تابعی برای شروع ضبط صدا
  void _startRecording() async {
    setState(() {
      _isRecordingAudio = true;
      _selectedAudio = null;
      _selectedAudioBytes = null;
      _selectedAudioName = null;
    });
    print('DEBUG: Recording started.');
    await AudioRecordingService.startRecording();
  }

  // تابعی برای توقف ضبط صدا
  void _stopRecording() async {
    setState(() {
      _isRecordingAudio = false;
    });
    print('DEBUG: Recording stopped. Attempting to get audio file...');
    try {
      final file = await AudioRecordingService.stopRecording();
      if (file != null) {
        print(
            'DEBUG: AudioRecordingService.stopRecording() returned file: ${file.path}');
        _onAudioRecorded(file, null, file.path.split('/').last);
      } else {
        print('ERROR: AudioRecordingService.stopRecording() returned null.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('خطا در ذخیره فایل صوتی. لطفا دوباره تلاش کنید.')),
          );
        }
      }
    } catch (e) {
      print('ERROR: Exception during stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در توقف ضبط: ${e.toString()}')),
        );
      }
    }
  }

  // تابع مدیریت ضبط صوت
  void _onAudioRecorded(
      File? audioFile, Uint8List? audioBytes, String? fileName) {
    if (audioFile != null || audioBytes != null) {
      print('DEBUG: _onAudioRecorded called with file: $fileName');
      setState(() {
        _selectedAudio = audioFile;
        _selectedAudioBytes = audioBytes;
        _selectedAudioName = fileName;
      });
    } else {
      print(
          'DEBUG: _onAudioRecorded called with null file, clearing selected audio.');
      setState(() {
        _selectedAudio = null;
        _selectedAudioBytes = null;
        _selectedAudioName = null;
        _isRecordingAudio = false;
      });
    }
  }

  // تابع حذف پیش‌نمایش صوتی
  void _cancelAudioPreview() {
    setState(() {
      _selectedAudio = null;
      _selectedAudioBytes = null;
      _selectedAudioName = null;
    });
    print('DEBUG: Audio preview cancelled.');
  }

  // تابع حذف پیش‌نمایش تصویر
  void _onImageCancel() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  /// Bubble radius similar to popular messengers: bottom inner corner tighter,
  /// bottom outer corner larger to "stick out" slightly.
  BorderRadius _getTelegramXBorderRadius(bool isMe, double fontSize) {
    final double baseRadius = math.max(18.0, fontSize * 1.3);
    final double tailSmallRadius =
        math.max(3.0, fontSize * 0.22); // inner corner
    final double tailLargeRadius =
        math.max(22.0, fontSize * 1.6); // outer corner

    return BorderRadius.only(
      topLeft: Radius.circular(baseRadius),
      topRight: Radius.circular(baseRadius),
      bottomLeft: Radius.circular(isMe ? tailLargeRadius : tailSmallRadius),
      bottomRight: Radius.circular(isMe ? tailSmallRadius : tailLargeRadius),
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
        color: Colors.black.withValues(alpha: 0.35),
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
      color: Colors.black.withValues(alpha: 0.5),
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

  // تابع آپلود صوت
  Future<String?> _uploadAudio(dynamic fileOrBytes) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      String? audioUrl;
      if (kIsWeb && fileOrBytes is Uint8List && _selectedAudioName != null) {
        audioUrl = await ChatAudioUploadService.uploadChatAudioWeb(
          fileOrBytes,
          _selectedAudioName!,
          widget.conversationId,
        );
      } else if (fileOrBytes is File) {
        audioUrl = await ChatAudioUploadService.uploadChatAudio(
          fileOrBytes,
          widget.conversationId,
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
        );
      }
      return audioUrl;
    } catch (e) {
      _showErrorDialog('خطا در آپلود فایل صوتی: $e');
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

  Widget _buildMessageItem(
      BuildContext context, MessageModel message, bool isMe) {
    return Consumer(
      builder: (context, ref, child) {
        final fontSize = ref.watch(messageFontSizeProvider);
        return _buildMessageItemContent(context, message, isMe, fontSize);
      },
    );
  }

  Widget _buildHeaderShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animation) * -20),
          child: Opacity(
            opacity: animation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button shimmer
                  Shimmer.fromColors(
                    baseColor:
                        isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    highlightColor:
                        isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                    period: const Duration(milliseconds: 1000),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar shimmer
                  Shimmer.fromColors(
                    baseColor:
                        isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    highlightColor:
                        isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                    period: const Duration(milliseconds: 1000),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and status shimmer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[100]!,
                          period: const Duration(milliseconds: 1000),
                          child: Container(
                            height: 16,
                            width: 120,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Shimmer.fromColors(
                          baseColor: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[100]!,
                          period: const Duration(milliseconds: 1000),
                          child: Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More button shimmer
                  Shimmer.fromColors(
                    baseColor:
                        isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    highlightColor:
                        isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                    period: const Duration(milliseconds: 1000),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animation) * 30),
          child: Opacity(
            opacity: animation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Attachment button shimmer
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, animation, child) {
                      return Transform.scale(
                        scale: 0.8 + (animation * 0.2),
                        child: Shimmer.fromColors(
                          baseColor: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[100]!,
                          period: const Duration(milliseconds: 1000),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Text input shimmer
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1400),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, animation, child) {
                        return Transform.scale(
                          scale: 0.9 + (animation * 0.1),
                          child: Shimmer.fromColors(
                            baseColor: isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                            highlightColor: isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey[100]!,
                            period: const Duration(milliseconds: 1000),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button shimmer
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, animation, child) {
                      return Transform.scale(
                        scale: 0.8 + (animation * 0.2),
                        child: Shimmer.fromColors(
                          baseColor: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[100]!,
                          period: const Duration(milliseconds: 1000),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageItemContent(
      BuildContext context, MessageModel message, bool isMe, double fontSize) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLightMode = brightness == Brightness.light;
    final colorScheme = theme.colorScheme;

    // Detect pure white light theme: surface is pure white in our white theme
    final isWhiteTheme = isLightMode && colorScheme.surface == Colors.white;

    // gradients not used in current flat design
    // final LinearGradient? myMessageGradient = null;

    // final LinearGradient? otherMessageGradient = null;

    // Bubble colors per request: outgoing black tone (solid), incoming whiter
    final Color outgoingBubbleColor =
        isLightMode ? const Color(0xFF323232) : const Color(0xFF2A2A2A);
    final Color incomingBubbleColor =
        isLightMode ? Colors.white : Colors.grey.shade800;

    final Color myTextColor = Colors.white;
    final Color otherTextColor = isLightMode ? Colors.black87 : Colors.white;

    final Color myTimeColor = Colors.white70;
    final Color otherTimeColor = isLightMode ? Colors.black54 : Colors.white70;

    Widget attachmentWidget = const SizedBox.shrink();
    final bool isImageAttachment = message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty &&
        message.attachmentType == 'image';
    final bool isAudioAttachment = message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty &&
        message.attachmentType == 'audio';
    final bool isImageOnly = isImageAttachment && message.content.isEmpty;
    // void _showImageViewer(String url) {
    //   _showFullScreenImage(context, url);
    // }

    if (isAudioAttachment) {
      attachmentWidget = Padding(
        padding: const EdgeInsets.only(top: 0.0), // پدینگ صفر شد
        child: AudioPlayerWidget(
          audioUrl: message.attachmentUrl!,
          isMe: isMe,
        ),
      );
    }
// بررسی پیام تصویری (کد موجود)
    else if (isImageAttachment) {
      final url = message.attachmentUrl!;

      Widget imageWidget;
      if (url.startsWith('/') && File(url).existsSync()) {
        // تصویر لوکال
        imageWidget = GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: LayoutBuilder(builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(url),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  constraints: const BoxConstraints(
                    maxWidth: 260,
                    maxHeight: 320,
                  ),
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image,
                      size: 40, color: Colors.grey),
                ),
              ),
            );
          }),
        );
      } else if (url.startsWith('http')) {
        // تصویر نتورک با احترام به تنظیم دانلود خودکار
        final settings = ref.watch(autoDownloadProvider);
        final bool shouldInlineLoad = settings.photos != 'never' ||
            _inlineImageGrants.contains(message.id);

        imageWidget = LayoutBuilder(builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 260,
                maxHeight: 320,
              ),
              child: shouldInlineLoad
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, url, progress) {
                        final p = progress.progress ?? 0.0;
                        _inlineImageProgress[message.id] = p;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(color: Colors.grey[300]),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(value: p),
                            ),
                          ],
                        );
                      },
                      imageBuilder: (context, provider) {
                        // علامت‌گذاری به عنوان لودشده (بدون رندر مجدد)
                        _inlineImageLoaded.add(message.id);
                        _inlineImageProgress.remove(message.id);
                        return GestureDetector(
                          onTap: () {
                            if (_inlineImageLoaded.contains(message.id)) {
                              _showFullScreenImage(context, url);
                            }
                          },
                          child: Image(
                            image: provider,
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image,
                            size: 40, color: Colors.grey),
                      ),
                    )
                  : GestureDetector(
                      onTap: () async {
                        if (_inlineImageGrants.contains(message.id)) return;
                        setState(() {
                          _inlineImageGrants.add(message.id);
                          _inlineImageProgress[message.id] = 0.0;
                        });
                        try {
                          final chatService = ref.read(chatServiceProvider);
                          await chatService.prefetchImageCancelable(
                            message.id,
                            url,
                            (p) {
                              if (mounted) {
                                setState(() {
                                  _inlineImageProgress[message.id] = p;
                                });
                              }
                            },
                          );
                          // پس از اتمام دانلود، CachedNetworkImage تصویر را از دیسک لود می‌کند
                          if (mounted) {
                            setState(() {});
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _inlineImageGrants.remove(message.id);
                              _inlineImageProgress.remove(message.id);
                            });
                          }
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Real blurred thumbnail (low-res) to preview actual image composition
                          CachedNetworkImage(
                            imageUrl: _buildThumbnailUrl(url),
                            fit: BoxFit.cover,
                            imageBuilder: (context, provider) => ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: provider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            placeholder: (context, _) =>
                                Container(color: Colors.grey[300]),
                            errorWidget: (context, _, __) =>
                                Container(color: Colors.grey[300]),
                          ),
                          Container(color: Colors.black26),
                          Center(
                            child: StatefulBuilder(
                              builder: (context, _) {
                                final granted =
                                    _inlineImageGrants.contains(message.id);
                                final progress =
                                    _inlineImageProgress[message.id];
                                final isDownloading = granted &&
                                    (progress != null && progress < 1.0);
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isDownloading)
                                      SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: () {
                                        if (isDownloading) {
                                          ref
                                              .read(chatServiceProvider)
                                              .cancelImagePrefetch(message.id);
                                          setState(() {
                                            _inlineImageProgress
                                                .remove(message.id);
                                            _inlineImageGrants
                                                .remove(message.id);
                                          });
                                        } else {
                                          // شروع دانلود با تپ روی آیکون دانلود
                                          if (!_inlineImageGrants
                                              .contains(message.id)) {
                                            setState(() {
                                              _inlineImageGrants
                                                  .add(message.id);
                                              _inlineImageProgress[message.id] =
                                                  0.0;
                                            });
                                            ref
                                                .read(chatServiceProvider)
                                                .prefetchImageCancelable(
                                              message.id,
                                              url,
                                              (p) {
                                                if (mounted) {
                                                  setState(() {
                                                    _inlineImageProgress[
                                                        message.id] = p;
                                                  });
                                                }
                                              },
                                            ).catchError((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _inlineImageGrants
                                                      .remove(message.id);
                                                  _inlineImageProgress
                                                      .remove(message.id);
                                                });
                                              }
                                              return '';
                                            });
                                          }
                                        }
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          isDownloading
                                              ? Icons.close_rounded
                                              : Icons.download_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        });
      } else {
        imageWidget = const SizedBox.shrink();
      }

      attachmentWidget = Padding(
        padding: EdgeInsets.only(
          top: isImageOnly ? 0 : 8.0,
          left: isImageOnly ? 0 : 0 + 12,
          right: isImageOnly ? 0 : 0 + 12,
          bottom: isImageOnly ? 0 : 0,
        ),
        child: isImageOnly
            ? Stack(
                children: [
                  imageWidget,
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageHour(message.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(width: 4),
                          if (isMe) ...[
                            if (message.isPending)
                              const Icon(Icons.schedule_rounded,
                                  size: 12, color: Colors.white70)
                            else if (!message.isSent)
                              const Icon(Icons.refresh_rounded,
                                  size: 12, color: Colors.white70)
                            else
                              const Icon(Icons.done_rounded,
                                  size: 12, color: Colors.white70),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : imageWidget,
      );
    }
    // پیام موقت: رنگ متفاوت یا شفافیت
    final bool isTemp = !message.isSent && message.id.startsWith('temp_');
    final double opacity = isTemp ? 0.6 : 1.0;
    final Color? tempColor = isTemp
        ? (isMe
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
            : Colors.grey[400]?.withValues(alpha: 0.5))
        : null;

    return TweenAnimationBuilder<double>(
      duration:
          Duration(milliseconds: message.id.startsWith('temp_') ? 150 : 300),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(
            isMe ? (1 - animation) * 50 : (1 - animation) * -50,
            (1 - animation) * 10,
          ),
          child: Transform.scale(
            scale: 0.9 + (animation * 0.1),
            child: Opacity(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          // کشیدن به سمت مخالف برای فعال‌سازی پاسخ
          // پیام‌های من: کشیدن به سمت چپ (dx < 0)
          // پیام‌های دیگران: کشیدن به سمت راست (dx > 0)
          final dragDirection = isMe ? -details.delta.dx : details.delta.dx;
          if (dragDirection > 0) {
            // محاسبه فاصله کشیدن
            final dragDistance = details.globalPosition.dx;
            final screenWidth = MediaQuery.of(context).size.width;
            final maxDragDistance = screenWidth * 0.3; // حداکثر 30% عرض صفحه
            final currentDragDistance = isMe
                ? (screenWidth - dragDistance).clamp(0.0, maxDragDistance)
                : dragDistance.clamp(0.0, maxDragDistance);

            final dragRatio = currentDragDistance / maxDragDistance;

            setState(() {
              _messageReplyStates[message.id] = true;
            });

            // اگر کشیدن به اندازه کافی بود، پاسخ را فعال کن
            if (dragRatio > 0.4) {
              // آستانه 40%
              // اضافه کردن هپتیک فیدبک
              HapticFeedback.lightImpact();
              _setReplyMessage(message);
            }
          }
        },
        onHorizontalDragEnd: (details) {
          // بازگشت نرم به حالت عادی با تاخیر
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _messageReplyStates[message.id] = false;
              });
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          transform: Matrix4.translationValues(
            _messageReplyStates[message.id] == true ? (isMe ? -40 : 40) : 0,
            0,
            0,
          ),
          child: Stack(
            children: [
              // نشانگر کشیدن
              if (_messageReplyStates[message.id] == true)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: isMe ? null : 0,
                  right: isMe ? 0 : null,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                decoration: BoxDecoration(
                  color: _highlightedMessageId == message.id
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Transform.scale(
                  scale: _messageReplyStates[message.id] == true ? 1.02 : 1.0,
                  child: GestureDetector(
                    onLongPress: () =>
                        _showMessageOptions(context, message, isMe),
                    child: Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: Opacity(
                          opacity: opacity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutQuart,
                            margin: EdgeInsets.symmetric(
                                horizontal: math.max(12, fontSize * 0.6),
                                vertical: math.max(2, fontSize * 0.15)),
                            decoration: BoxDecoration(
                              color: (isImageOnly
                                  ? Colors.transparent
                                  : tempColor ??
                                      (isMe
                                          ? outgoingBubbleColor
                                          : incomingBubbleColor)),
                              border: !isMe
                                  ? Border.all(
                                      color: isLightMode
                                          ? (Colors.grey[200]!)
                                          : Colors.transparent,
                                      width: 1,
                                    )
                                  : null,
                              borderRadius:
                                  _getTelegramXBorderRadius(isMe, fontSize),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.replyToMessageId != null)
                                  Container(
                                    padding: EdgeInsets.all(
                                        math.max(8, fontSize * 0.5)),
                                    margin: EdgeInsets.only(
                                      bottom: math.max(6, fontSize * 0.35),
                                      left: math.max(8, fontSize * 0.5),
                                      right: math.max(8, fontSize * 0.5),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? outgoingBubbleColor.withValues(
                                              alpha: 0.8)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(
                                          math.max(12, fontSize * 0.7)),
                                      border: Border.all(
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.2)
                                            : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.reply,
                                                size: 14,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black45),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _getReplySenderName(message),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        FutureBuilder<String?>(
                                          future: E2EEService.instance
                                              .maybeDecryptWithSender(
                                            content:
                                                message.replyToContent ?? '',
                                            conversationId:
                                                widget.conversationId,
                                            senderId: message.senderId,
                                            messageId: message.id,
                                            userId:
                                                supabase.auth.currentUser?.id ??
                                                    '',
                                            messageCreatedAt: message.createdAt,
                                          ),
                                          builder: (context, snapshot) {
                                            final text = snapshot.data ??
                                                message.replyToContent ??
                                                '';
                                            return Text(
                                              text,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black87,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                if (message.attachmentUrl != null &&
                                    message.attachmentUrl!.isNotEmpty &&
                                    (message.attachmentType == 'image' ||
                                        message.attachmentType == 'audio'))
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top: message.replyToMessageId != null
                                            ? 4
                                            : 12,
                                        left: 12,
                                        right: 12,
                                        bottom: message.content.isNotEmpty
                                            ? 4
                                            : 12),
                                    child: Container(
                                      decoration: isImageOnly
                                          ? BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(math
                                                      .max(12, fontSize * 0.8)),
                                            )
                                          : null,
                                      child: attachmentWidget,
                                    ),
                                  ),
                                if (message.content.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: (message.attachmentUrl != null &&
                                              message.attachmentUrl!.isNotEmpty)
                                          ? math.max(4, fontSize * 0.25)
                                          : math.max(12, fontSize * 0.75),
                                      left: math.max(12, fontSize * 0.75),
                                      right: math.max(12, fontSize * 0.75),
                                      bottom: math.max(12, fontSize * 0.75),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (message.content.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: message.attachmentUrl != null
                                                  ? 8
                                                  : 0,
                                            ),
                                            child: FutureBuilder<String>(
                                              future: _decryptMessageContent(
                                                message.content,
                                                message.id,
                                                message.senderId,
                                                message.createdAt,
                                              ),
                                              builder: (context, snapshot) {
                                                final displayContent =
                                                    snapshot.data ??
                                                        message.content;
                                                return Directionality(
                                                  textDirection:
                                                      getTextDirection(
                                                          displayContent),
                                                  child: Text(
                                                    displayContent,
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? myTextColor
                                                          : otherTextColor,
                                                      fontSize: fontSize,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (!isImageOnly)
                                          Padding(
                                            padding: EdgeInsets.only(
                                                top: math.max(
                                                    6, fontSize * 0.3)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: math.max(
                                                        8, fontSize * 0.5),
                                                    vertical: math.max(
                                                        3, fontSize * 0.2),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? (isWhiteTheme &&
                                                                !isLightMode
                                                            ? Colors.black
                                                                .withValues(
                                                                    alpha: 0.2)
                                                            : Colors.black
                                                                .withValues(
                                                                    alpha:
                                                                        0.15))
                                                        : colorScheme
                                                            .surfaceContainerHighest
                                                            .withValues(
                                                                alpha: 0.7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            math.max(
                                                                12,
                                                                fontSize *
                                                                    0.8)),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.05),
                                                        blurRadius: 2,
                                                        offset:
                                                            const Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    _formatMessageHour(
                                                        message.createdAt),
                                                    style: TextStyle(
                                                      fontSize: math.max(
                                                          10, fontSize * 0.75),
                                                      color: isMe
                                                          ? myTimeColor
                                                          : otherTimeColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      letterSpacing: 0.1,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                    width: math.max(
                                                        6, fontSize * 0.3)),
                                                if (isMe) ...[
                                                  if (message.isPending)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration: BoxDecoration(
                                                        color: myTimeColor
                                                            .withValues(
                                                                alpha: 0.2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.schedule_rounded,
                                                        size: math.max(
                                                            12, fontSize * 0.8),
                                                        color: myTimeColor,
                                                      ),
                                                    )
                                                  else if (!message.isSent)
                                                    GestureDetector(
                                                      onTap: () {
                                                        ref
                                                            .read(
                                                                messageNotifierProvider
                                                                    .notifier)
                                                            .retrySendMessage(
                                                                message);
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  'درحال تلاش مجدد برای ارسال...')),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.refresh_rounded,
                                                          size: math.max(12,
                                                              fontSize * 0.8),
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration: BoxDecoration(
                                                        color: myTimeColor
                                                            .withValues(
                                                                alpha: 0.2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.done_rounded,
                                                        size: math.max(
                                                            12, fontSize * 0.8),
                                                        color: myTimeColor,
                                                      ),
                                                    ),
                                                ],
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                onTap: () async {
                  Navigator.pop(context);
                  // رمزگشایی محتوا قبل از کپی
                  final decryptedContent = await _decryptMessageContent(
                    message.content,
                    message.id,
                    message.senderId,
                    message.createdAt,
                  );
                  Clipboard.setData(ClipboardData(text: decryptedContent));
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

  // Deprecated: use viewer action with ChatService instead
  // Future<void> _downloadImage(String imageUrl, WidgetRef ref) async {}

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
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  color: Colors.white,
                  onPressed: () async {
                    if (!imageUrl.startsWith('http')) return;
                    if (kIsWeb) {
                      downloadImageOnWeb(imageUrl);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('دانلود آغاز شد')),
                        );
                      }
                      return;
                    }
                    try {
                      final chatService = ref.read(chatServiceProvider);
                      await chatService.downloadChatImage(imageUrl, (_) {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تصویر دانلود شد')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در دانلود تصویر: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            body: Center(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
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

  String _formatMessageHour(DateTime time) {
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = time.toUtc().add(tehranOffset);
    return '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';
  }

  // متدهای باقی‌مانده
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
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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

  /// Returns the appropriate chat wallpaper URL based on current theme
  String _getChatWallpaperUrl(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return WallpaperCacheService.getWallpaperUrl(isDarkMode);
  }

  /// Returns the appropriate overlay color for better text readability
  Color _getWallpaperOverlayColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.4);
  }

  /// Returns a placeholder widget while wallpaper is loading
  Widget _buildWallpaperPlaceholder(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.grey[900]!,
                  Colors.grey[800]!,
                ]
              : [
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
        ),
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

    // --- اضافه شد: گوش دادن به تغییرات استریم پیام‌ها و بروزرسانی UI ---
    ref.watch(messagesStreamProvider(widget.conversationId));

    // پیش رمزگشایی پیام‌های کش شده برای عملکرد بهتر
    ref.watch(preDecryptMessagesProvider(widget.conversationId));

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
            title: InkWell(
              onTap: () async {
                final messageIdToJump = await Navigator.push<String?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailsScreen(
                      conversationId: widget.conversationId,
                      otherUserName: widget.otherUserName,
                      otherUserAvatar: widget.otherUserAvatar,
                      otherUserId: widget.otherUserId,
                    ),
                  ),
                );

                if (messageIdToJump != null && mounted) {
                  _jumpToMessage(messageIdToJump);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Hero(
                      tag: 'avatar_${widget.otherUserId}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: ClipOval(
                          child: widget.otherUserAvatar != null &&
                                  widget.otherUserAvatar!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.otherUserAvatar!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print(
                                        'خطا در بارگذاری عکس پروفایل: $error');
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(
                                  'lib/view/util/images/default-avatar.jpg',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final isOnlineAsync = ref.watch(
                                  userOnlineStatusStreamProvider(
                                      widget.otherUserId));

                              return isOnlineAsync.when(
                                data: (isOnline) {
                                  if (isOnline) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'آنلاین',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    final canShowAsync = ref.watch(
                                        canShowLastSeenProvider(
                                            widget.otherUserId));
                                    return canShowAsync.when(
                                      data: (canShow) {
                                        if (!canShow) {
                                          return Text(
                                            'آفلاین',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          );
                                        }
                                        final lastOnlineAsync = ref.watch(
                                            userLastOnlineProvider(
                                                widget.otherUserId));
                                        return lastOnlineAsync.when(
                                          data: (lastOnline) {
                                            return Text(
                                              lastOnline != null
                                                  ? TimeUtils.formatLastSeen(
                                                      lastOnline)
                                                  : 'آفلاین',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            );
                                          },
                                          loading: () => const Text(
                                              'در حال بارگذاری...',
                                              style: TextStyle(fontSize: 12)),
                                          error: (_, __) => const Text('آفلاین',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        );
                                      },
                                      loading: () => const Text(
                                          'در حال بارگذاری...',
                                          style: TextStyle(fontSize: 12)),
                                      error: (_, __) => const Text('آفلاین',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    );
                                  }
                                },
                                loading: () => const Text('در حال بارگذاری...',
                                    style: TextStyle(fontSize: 12)),
                                error: (error, _) {
                                  print('خطا در دریافت وضعیت آنلاین: $error');
                                  return const Text('آفلاین',
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
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'پاکسازی تاریخچه گفتگو',
                onPressed: () => _showClearConversationDialog(context),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87),
                        const SizedBox(width: 12),
                        const Text('مشاهده پروفایل'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                            _isOtherUserBlocked ? Icons.lock_open : Icons.block,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87),
                        const SizedBox(width: 12),
                        Text(
                            _isOtherUserBlocked ? 'رفع مسدودیت' : 'مسدود کردن'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report_problem_outlined,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87),
                        const SizedBox(width: 12),
                        const Text('گزارش کاربر'),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
        body: Stack(
          children: [
            // Chat Wallpaper Background - Optimized with dedicated cache manager
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _getChatWallpaperUrl(context),
                fit: BoxFit.cover,
                cacheManager: CustomCacheManager.wallpaperInstance,
                placeholder: (context, url) =>
                    _buildWallpaperPlaceholder(context),
                errorWidget: (context, url, error) =>
                    _buildWallpaperPlaceholder(context),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 200),
                memCacheWidth: 1080, // بهینه‌سازی حافظه
                memCacheHeight: 1920,
              ),
            ),
            // Subtle overlay for better text readability - Adapts to theme
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _getWallpaperOverlayColor(context),
                ),
              ),
            ),
            // Chat content
            Column(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final lazyState = ref
                          .watch(lazyMessagesProvider(widget.conversationId));

                      // Show empty state if no messages
                      if (lazyState.messages.isEmpty && !lazyState.isLoading) {
                        return const Center(
                          child: Text(
                            'پیامی وجود ندارد. اولین پیام را ارسال کنید!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }

                      // Filter out temporary messages replaced by real ones
                      final realLocalIds = lazyState.messages
                          .where((m) =>
                              !m.id.startsWith('temp_') && m.localId != null)
                          .map((m) => m.localId)
                          .toSet();
                      final filteredMessages = lazyState.messages.where((m) {
                        if (m.id.startsWith('temp_') &&
                            realLocalIds.contains(m.id)) return false;
                        return true;
                      }).toList();

                      if (filteredMessages.isEmpty && !lazyState.isLoading) {
                        return const Center(
                            child: Text(
                                'پیامی وجود ندارد. اولین پیام را ارسال کنید!'));
                      }

                      return NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          // Load more messages when reaching the top
                          if (scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 200) {
                            if (lazyState.hasMore && !lazyState.isLoading) {
                              ref
                                  .read(lazyMessagesProvider(
                                          widget.conversationId)
                                      .notifier)
                                  .loadMoreMessages();
                            }
                          }
                          return false;
                        },
                        child: ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          reverse: true,
                          itemCount: filteredMessages.length +
                              (lazyState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the top
                            if (index == filteredMessages.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final message = filteredMessages[index];
                            final isMe = message.senderId ==
                                supabase.auth.currentUser?.id;
                            bool showDateDivider = false;
                            if (index == filteredMessages.length - 1) {
                              showDateDivider = true;
                            } else {
                              final prevMsg = filteredMessages[index + 1];
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
                        ),
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
                  mini: true, // دکمه کوچکتر
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
        // محدودسازی دانلود به دامنه‌های مجاز
        final uri = Uri.parse(imageUrl);
        const allowedHosts = {
          'storage.389346.ir.cdn.ir',
          'coffevista.s3.ir-thr-at1.arvanstorage.ir',
        };
        if (!allowedHosts.contains(uri.host)) {
          throw Exception('دانلود از دامنه نامجاز');
        }
        final response = await http.get(uri);
        final bytes = response.bodyBytes;
        final tmp = await getTemporaryDirectory();
        final tempPath = '${tmp.path}/shared_image.jpg';
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
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
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
    final userId = supabase.auth.currentUser!.id;
    await messageCache.cacheMessage(tempMessage, userId);

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
        tempMessage,
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
