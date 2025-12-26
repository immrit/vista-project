import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../utils/const.dart';
import '../../../provider/settings_providers.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_screen_provider.dart';
import '../../../provider/chat_provider.dart' as chat_provider;
import '../../../provider/chat_provider.dart';
import '../../../services/uploadAudioChatService.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../services/uploadImageChatService.dart';
import '../../../services/advanced_file_manager.dart';
import '../../../services/global_voice_manager.dart';
import '../../../services/wallpaper_cache_service.dart';
import '../../../services/current_chat_tracker.dart';
import 'chat_input.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../features/chat/widgets/message_bubble.dart';
import 'package:Vista/widgets/date_divider.dart';
import 'package:Vista/widgets/connection_status_widget.dart';
import 'package:Vista/widgets/typing_indicator.dart';
import '../../../widgets/reactions/reaction_picker.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'ChatDetailsScreen.dart';
import 'ChatMessageSearchScreen.dart';
import 'package:Vista/utils/time_utils.dart';
import '../../../services/toast_service.dart';
import '../../../services/typing_service.dart';
import '../../../widgets/universal_delete_animation.dart';

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
  // Controllers
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Highlight state
  String? _highlightedMessageId;

  // Message selection state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

  // Reaction picker state
  String? _reactionPickerMessageId;
  Offset? _reactionPickerPosition;

  // State
  DateTime? _floatingDate;
  Timer? _floatingDateTimer;
  late final ChatProviderParams _providerParams;
  MessageModel? _replyToMessage;

  // File handling state
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  File? _selectedFile;
  String? _selectedFileName;
  bool _showFileCaptionInput = false;
  late TextEditingController _fileCaptionController;

  // UI state
  bool _isOtherUserBlocked = false;
  bool _isCurrentUserBlocked = false;
  bool _isCacheEmpty = false;
  bool _isOtherUserTyping = false; // typing indicator state
  StreamSubscription<Set<String>>?
      _typingSubscription; // typing service subscription

  // Performance optimization
  Timer? _scrollDebounceTimer;
  Timer? _floatingDateDebounceTimer;
  Timer? _typingTimer; // timer for typing indicator
  bool _isNearBottom = true; // track if user is near bottom for auto-scroll
  Timer? _autoScrollTimer;

  // Delete animation state
  final Set<String> _deletingMessageIds = {};
  final Map<String, UniversalDeleteAnimationController>
      _deleteAnimationControllers = {};

  @override
  void initState() {
    super.initState();

    // بررسی اولیه conversationId
    if (widget.conversationId.isEmpty) {
      print('❌ ConversationId is empty in ChatScreen initState');
      return;
    }

    print('🚀 ChatScreen initState - conversationId: ${widget.conversationId}');

    _providerParams = ChatProviderParams(
      conversationId: widget.conversationId,
      otherUserId: widget.otherUserId,
    );
    _fileCaptionController = TextEditingController();
    _itemPositionsListener.itemPositions.addListener(_scrollListener);
    _checkBlockStatus();

    // ثبت مکالمه باز برای مدیریت unread
    CurrentChatTracker.instance.setOpenConversation(widget.conversationId);

    // بازنشانی تعداد پیام‌های خوانده‌نشده وقتی کاربر وارد مکالمه می‌شود
    _resetUnreadCount();

    // اتصال به سرویس تایپینگ برای نمایش نشانگر "در حال تایپ..."
    _setupTypingListener();

    // اسکرول به آخرین پیام بعد از بارگذاری اولیه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = ref.read(chatScreenProvider(_providerParams)).messages;
      if (messages.isNotEmpty) {
        _scrollToLatestMessage();
      } else {
        // اگر هیچ پیامی نیست، چک کن که آیا کش کار می‌کنه یا نه
        _checkCacheEmpty();
      }
    });
  }

  Future<void> _checkBlockStatus() async {
    try {
      final chatService = ref.read(chat_provider.chatServiceProvider);
      final isBlocked = await chatService.isUserBlocked(widget.otherUserId);
      final isCurrentUserBlocked = await chatService.isCurrentUserBlockedBy(
        widget.otherUserId,
      );
      if (mounted) {
        setState(() {
          _isOtherUserBlocked = isBlocked;
          _isCurrentUserBlocked = isCurrentUserBlocked;
        });
      }
    } catch (e) {
      print('خطا در بررسی وضعیت مسدودیت: $e');
    }
  }

  /// راه‌اندازی گوش‌دهنده برای نشانگر تایپ کردن
  void _setupTypingListener() {
    final typingService = TypingService();
    _typingSubscription = typingService
        .getTypingStream(widget.conversationId)
        .listen((typingUsers) {
      if (mounted) {
        final isOtherTyping = typingUsers.contains(widget.otherUserId);
        if (_isOtherUserTyping != isOtherTyping) {
          setState(() {
            _isOtherUserTyping = isOtherTyping;
          });
        }
      }
    });
  }

  // Message selection methods
  void _toggleMessageSelection(String messageId) {
    final wasInSelectionMode = _isSelectionMode;
    final previousCount = _selectedMessageIds.length;

    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
        _isSelectionMode = true;
      }

      // اگر قبلاً در selection mode بودیم و حالا پیام دوم یا بیشتر انتخاب شد، reaction picker را ببند
      if (wasInSelectionMode &&
          _isSelectionMode &&
          _selectedMessageIds.length > previousCount &&
          _selectedMessageIds.length > 1) {
        _hideReactionPicker();
      }
    });
  }

  // Show reaction picker at specific position
  void _showReactionPicker(String messageId, Offset position) {
    setState(() {
      _reactionPickerMessageId = messageId;
      _reactionPickerPosition = position;
    });
  }

  // Hide reaction picker
  void _hideReactionPicker() {
    setState(() {
      _reactionPickerMessageId = null;
      _reactionPickerPosition = null;
    });
  }

  void _clearMessageSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _isSelectionMode = false;
      _hideReactionPicker(); // بستن reaction picker هنگام پاک کردن selection
    });
  }

  void _showMessageActionsBottomSheet(
      BuildContext context, MessageModel message) {
    final isMe = message.senderId == supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Options
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.reply,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                title: const Text('پاسخ'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyMessage(message);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy, color: Colors.blue, size: 20),
                ),
                title: const Text('کپی پیام'),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: message.content));
                  ToastService.showSuccessToast(context, 'پیام کپی شد');
                },
              ),
              if (message.attachmentType == 'document' ||
                  message.attachmentType == 'image')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: Colors.green, size: 20),
                  ),
                  title: const Text('ذخیره فایل'),
                  onTap: () {
                    Navigator.pop(context);
                    if (message.attachmentUrl != null) {
                      // فراخوانی متد ذخیره فایل
                      _saveFile(message);
                    }
                  },
                ),
              if (isMe)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.delete, color: Colors.red, size: 20),
                  ),
                  title: const Text('حذف پیام'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteMessageDialog(message);
                  },
                ),
              if (!isMe)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.report,
                        color: Colors.orange, size: 20),
                  ),
                  title: const Text('گزارش پیام'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportMessageDialog(context, message);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _saveFile(MessageModel message) {
    // Implementation for saving file
    ToastService.showInfoToast(context, 'در حال ذخیره فایل...');
  }

  void _showReportMessageDialog(BuildContext context, MessageModel message) {
    ToastService.showInfoToast(
        context, 'قابلیت گزارش پیام به زودی اضافه می‌شود');
  }

  void _showDeleteMessageDialog(MessageModel message) async {
    final isSender = message.senderId == supabase.auth.currentUser?.id;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پیام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('پیام را چگونه می‌خواهید حذف کنید؟'),
            if (isSender) ...[
              const SizedBox(height: 8),
              Text(
                'توجه: حذف برای همه قابل بازگشت نیست.',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message.id, false);
            },
            child: const Text('حذف برای من'),
          ),
          if (isSender)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(message.id, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
              child: const Text('حذف برای همه'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    try {
      // ✅ شروع انیمیشن حذف
      setState(() {
        _deletingMessageIds.add(messageId);
      });

      // اجرای انیمیشن پودر شدن
      final controller = _deleteAnimationControllers[messageId];
      if (controller != null) {
        await controller.startDeleteAnimation();
        // صبر کوتاه برای اتمام انیمیشن
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // حذف واقعی پیام
      await ref
          .read(chatScreenProvider(_providerParams).notifier)
          .deleteMessage(messageId, forEveryone: forEveryone);

      // پاکسازی state
      if (mounted) {
        setState(() {
          _deletingMessageIds.remove(messageId);
          _deleteAnimationControllers.remove(messageId);
        });
      }

      ToastService.showSuccessToast(
        context,
        forEveryone ? 'پیام برای همه حذف شد' : 'پیام برای شما حذف شد',
      );
    } catch (e) {
      // در صورت خطا، state را پاکسازی کن
      if (mounted) {
        setState(() {
          _deletingMessageIds.remove(messageId);
        });
      }
      ToastService.showErrorToast(
          context, 'خطا در حذف پیام. لطفاً دوباره تلاش کنید.');
    }
  }

  void _showMultiSelectOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.forward, color: Colors.blue, size: 20),
                ),
                title: const Text('فوروارد پیام‌ها'),
                onTap: () {
                  Navigator.pop(context);
                  _forwardSelectedMessages();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red, size: 20),
                ),
                title: const Text('حذف پیام‌ها'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteSelectedMessagesDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline,
                      color: Colors.grey[600], size: 20),
                ),
                title: const Text('اطلاعات پیام‌ها'),
                onTap: () {
                  Navigator.pop(context);
                  _showSelectedMessagesInfo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _forwardSelectedMessages() {
    // Implementation for forwarding selected messages
    // For now, just show a message that this feature is coming soon
    ToastService.showInfoToast(context,
        'فوروارد ${_selectedMessageIds.length} پیام در حال پیاده‌سازی...');
    _clearMessageSelection();
  }

  void _showDeleteSelectedMessagesDialog() {
    final messages = ref.read(chatScreenProvider(_providerParams)).messages;
    final selectedMessages =
        messages.where((msg) => _selectedMessageIds.contains(msg.id)).toList();
    final myMessages = selectedMessages
        .where((msg) => msg.senderId == supabase.auth.currentUser?.id)
        .toList();
    final otherMessages = selectedMessages
        .where((msg) => msg.senderId != supabase.auth.currentUser?.id)
        .toList();

    final hasOnlyMyMessages = otherMessages.isEmpty;
    final hasMixedMessages = myMessages.isNotEmpty && otherMessages.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پیام‌ها'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'آیا مطمئن هستید که می‌خواهید ${_selectedMessageIds.length} پیام انتخاب شده را حذف کنید؟'),
            if (hasOnlyMyMessages) ...[
              const SizedBox(height: 8),
              Text(
                'توجه: حذف برای همه قابل بازگشت نیست.',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
            if (hasMixedMessages) ...[
              const SizedBox(height: 8),
              Text(
                'پیام‌های انتخاب شده شامل پیام‌های شما و طرف مقابل است.',
                style: TextStyle(color: Colors.orange[700], fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedMessages(false);
            },
            child: const Text('حذف برای من'),
          ),
          if (hasOnlyMyMessages)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteSelectedMessages(true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
              child: const Text('حذف برای همه'),
            ),
        ],
      ),
    );
  }

  void _deleteSelectedMessages(bool forEveryone) async {
    try {
      final chatService = ref.read(chat_provider.chatServiceProvider);
      final messageIdsToDelete = Set<String>.from(_selectedMessageIds);

      // ✅ شروع انیمیشن حذف برای همه پیام‌های انتخاب شده
      setState(() {
        _deletingMessageIds.addAll(messageIdsToDelete);
      });

      // اجرای انیمیشن‌ها به صورت موازی
      await Future.wait(
        messageIdsToDelete.map((messageId) async {
          final controller = _deleteAnimationControllers[messageId];
          if (controller != null) {
            await controller.startDeleteAnimation();
          }
        }),
      );

      // صبر کوتاه برای اتمام انیمیشن‌ها
      await Future.delayed(const Duration(milliseconds: 100));

      // حذف واقعی پیام‌ها
      for (final messageId in messageIdsToDelete) {
        await chatService.deleteMessage(messageId, forEveryone: forEveryone);
      }

      // پاکسازی state
      if (mounted) {
        setState(() {
          for (final messageId in messageIdsToDelete) {
            _deletingMessageIds.remove(messageId);
            _deleteAnimationControllers.remove(messageId);
          }
        });
      }

      ToastService.showSuccessToast(
          context,
          forEveryone
              ? '${_selectedMessageIds.length} پیام برای همه حذف شد'
              : '${_selectedMessageIds.length} پیام برای شما حذف شد');
      _clearMessageSelection();

      // Refresh the conversation list to update last message
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);

      // Refresh the current chat screen
      ref.invalidate(chatScreenProvider(_providerParams));
    } catch (e) {
      // در صورت خطا، state را پاکسازی کن
      if (mounted) {
        setState(() {
          _deletingMessageIds.clear();
        });
      }
      ToastService.showErrorToast(context, 'خطا در حذف پیام‌ها');
    }
  }

  void _showSelectedMessagesInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اطلاعات پیام‌های انتخاب شده'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعداد پیام‌های انتخاب شده: ${_selectedMessageIds.length}'),
            const SizedBox(height: 8),
            Text('این قابلیت در حال پیاده‌سازی است.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetUnreadCount() async {
    try {
      final chatService = ref.read(chat_provider.chatServiceProvider);
      await chatService.resetUnreadCount(
          widget.conversationId, supabase.auth.currentUser!.id);
      print('✅ Unread count reset for conversation: ${widget.conversationId}');
    } catch (e) {
      print('خطا در بازنشانی تعداد خوانده‌نشده: $e');
    }
  }

  void _scrollListener() {
    // استفاده از debouncing برای بهبود performance
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      try {
        final positions = _itemPositionsListener.itemPositions.value;
        if (positions.isEmpty) return;

        final firstPosition = positions.first;
        if (firstPosition.index <= 5) {
          ref
              .read(chatScreenProvider(_providerParams).notifier)
              .fetchMoreMessages();
        }

        // Check if user is near bottom (within 3 messages)
        final messages = ref.read(chatScreenProvider(_providerParams)).messages;
        _isNearBottom = firstPosition.index >= (messages.length - 3);

        _updateFloatingDate(positions);
      } catch (e) {
        debugPrint('❌ Scroll listener error: $e');
      }
    });
  }

  void _updateFloatingDate(Iterable<ItemPosition> positions) {
    if (!mounted) return;

    // استفاده از debouncing برای floating date updates
    _floatingDateDebounceTimer?.cancel();
    _floatingDateDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      try {
        final firstVisibleItemIndex = positions
            .where((position) => position.itemLeadingEdge < 1)
            .last
            .index;

        final messages = ref.read(chatScreenProvider(_providerParams)).messages;
        if (firstVisibleItemIndex >= 0 &&
            firstVisibleItemIndex < messages.length) {
          final messageDate = messages[firstVisibleItemIndex].createdAt;
          if (_floatingDate == null ||
              !_isSameDay(_floatingDate!, messageDate)) {
            // استفاده از SchedulerBinding برای بهینه‌سازی performance
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _floatingDate = messageDate;
                });
              }
            });
          }
        }

        _floatingDateTimer?.cancel();
        _floatingDateTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _floatingDate = null;
                });
              }
            });
          }
        });
      } catch (e) {
        debugPrint('❌ Floating date update error: $e');
      }
    });
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return TimeUtils.isSameDay(d1, d2);
  }

  void _setReplyMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
      // Focus logic is now handled inside ChatInput
    });
  }

  void _retryFailedMessage(MessageModel message) {
    print('🔄 تلاش مجدد برای ارسال پیام: ${message.id}');

    HapticFeedback.lightImpact();

    // بررسی نوع پیام
    if (message.attachmentType == 'image' && message.localImagePath != null) {
      // اگر تصویر است و مسیر محلی دارد
      final imageFile = File(message.localImagePath!);

      if (imageFile.existsSync()) {
        print('✅ فایل محلی یافت شد، شروع ارسال مجدد...');

        // ابتدا پیام قدیمی را حذف کن
        ref
            .read(chatScreenProvider(_providerParams).notifier)
            .removePendingMessage(message.id);

        // سپس دوباره ارسال کن
        _sendImageMessage(imageFile, message.content);
      } else {
        print('❌ فایل محلی یافت نشد');
        ToastService.showErrorToast(
          context,
          'فایل محلی یافت نشد. لطفاً تصویر را دوباره انتخاب کنید.',
        );
        return;
      }
    } else {
      // برای سایر انواع پیام‌ها
      ref
          .read(chat_provider.messageNotifierProvider.notifier)
          .retrySendMessage(message);
    }

    ToastService.showInfoToast(context, 'در حال تلاش مجدد...');
  }

  void _retryAllFailedMessages() {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // دریافت تمام پیام‌های ناموفق از chatScreenProvider
    final messages = ref.read(chatScreenProvider(_providerParams)).messages;
    final failedMessages =
        messages.where((msg) => !msg.isSent && msg.isMe).toList();

    if (failedMessages.isEmpty) {
      ToastService.showInfoToast(
          context, 'پیام ناموفقی برای ارسال مجدد وجود ندارد');
      return;
    }

    // تلاش مجدد برای تمام پیام‌های ناموفق
    for (final message in failedMessages) {
      ref
          .read(chat_provider.messageNotifierProvider.notifier)
          .retrySendMessage(message);
    }

    // نمایش پیام موفقیت
    ToastService.showInfoToast(
      context,
      'در حال تلاش مجدد برای ${failedMessages.length} پیام ناموفق...',
    );
  }

  @override
  void dispose() {
    print(
      '🗑️ Disposing ChatScreen for conversation: ${widget.conversationId}',
    );

    // توقف تمام وویس‌های در حال پخش
    _stopAllVoicePlayback();

    // پاکسازی timers
    _floatingDateTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _floatingDateDebounceTimer?.cancel();
    _typingTimer?.cancel();
    _autoScrollTimer?.cancel();
    _typingSubscription?.cancel(); // پاکسازی اشتراک سرویس تایپ
    _fileCaptionController.dispose();

    // پاک کردن وضعیت مکالمه باز
    CurrentChatTracker.instance.clearOpenConversation();

    super.dispose();
  }

  /// توقف تمام وویس‌های در حال پخش
  void _stopAllVoicePlayback() {
    try {
      // توقف تمام وویس‌ها از طریق GlobalVoiceManager
      final voiceManager = GlobalVoiceManager();
      voiceManager.stopCurrentVoice();
      print(
          '🔇 Stopped all voice playback for conversation: ${widget.conversationId}');
    } catch (e) {
      print('⚠️ Error stopping voice playback: $e');
    }
  }

  // --- Message Sending Logic ---
  Future<void> _sendMessage(String message) async {
    if (message.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null) {
      return;
    }

    setState(() {});

    String? attachmentUrl;
    String? attachmentType;

    try {
      if (_selectedImage != null || _selectedImageBytes != null) {
        attachmentType = 'image';
        attachmentUrl = await _uploadImage(
          _selectedImage ?? _selectedImageBytes!,
        );
      }

      if (attachmentUrl == null && message.isEmpty) {
        setState(() {});
        return;
      }

      await ref.read(chatScreenProvider(_providerParams).notifier).sendMessage(
            message,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            replyToMessage: _replyToMessage,
          );

      _clearAttachments();
      _autoScrollToBottom();

      // اگر قبلاً کش خالی بود، حالا که پیام فرستادیم، چک کن که آیا کش پر شده یا نه
      if (_isCacheEmpty) {
        setState(() {
          _isCacheEmpty = false;
        });
      }

      // بروزرسانی لیست مکالمات برای نمایش آخرین پیام
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      // برای StateNotifier، refresh method فراخوانی کنیم
      ref.read(cachedConversationsProvider.notifier).refresh();
    } catch (e) {
      ToastService.showErrorToast(
          context, 'خطا در ارسال پیام. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendVoiceMessage(File audioFile) async {
    setState(() {});
    try {
      print("🎙️ شروع ارسال پیام صوتی: ${audioFile.path}");

      // نمایش پیام در حال ارسال
      ToastService.showInfoToast(context, 'در حال ارسال پیام صوتی...');

      final audioUrl = await _uploadAudio(audioFile);
      if (audioUrl != null) {
        print("✅ فایل صوتی آپلود شد: $audioUrl");

        // محاسبه مدت زمان فایل صوتی
        final duration = await _getAudioDuration(audioFile);
        print("🎵 مدت زمان فایل: $duration ثانیه");

        await ref
            .read(chatScreenProvider(_providerParams).notifier)
            .sendMessage(
              '', // Voice messages have no text content
              attachmentUrl: audioUrl,
              attachmentType: 'audio',
              duration: duration, // فعال کردن duration برای وویس
              replyToMessage: _replyToMessage,
            );

        print("✅ پیام صوتی ارسال شد");
        _clearAttachments();
        _autoScrollToBottom();

        // اگر قبلاً کش خالی بود، حالا که پیام فرستادیم، چک کن که آیا کش پر شده یا نه
        if (_isCacheEmpty) {
          setState(() {
            _isCacheEmpty = false;
          });
        }

        // بروزرسانی لیست مکالمات برای نمایش آخرین پیام
        ref.invalidate(conversationsProvider);
        ref.invalidate(conversationsStreamProvider);
        ref.invalidate(cachedConversationsStreamProvider);

        // نمایش پیام موفقیت
        ToastService.showSuccessToast(context, 'پیام صوتی با موفقیت ارسال شد');
      } else {
        throw Exception('آپلود فایل صوتی ناموفق بود');
      }
    } catch (e) {
      print('❌ خطا در ارسال پیام صوتی: $e');
      ToastService.showErrorToast(
          context, 'خطا در ارسال پیام صوتی. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// محاسبه مدت زمان فایل صوتی
  Future<int?> _getAudioDuration(File audioFile) async {
    try {
      print('🎵 محاسبه مدت زمان فایل: ${audioFile.path}');

      // استفاده از audio_waveforms برای محاسبه مدت زمان
      final playerController = PlayerController();
      await playerController.preparePlayer(path: audioFile.path);

      // انتظار برای بارگذاری کامل فایل
      await Future.delayed(const Duration(milliseconds: 500));

      // استفاده از onCurrentDurationChanged stream
      int? durationMs;
      final subscription = playerController.onCurrentDurationChanged.listen((
        duration,
      ) {
        durationMs = duration;
      });

      // انتظار برای دریافت duration
      await Future.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();
      playerController.dispose();

      final durationSeconds = durationMs != null ? durationMs! ~/ 1000 : null;
      print('🎵 مدت زمان محاسبه شده: $durationSeconds ثانیه');

      return durationSeconds;
    } catch (e) {
      print('❌ خطا در محاسبه مدت زمان: $e');
      // در صورت خطا، مدت زمان پیش‌فرض برگردان
      return 0;
    }
  }

  // --- GIF Handling ---
  Future<void> _sendGifMessage(String gifUrl) async {
    print("🟢 ChatScreen: _sendGifMessage CALLED with: $gifUrl");
    setState(() {}); // رفرش UI

    try {
      // ساخت پیام جدید
      // نکته: اگر از مدل‌های جدید استفاده می‌کنید مطمئن شوید attachmentType درست است
      await ref.read(chatScreenProvider(_providerParams).notifier).sendMessage(
            '', // محتوای متنی خالی
            attachmentUrl: gifUrl,
            attachmentType: 'gif', // ✅ بسیار مهم: نوع پیام باید gif باشد
            replyToMessage: _replyToMessage,
          );

      print("🟢 ChatScreen: GIF Sent Successfully!");

      _clearAttachments();
      _autoScrollToBottom();

      // آپدیت لیست مکالمات
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      ref.read(cachedConversationsProvider.notifier).refresh();

      // نمایش پیام موفقیت
      ToastService.showSuccessToast(context, 'گیف با موفقیت ارسال شد');
    } catch (e) {
      print('❌ ChatScreen Error sending GIF: $e');
      ToastService.showErrorToast(
          context, 'خطا در ارسال گیف. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _clearAttachments() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedFile = null;
      _selectedFileName = null;
      _showFileCaptionInput = false;
      _fileCaptionController.clear();
      _replyToMessage = null;
    });
  }

  // --- File Handling ---

  Future<String?> _uploadImage(dynamic fileOrBytes) async {
    setState(() {});

    try {
      String? imageUrl;
      if (kIsWeb && fileOrBytes is Uint8List && _selectedImageName != null) {
        imageUrl = await ChatImageUploadService.uploadChatImageWeb(
          fileOrBytes,
          _selectedImageName!,
          widget.conversationId,
        );
      } else if (fileOrBytes is File) {
        // استفاده از AdvancedFileManager برای آپلود تصویر
        imageUrl = await AdvancedFileManager.instance.uploadFile(
          fileOrBytes,
          widget.conversationId,
          fileType: 'image',
          onProgress: (progress) {
            if (mounted) {
              // می‌توان در آینده پیشرفت را در UI نمایش داد
              debugPrint('Image upload progress: ${(progress * 100).toInt()}%');
            }
          },
        );
      }
      return imageUrl;
    } catch (e) {
      ToastService.showErrorToast(
          context, 'خطا در آپلود تصویر. لطفاً دوباره تلاش کنید.');
      return null;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<String?> _uploadAudio(dynamic fileOrBytes) async {
    setState(() {});
    try {
      String? audioUrl;
      if (kIsWeb && fileOrBytes is Uint8List && _selectedImageName != null) {
        audioUrl = await ChatAudioUploadService.uploadChatAudioWeb(
          fileOrBytes,
          _selectedImageName!,
          widget.conversationId,
        );
      } else if (fileOrBytes is File) {
        audioUrl = await ChatAudioUploadService.uploadChatAudio(
          fileOrBytes,
          widget.conversationId,
          onProgress: (progress) {
            if (mounted) {
              setState(() {});
            }
          },
        );
      }
      return audioUrl;
    } catch (e) {
      ToastService.showErrorToast(
          context, 'خطا در آپلود صدا. لطفاً دوباره تلاش کنید.');
      return null;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  // --- UI Methods ---
  void _scrollToBottom() {
    if (_itemScrollController.isAttached) {
      final messages = ref.read(chatScreenProvider(_providerParams)).messages;
      if (messages.isNotEmpty) {
        print(
            '📱 Scrolling to bottom - messages count: ${messages.length}, newest message: ${messages.first.content}');
        _itemScrollController.scrollTo(
          index: 0, // اولین پیام در لیست مرتب‌شده (جدیدترین)
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _scrollToLatestMessage() {
    // اسکرول به آخرین پیام بعد از بارگذاری
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _autoScrollToBottom() {
    // Auto-scroll only if user is near bottom
    if (_isNearBottom) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  Future<void> _checkCacheEmpty() async {
    try {
      // چک کن که آیا کش خالیه یا نه
      await ref
          .read(chatScreenProvider(_providerParams).notifier)
          .fetchLatestMessages();

      // اگر هنوز هیچ پیامی نیست، احتمالاً کش خالیه
      final messages = ref.read(chatScreenProvider(_providerParams)).messages;
      if (messages.isEmpty) {
        setState(() {
          _isCacheEmpty = true;
        });

        // کش باید از سرور پر شده باشه، این اسنک بار رو حذف کردیم
        // چون کاربر نباید مجبور بشه پیام بفرسته تا کش فعال بشه
      }
    } catch (e) {
      print('خطا در چک کردن وضعیت کش: $e');
    }
  }

  void _showBlockUserDialog(BuildContext context) {
    final isBlocked = _isOtherUserBlocked;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isBlocked
              ? 'رفع مسدودیت ${widget.otherUserName}'
              : 'مسدود کردن ${widget.otherUserName}',
        ),
        content: Text(
          isBlocked
              ? 'آیا از رفع مسدودیت ${widget.otherUserName} اطمینان دارید؟'
              : 'آیا از مسدود کردن ${widget.otherUserName} اطمینان دارید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final notifier = ref.read(
                  chat_provider.userBlockNotifierProvider.notifier,
                );

                if (isBlocked) {
                  await notifier.unblockUser(widget.otherUserId);
                } else {
                  await notifier.blockUser(widget.otherUserId);
                }

                await _checkBlockStatus();

                ToastService.showSuccessToast(
                  context,
                  isBlocked
                      ? '${widget.otherUserName} با موفقیت رفع مسدودیت شد'
                      : '${widget.otherUserName} با موفقیت مسدود شد',
                );
              } catch (e) {
                ToastService.showErrorToast(
                  context,
                  isBlocked
                      ? 'خطا در رفع مسدودیت کاربر. لطفاً دوباره تلاش کنید.'
                      : 'خطا در مسدود کردن کاربر. لطفاً دوباره تلاش کنید.',
                );
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
      'سایر موارد',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isLightMode ? Colors.white : const Color(0xFF1A1A1A),
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
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color:
                      isLightMode ? Colors.grey[100] : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  dropdownColor:
                      isLightMode ? Colors.white : const Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  style: TextStyle(
                    color: isLightMode ? Colors.black87 : Colors.white,
                  ),
                  items: reportReasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
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
              const SizedBox(height: 16),
              Text(
                'توضیحات بیشتر:',
                style: TextStyle(
                  color: isLightMode ? Colors.black87 : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reportReasonController,
                decoration: InputDecoration(
                  hintText: 'توضیحات اختیاری...',
                  filled: true,
                  fillColor:
                      isLightMode ? Colors.grey[100] : const Color(0xFF2A2A2A),
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
                    .read(chat_provider.userReportNotifierProvider.notifier)
                    .reportUser(
                      userId: widget.otherUserId,
                      reason: selectedReason,
                      additionalInfo:
                          additionalInfo.isEmpty ? null : additionalInfo,
                    )
                    .then((_) {
                  ToastService.showSuccessToast(
                      context, 'گزارش شما با موفقیت ارسال شد');
                }).catchError((error) {
                  ToastService.showErrorToast(
                      context, 'خطا در ارسال گزارش. لطفاً دوباره تلاش کنید.');
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

  void _showSearchMessagesDialog(BuildContext context) async {
    final messageId = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (context) => ChatMessageSearchScreen(
          conversationId: widget.conversationId,
          otherUserName: widget.otherUserName,
          otherUserAvatar: widget.otherUserAvatar,
          otherUserId: widget.otherUserId,
        ),
      ),
    );

    if (messageId != null && mounted) {
      _jumpToMessage(messageId);
    }
  }

  void _jumpToMessage(String messageId) {
    final messages = ref.read(chatScreenProvider(_providerParams)).messages;
    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);

    if (messageIndex != -1) {
      // Scroll to the message with animation
      _itemScrollController.scrollTo(
        index: messageIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // Show a brief highlight effect
      _highlightMessage(messageId);

      ToastService.showSuccessToast(context, 'پرش به پیام انجام شد');
    } else {
      ToastService.showWarningToast(context, 'پیام مورد نظر یافت نشد');
    }
  }

  void _highlightMessage(String messageId) {
    // Add a brief highlight effect to the message
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Remove highlight after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _showClearHistoryDialog(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : const Color(0xFF1A1A1A),
        title: Text(
          'پاکسازی تاریخچه',
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از پاکسازی تاریخچه این گفتگو اطمینان دارید؟',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'گزینه‌های پاکسازی:',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text('فقط برای من'),
              subtitle: const Text('تاریخچه فقط برای شما پاک می‌شود'),
              onTap: () {
                Navigator.pop(context);
                _clearHistory(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Colors.red),
              title: const Text('برای همه'),
              subtitle: const Text('تاریخچه برای همه شرکت‌کنندگان پاک می‌شود'),
              onTap: () {
                Navigator.pop(context);
                _clearHistory(true);
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
        ],
      ),
    );
  }

  Future<void> _clearHistory(bool forEveryone) async {
    try {
      final chatService = ref.read(chat_provider.chatServiceProvider);
      await chatService.clearConversation(
        widget.conversationId,
        bothSides: forEveryone,
      );

      // پاکسازی فوری از UI
      ref.read(chatScreenProvider(_providerParams).notifier).clearAllMessages();

      ToastService.showSuccessToast(
        context,
        forEveryone ? 'تاریخچه برای همه پاک شد' : 'تاریخچه برای شما پاک شد',
      );
    } catch (e) {
      ToastService.showErrorToast(
          context, 'خطا در پاکسازی تاریخچه. لطفاً دوباره تلاش کنید.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // بررسی اولیه conversationId
    if (widget.conversationId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطا')),
        body: const Center(child: Text('شناسه مکالمه نامعتبر است')),
      );
    }

    // ✅ بهینه‌سازی: استفاده از select برای کاهش rebuild های غیرضروری
    final messages = ref.watch(
      chatScreenProvider(_providerParams).select((state) => state.messages),
    );
    // ✅ Pre-calculate message map for O(1) lookups
    // This prevents O(N) search inside each item build (O(N^2) total)
    final messageMap = {for (var m in messages) m.id: m};
    final isLoading = ref.watch(
      chatScreenProvider(_providerParams).select((state) => state.isLoading),
    );

    // دریافت تنظیم بلور پس‌زمینه
    final isBlurEnabled = ref.watch(chatBlurBackgroundProvider);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // تشخیص تم مشکی مطلق (AMOLED)
    final isPitchBlack =
        Theme.of(context).scaffoldBackgroundColor.value == 0xFF000000;

    // محاسبه نهایی - بلور در هر دو تم روشن و تاریک (به جز تم مشکی مطلق)
    final shouldShowBlur = isBlurEnabled && !isPitchBlack;

    return Stack(
      children: [
        // Chat Wallpaper Background
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // استفاده از تصویر محلی به عنوان پس‌زمینه اصلی
              Image.asset(
                WallpaperCacheService.getLocalWallpaperAsset(isDarkTheme),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              // افکت بلور - در هر دو تم روشن و تاریک (به جز تم مشکی مطلق)
              if (shouldShowBlur)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5.0,
                      sigmaY: 5.0,
                    ),
                    child: Container(
                      // رنگ لایه رویی بلور - متناسب با تم
                      color: isDarkTheme
                          ? Colors.black.withOpacity(0.2)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Main chat interface
        Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          // ✅ فعال کردن اسکرول پیام‌ها از پشت app bar
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 1,
            backgroundColor: isDarkTheme
                ? const Color(0xFF1A1A1A).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
            titleSpacing: 0,
            title: _isSelectionMode
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedMessageIds.length}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'انتخاب شده',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : InkWell(
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
                        // TODO: Implement jump to message functionality
                        print('Jump to message: $messageIdToJump');
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: widget.otherUserAvatar != null
                              ? CachedNetworkImageProvider(
                                  widget.otherUserAvatar!)
                              : null,
                          child: widget.otherUserAvatar == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.otherUserName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Consumer(
                                builder: (context, ref, child) {
                                  final isOnlineAsync = ref.watch(
                                    chat_provider
                                        .userOnlineStatusStreamProvider(
                                      widget.otherUserId,
                                    ),
                                  );

                                  return isOnlineAsync.when(
                                    data: (isOnline) {
                                      return Text(
                                        isOnline ? 'آنلاین' : 'آفلاین',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOnline
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      );
                                    },
                                    loading: () => const Text(
                                      'در حال بارگذاری...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    error: (_, __) => const Text(
                                      'آفلاین',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            actions: _isSelectionMode
                ? [
                    // Selection mode actions
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: IconButton(
                        onPressed: _showMultiSelectOptions,
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'گزینه‌های بیشتر',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: IconButton(
                        onPressed: _clearMessageSelection,
                        icon: const Icon(Icons.close),
                        tooltip: 'لغو انتخاب',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ]
                : [
                    // Normal mode actions
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'گزینه‌های بیشتر',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'search':
                            _showSearchMessagesDialog(context);
                            break;
                          case 'clear_history':
                            _showClearHistoryDialog(context);
                            break;
                          case 'block':
                            _showBlockUserDialog(context);
                            break;
                          case 'report':
                            _showReportUserDialog(context);
                            break;
                          case 'profile':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: widget.otherUserId,
                                  username: widget.otherUserName,
                                ),
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'search',
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text('جستجو در پیام‌ها'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'clear_history',
                          child: Row(
                            children: [
                              Icon(
                                Icons.clear_all,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text('پاکسازی تاریخچه'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
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
                                _isOtherUserBlocked
                                    ? Icons.lock_open
                                    : Icons.block,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isOtherUserBlocked
                                    ? 'رفع مسدودیت'
                                    : 'مسدود کردن',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(
                                Icons.report_problem_outlined,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text('گزارش کاربر'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
          body: GestureDetector(
            onTap: () {
              // Clear focus from text fields when tapping outside
              FocusScope.of(context).unfocus();
              // Clear message selection if in selection mode
              if (_isSelectionMode) {
                _clearMessageSelection();
              }
            },
            // بهینه‌سازی برای keyboard handling
            behavior:
                HitTestBehavior.opaque, // استفاده از opaque برای عملکرد بهتر
            child: Column(children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    isLoading && messages.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty && !isLoading
                            ? const Center(child: Text('پیامی یافت نشد'))
                            : ScrollablePositionedList.builder(
                                itemScrollController: _itemScrollController,
                                itemPositionsListener: _itemPositionsListener,
                                reverse: true,
                                // بهینه‌سازی: استفاده از physics بهینه برای اسکرول روان
                                physics: const ClampingScrollPhysics(),
                                // ✅ بهینه‌سازی‌های performance:
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                addSemanticIndexes: false,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final prevMessage =
                                      index < messages.length - 1
                                          ? messages[index + 1]
                                          : null;
                                  final nextMessage =
                                      index > 0 ? messages[index - 1] : null;

                                  // اصلاح replyToSenderName اگر null یا 'کاربر' است
                                  MessageModel correctedMessage = message;
                                  if (message.replyToMessageId != null &&
                                      (message.replyToSenderName == null ||
                                          message.replyToSenderName!.isEmpty ||
                                          message.replyToSenderName ==
                                              'کاربر')) {
                                    // جستجو در کل لیست پیام‌ها برای پیدا کردن پیام ریپلای شده
                                    // جستجو در map (O(1)) به جای لیست (O(N))
                                    final repliedMessage =
                                        messageMap[message.replyToMessageId] ??
                                            MessageModel.empty();

                                    if (repliedMessage.id.isNotEmpty &&
                                        repliedMessage.senderName != null &&
                                        repliedMessage.senderName!.isNotEmpty) {
                                      correctedMessage = message.copyWith(
                                        replyToSenderName:
                                            repliedMessage.senderName,
                                      );
                                    }
                                  }

                                  // بررسی نمایش date divider (از message اصلی استفاده می‌کنیم)
                                  final showDateDivider =
                                      TimeUtils.shouldShowDateDivider(
                                    correctedMessage.createdAt,
                                    prevMessage?.createdAt,
                                  );

                                  // محاسبه spacing و radius برای bubble (از message اصلی استفاده می‌کنیم)
                                  final spacing =
                                      TimeUtils.calculateMessageSpacing(
                                    correctedMessage.createdAt,
                                    prevMessage?.createdAt,
                                    correctedMessage.senderId,
                                    prevMessage?.senderId,
                                  );

                                  // ✅ ایجاد کنترلر انیمیشن حذف برای این پیام
                                  _deleteAnimationControllers.putIfAbsent(
                                    correctedMessage.id,
                                    () => UniversalDeleteAnimationController(),
                                  );

                                  // ✅ ساخت پیام با انیمیشن حذف پودری
                                  final messageWidget = Column(
                                    children: [
                                      if (showDateDivider)
                                        DateDivider(
                                          date: correctedMessage.createdAt,
                                        ),
                                      SizedBox(height: spacing),
                                      // ✅ اضافه کردن RepaintBoundary برای بهینه‌سازی render
                                      RepaintBoundary(
                                        child: MessageBubble(
                                          message:
                                              correctedMessage, // استفاده از پیام اصلاح شده
                                          isHighlighted:
                                              _highlightedMessageId ==
                                                  correctedMessage.id,
                                          isSelected: _selectedMessageIds
                                              .contains(correctedMessage.id),
                                          previousMessage: prevMessage,
                                          nextMessage: nextMessage,
                                          currentUserId:
                                              supabase.auth.currentUser?.id,
                                          conversationId: widget.conversationId,
                                          isSelectionMode: _isSelectionMode,
                                          onShowReactionPicker:
                                              _showReactionPicker,
                                          onLongPress: (msg) {
                                            // اگر در selection mode هستیم و این پیام قبلاً select نشده، فقط select کن
                                            // اگر در selection mode نیستیم، select کن و reaction picker نمایش بده (در MessageBubble)
                                            _toggleMessageSelection(
                                                correctedMessage.id);
                                          },
                                          onTap: _isSelectionMode
                                              ? (messageId) {
                                                  _showMessageActionsBottomSheet(
                                                      context,
                                                      correctedMessage);
                                                }
                                              : null,
                                          onSelectTap: _isSelectionMode
                                              ? (messageId) =>
                                                  _toggleMessageSelection(
                                                      correctedMessage.id)
                                              : null,
                                          onSingleTap: (msg) =>
                                              _showMessageActionsBottomSheet(
                                                  context, msg),
                                          onReply: (msg) =>
                                              _setReplyMessage(msg),
                                          onRetry: (msg) =>
                                              _retryFailedMessage(msg),
                                          onReactionSelected: () {
                                            // خاموش کردن selection mode بعد از انتخاب reaction
                                            _clearMessageSelection();
                                          },
                                        ),
                                      ),
                                    ],
                                  );

                                  // ✅ پیچیدن پیام با انیمیشن حذف پودری
                                  return UniversalDeleteAnimation(
                                    controller: _deleteAnimationControllers[
                                        correctedMessage.id],
                                    child: messageWidget,
                                  );
                                },
                              ),
                    // ✅ حباب تاریخ شناور حذف شد - به Stack بیرونی منتقل شد
                  ],
                ),
              ),
              _buildBlockedBanner(),
              // Typing indicator
              TypingIndicatorWidget(
                userName: widget.otherUserName,
                isTyping: _isOtherUserTyping,
              ),
              ConnectionStatusWidget(
                onRetry: () {
                  // تلاش مجدد برای ارسال پیام‌های ناموفق
                  _retryAllFailedMessages();
                },
              ),
              if (!_isCurrentUserBlocked && !_isOtherUserBlocked) ...[
                if (_showFileCaptionInput && _selectedFile != null)
                  _buildFileCaptionInput()
                else
                  _buildMessageInput(),
              ],
            ]),
          ),
        ),
        // ✅ حباب تاریخ شناور - در Stack بیرونی برای نمایش روی AppBar (مثل تلگرام)
        _buildFloatingDateChip(),
        // ✅ Reaction Picker Overlay - نمایش در سطح بالاتر برای جلوگیری از overflow
        // فقط نمایش بده اگر در selection mode نیستیم (یعنی اولین long press)
        if (_reactionPickerMessageId != null &&
            _reactionPickerPosition != null &&
            !_isSelectionMode)
          Builder(
            builder: (context) {
              // محاسبه موقعیت بهینه برای جلوگیری از overflow
              final screenSize = MediaQuery.of(context).size;
              final pickerWidth = 250.0; // عرض تقریبی picker
              final pickerHeight = 60.0; // ارتفاع تقریبی picker

              // محاسبه موقعیت افقی (مرکز picker در مرکز حباب پیام)
              double left = _reactionPickerPosition!.dx - (pickerWidth / 2);
              // اطمینان از اینکه picker از صفحه خارج نشود
              if (left < 10) left = 10;
              if (left + pickerWidth > screenSize.width - 10) {
                left = screenSize.width - pickerWidth - 10;
              }

              // محاسبه موقعیت عمودی (بالای حباب پیام)
              double top = _reactionPickerPosition!.dy - pickerHeight - 10;
              // اگر فضای کافی بالای حباب نیست، زیر حباب نمایش بده
              if (top < 10) {
                top = _reactionPickerPosition!.dy + 50; // زیر حباب
              }

              return Positioned.fill(
                child: GestureDetector(
                  onTap: () => _hideReactionPicker(), // بستن با کلیک خارج
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      // Positioned reaction picker بر اساس موقعیت حباب پیام
                      Positioned(
                        left: left,
                        top: top,
                        child: Material(
                          color: Colors.transparent,
                          elevation: 8,
                          child: ReactionPicker(
                            onReactionSelected: (emoji) async {
                              if (_reactionPickerMessageId != null) {
                                // ارسال reaction به سرور
                                await ref
                                    .read(messageNotifierProvider.notifier)
                                    .toggleReaction(
                                      messageId: _reactionPickerMessageId!,
                                      conversationId: widget.conversationId,
                                      emoji: emoji,
                                    );
                              }
                              _hideReactionPicker();
                            },
                            onClose: () {
                              _hideReactionPicker();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFloatingDateChip() {
    // Don't show floating date when there are no messages to avoid
    // displaying "Today" or occupying space when the list is empty.
    final messages = ref.read(chatScreenProvider(_providerParams)).messages;
    if (messages.isEmpty) return const SizedBox.shrink();

    // ✅ محاسبه فاصله از بالا: ارتفاع status bar + ارتفاع app bar + margin اضافی
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight; // ارتفاع استاندارد app bar (56.0)
    final topPosition = statusBarHeight + appBarHeight + 12.0;

    // ✅ استفاده از Positioned برای قرار دادن دقیق زیر app bar
    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _floatingDate != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeIn,
          child: FloatingDateChip(date: _floatingDate ?? DateTime.now()),
        ),
      ),
    );
  }

  Widget _buildBlockedBanner() {
    if (_isCurrentUserBlocked) {
      return BlockedUserBanner(
        message:
            ' ارسال پیام مجاز نیست. شما توسط ${widget.otherUserName} مسدود شده اید.',
      );
    } else if (_isOtherUserBlocked) {
      return BlockedUserBanner(
        message: 'شما ${widget.otherUserName} را مسدود کرده‌اید.',
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleSendImages(String caption, List<File> files) async {
    try {
      print('📸 ارسال ${files.length} تصویر...');

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        print('📸 ارسال تصویر ${i + 1}/${files.length}');

        // فقط تصویر اول کپشن دارد
        await _sendImageMessage(file, i == 0 ? caption : '');

        // تاخیر کوتاه بین ارسال تصاویر (جلوگیری از فشار به سرور)
        if (i < files.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      print('✅ همه تصاویر ارسال شدند');
    } catch (e) {
      print('❌ خطا در ارسال تصاویر: $e');
      ToastService.showErrorToast(context, 'خطا در ارسال تصاویر');
    }
  }

  Future<void> _sendImageMessage(File file, String caption) async {
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      print('📸 شروع ارسال تصویر: ${file.path}');

      // 1️⃣ ایجاد پیام موقت با تصویر محلی (نمایش فوری)
      final tempMessage = MessageModel.temporary(
        tempId: tempMessageId,
        conversationId: widget.conversationId,
        senderId: supabase.auth.currentUser!.id,
        content: caption.isNotEmpty ? caption : '',
        attachmentType: 'image',
        attachmentUrl: '', // هنوز آپلود نشده
        localImagePath: file.path, // ✅ مسیر محلی تصویر
        isUploading: true,
        uploadProgress: 0.0,
        senderName: 'من',
        createdAt: DateTime.now(),
      );

      // 2️⃣ اضافه کردن پیام موقت به لیست (نمایش فوری با تصویر محلی)
      ref
          .read(chatScreenProvider(_providerParams).notifier)
          .addPendingMessage(tempMessage);

      print('✅ پیام موقت اضافه شد با ID: $tempMessageId');

      // اسکرول به پایین برای نمایش پیام جدید
      _autoScrollToBottom();

      // 3️⃣ آپلود تصویر با نمایش پیشرفت
      print('⬆️ شروع آپلود تصویر...');
      final imageUrl = await AdvancedFileManager.instance.uploadFile(
        file,
        widget.conversationId,
        fileType: 'image',
        onProgress: (progress) {
          print('📊 پیشرفت آپلود: ${(progress * 100).toInt()}%');

          // ✅ به‌روزرسانی پیشرفت آپلود در UI
          if (mounted) {
            ref
                .read(chatScreenProvider(_providerParams).notifier)
                .updateMessageUploadProgress(tempMessageId, progress);
          }
        },
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('URL آپلود شده خالی است');
      }

      print('✅ تصویر آپلود شد: $imageUrl');

      // 4️⃣ ارسال پیام نهایی به سرور
      print('📤 ارسال پیام به سرور...');
      await ref.read(chatScreenProvider(_providerParams).notifier).sendMessage(
            caption.isNotEmpty ? caption : '',
            attachmentUrl: imageUrl,
            attachmentType: 'image',
            tempMessageId: tempMessageId, // برای جایگزینی پیام موقت
          );

      print('✅ پیام با موفقیت ارسال شد');

      // 5️⃣ به‌روزرسانی لیست مکالمات
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      ref.read(cachedConversationsProvider.notifier).refresh();

      ToastService.showSuccessToast(context, 'تصویر با موفقیت ارسال شد');
    } catch (e, stackTrace) {
      print('❌ خطا در ارسال تصویر: $e');
      print('Stack trace: $stackTrace');

      // ✅ علامت‌گذاری پیام به عنوان ناموفق (با دکمه retry)
      if (mounted) {
        ref
            .read(chatScreenProvider(_providerParams).notifier)
            .markMessageAsFailed(tempMessageId, 'خطا در آپلود تصویر: $e');
      }

      ToastService.showErrorToast(
        context,
        'خطا در ارسال تصویر. روی پیام کلیک کنید تا دوباره تلاش کنید.',
      );
    }
  }

  void _handleFileSelected(File file) async {
    setState(() {
      _selectedFile = file;
      _selectedFileName = file.path.split('/').last;
      _showFileCaptionInput = true;
    });
  }

  Future<void> _sendFileMessage(File file, {String caption = ''}) async {
    setState(() {});
    try {
      // آپلود فایل با استفاده از AdvancedFileManager
      final fileUrl = await AdvancedFileManager.instance.uploadFile(
        file,
        widget.conversationId,
        fileType: 'document',
        onProgress: (progress) {
          if (mounted) {
            // می‌توان در آینده پیشرفت را در UI نمایش داد
            debugPrint('File upload progress: ${(progress * 100).toInt()}%');
          }
        },
      );

      if (fileUrl == null) {
        ToastService.showErrorToast(context, 'خطا در آپلود فایل');
        return;
      }

      await ref.read(chatScreenProvider(_providerParams).notifier).sendMessage(
            caption.isNotEmpty ? caption : '',
            attachmentUrl: fileUrl,
            attachmentType: 'document',
          );

      _autoScrollToBottom();

      // بروزرسانی لیست مکالمات برای نمایش آخرین پیام
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      // برای StateNotifier، refresh method فراخوانی کنیم
      ref.read(cachedConversationsProvider.notifier).refresh();
    } catch (e) {
      ToastService.showErrorToast(context, 'خطا در ارسال فایل');
    }
  }

  void _sendFileWithCaption(String caption) {
    if (_selectedFile != null) {
      _sendFileMessage(_selectedFile!, caption: caption);
      _clearAttachments();
    }
  }

  Widget _buildMessageInput() {
    // ✅ RepaintBoundary برای بهبود عملکرد کیبورد
    return RepaintBoundary(
      child: ChatInput(
        onSendMessage: _sendMessage,
        onSendVoiceMessage: _sendVoiceMessage,
        onSendImages: _handleSendImages,
        onFileSelected: _handleFileSelected,
        // ✅✅✅ این خط حیاتی است - مطمئن شوید وجود دارد
        onSendGif: _sendGifMessage,
        parentContext: context,
        replyTo: _replyToMessage,
        onClearReply: () {
          if (mounted) {
            setState(() {
              _replyToMessage = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildFileCaptionInput() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with file info and close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ارسال فایل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    Text(
                      _selectedFileName ?? 'فایل انتخاب شده',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFileCaptionInput = false;
                    _selectedFile = null;
                    _selectedFileName = null;
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.hintColor,
                  size: 20,
                ),
                tooltip: 'لغو',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Caption input
          TextField(
            controller: _fileCaptionController,
            decoration: InputDecoration(
              hintText: 'کپشن فایل (اختیاری)...',
              hintStyle: TextStyle(
                color: theme.hintColor,
                fontSize: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
            ),
            style: TextStyle(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty || _selectedFile != null) {
                _sendFileWithCaption(value.trim());
              }
            },
          ),
          const SizedBox(height: 16),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final caption = _fileCaptionController.text.trim();
                _sendFileWithCaption(caption);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('ارسال فایل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red.withValues(alpha: 0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
