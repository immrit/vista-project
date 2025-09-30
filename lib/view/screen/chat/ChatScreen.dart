import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../main.dart';
import '../../../model/message_model.dart';
import '../../../provider/new_chat_provider.dart';
import '../../../provider/chat_provider.dart' as chat_provider;
import '../../../services/audio_recording_service.dart';
import '../../../services/uploadAudioChatService.dart';
import '../../../services/uploadImageChatService.dart';
import '../../widgets/SharedPostWidget.dart';
import 'chat_input_box.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/date_divider.dart';
import '../PublicPosts/profileScreen.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final FocusNode _messageFocusNode = FocusNode();

  // State
  DateTime? _floatingDate;
  Timer? _floatingDateTimer;
  late final ChatProviderParams _providerParams;
  bool _showEmojiPicker = false;
  MessageModel? _replyToMessage;

  // File handling state
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  File? _selectedAudio;
  Uint8List? _selectedAudioBytes;
  String? _selectedAudioName;

  // UI state
  bool _isUploading = false;
  bool _isSending = false;
  bool _isRecordingAudio = false;
  bool _isScrolling = false; // جلوگیری از فراخوانی مکرر scroll listener
  bool _isUpdatingFloatingDate =
      false; // جلوگیری از فراخوانی مکرر floating date update
  double _uploadProgress = 0.0;
  bool _isOtherUserBlocked = false;
  bool _isCurrentUserBlocked = false;
  final Set<String> _deletingMessageIds = {};

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
    _itemPositionsListener.itemPositions.addListener(_scrollListener);
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    try {
      final chatService = ref.read(chat_provider.chatServiceProvider);
      final isBlocked = await chatService.isUserBlocked(widget.otherUserId);
      final isCurrentUserBlocked =
          await chatService.isCurrentUserBlockedBy(widget.otherUserId);
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

  void _scrollListener() {
    // جلوگیری از فراخوانی مکرر
    if (_isScrolling) return;
    _isScrolling = true;

    try {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      final firstPosition = positions.first;
      if (firstPosition.index <= 5) {
        ref.read(newChatProvider(_providerParams).notifier).fetchMoreMessages();
      }

      _updateFloatingDate(positions);
    } finally {
      _isScrolling = false;
    }
  }

  void _updateFloatingDate(Iterable<ItemPosition> positions) {
    if (!mounted || _isUpdatingFloatingDate) return;

    _isUpdatingFloatingDate = true;

    try {
      final firstVisibleItemIndex = positions
          .where((position) => position.itemLeadingEdge < 1)
          .last
          .index;

      final messages = ref.read(newChatProvider(_providerParams)).messages;
      if (firstVisibleItemIndex >= 0 &&
          firstVisibleItemIndex < messages.length) {
        final messageDate = messages[firstVisibleItemIndex].createdAt;
        if (_floatingDate == null || !_isSameDay(_floatingDate!, messageDate)) {
          if (mounted) {
            setState(() {
              _floatingDate = messageDate;
            });
          }
        }
      }

      _floatingDateTimer?.cancel();
      _floatingDateTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _floatingDate = null;
          });
        }
      });
    } finally {
      _isUpdatingFloatingDate = false;
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _isSharedPost(String content) {
    return content.contains('📝 پست از') &&
        content.contains('🔗 مشاهده در Vista:');
  }

  @override
  void dispose() {
    print(
        '🗑️ Disposing ChatScreen for conversation: ${widget.conversationId}');
    _messageController.dispose();
    _floatingDateTimer?.cancel();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // --- Message Sending Logic ---
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null &&
        _selectedAudio == null &&
        _selectedAudioBytes == null) {
      return;
    }

    setState(() => _isSending = true);

    String? attachmentUrl;
    String? attachmentType;

    try {
      if (_selectedAudio != null || _selectedAudioBytes != null) {
        attachmentType = 'audio';
        attachmentUrl =
            await _uploadAudio(_selectedAudio ?? _selectedAudioBytes!);
      } else if (_selectedImage != null || _selectedImageBytes != null) {
        attachmentType = 'image';
        attachmentUrl =
            await _uploadImage(_selectedImage ?? _selectedImageBytes!);
      }

      if (attachmentUrl == null && message.isEmpty) {
        setState(() => _isSending = false);
        return;
      }

      await ref.read(newChatProvider(_providerParams).notifier).sendMessage(
            message,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            replyToMessage: _replyToMessage,
          );

      _messageController.clear();
      _clearAttachments();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال پیام: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _clearAttachments() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedAudio = null;
      _selectedAudioBytes = null;
      _selectedAudioName = null;
      _replyToMessage = null;
      _isUploading = false;
      _uploadProgress = 0.0;
    });
  }

  // --- File Handling ---
  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
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
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در انتخاب تصویر: $e')),
      );
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
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );
      }
      return imageUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در آپلود تصویر: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _uploadAudio(dynamic fileOrBytes) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    try {
      String? audioUrl;
      if (kIsWeb && fileOrBytes is Uint8List && _selectedAudioName != null) {
        audioUrl = await ChatAudioUploadService.uploadChatAudioWeb(
            fileOrBytes, _selectedAudioName!, widget.conversationId);
      } else if (fileOrBytes is File) {
        audioUrl = await ChatAudioUploadService.uploadChatAudio(
            fileOrBytes, widget.conversationId, onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        });
      }
      return audioUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در آپلود صدا: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- UI Methods ---
  void _scrollToBottom() {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiKeyboard() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      FocusScope.of(context).requestFocus(_messageFocusNode);
    } else {
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
    _messageController.text += emoji;
  }

  void _setReplyMessage(MessageModel message) {
    setState(() => _replyToMessage = message);
    _messageFocusNode.requestFocus();
  }

  // --- Recording Logic ---
  void _startRecording() async {
    setState(() => _isRecordingAudio = true);
    await AudioRecordingService.startRecording();
  }

  void _stopRecording() async {
    setState(() => _isRecordingAudio = false);
    final file = await AudioRecordingService.stopRecording();
    if (file != null) {
      _onAudioRecorded(file, null, file.path.split('/').last);
    }
  }

  void _onAudioRecorded(
      File? audioFile, Uint8List? audioBytes, String? fileName) {
    if (audioFile != null || audioBytes != null) {
      setState(() {
        _selectedAudio = audioFile;
        _selectedAudioBytes = audioBytes;
        _selectedAudioName = fileName;
      });
    }
  }

  // --- Dialogs & Menus ---
  void _showMessageOptions(BuildContext context, MessageModel message) {
    final isMe = message.senderId == supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    Icon(Icons.reply, color: Theme.of(context).primaryColor),
                title: const Text('پاسخ'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('کپی پیام'),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پیام کپی شد')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف پیام'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteMessageDialog(message);
                },
              ),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('گزارش پیام'),
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

  Future<void> _showDeleteMessageDialog(MessageModel message) async {
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
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              child: const Text('حذف برای همه'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    try {
      setState(() => _deletingMessageIds.add(messageId));
      await ref
          .read(chat_provider.messageNotifierProvider.notifier)
          .deleteMessage(messageId, forEveryone: forEveryone);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              forEveryone ? 'پیام برای همه حذف شد' : 'پیام برای شما حذف شد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطا در حذف پیام: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingMessageIds.remove(messageId));
      }
    }
  }

  void _showReportMessageDialog(BuildContext context, MessageModel message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('قابلیت گزارش پیام به زودی اضافه می‌شود')),
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
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final notifier =
                    ref.read(chat_provider.userBlockNotifierProvider.notifier);

                if (isBlocked) {
                  await notifier.unblockUser(widget.otherUserId);
                } else {
                  await notifier.blockUser(widget.otherUserId);
                }

                await _checkBlockStatus();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isBlocked
                          ? '${widget.otherUserName} با موفقیت رفع مسدودیت شد'
                          : '${widget.otherUserName} با موفقیت مسدود شد')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isBlocked
                          ? 'خطا در رفع مسدودیت کاربر'
                          : 'خطا در مسدود کردن کاربر')),
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
      'سایر موارد'
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
                  value: selectedReason,
                  dropdownColor:
                      isLightMode ? Colors.white : const Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    .read(chat_provider.userReportNotifierProvider.notifier)
                    .reportUser(
                      userId: widget.otherUserId,
                      reason: selectedReason,
                      additionalInfo:
                          additionalInfo.isEmpty ? null : additionalInfo,
                    )
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('گزارش شما با موفقیت ارسال شد')),
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

  @override
  Widget build(BuildContext context) {
    // بررسی اولیه conversationId
    if (widget.conversationId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطا')),
        body: const Center(child: Text('شناسه مکالمه نامعتبر است')),
      );
    }

    final chatState = ref.watch(newChatProvider(_providerParams));
    final messages = chatState.messages;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUserAvatar != null
                  ? CachedNetworkImageProvider(widget.otherUserAvatar!)
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
                      final isOnlineAsync = ref.watch(chat_provider
                          .userOnlineStatusStreamProvider(widget.otherUserId));

                      return isOnlineAsync.when(
                        data: (isOnline) {
                          return Text(
                            isOnline ? 'آنلاین' : 'آفلاین',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          );
                        },
                        loading: () => const Text('در حال بارگذاری...',
                            style: TextStyle(fontSize: 12)),
                        error: (_, __) => const Text('آفلاین',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'گزینه‌های بیشتر',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _showBlockUserDialog(context);
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
                    const SizedBox(width: 12),
                    const Text('مشاهده پروفایل'),
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
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 12),
                    const Text('گزارش کاربر'),
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
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                chatState.isLoading && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty && !chatState.isLoading
                        ? const Center(child: Text('پیامی یافت نشد'))
                        : AnimationLimiter(
                            child: ScrollablePositionedList.builder(
                              itemScrollController: _itemScrollController,
                              itemPositionsListener: _itemPositionsListener,
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                bool showDateDivider = false;
                                if (index < messages.length - 1) {
                                  final prevMessage = messages[index + 1];
                                  if (!_isSameDay(message.createdAt,
                                      prevMessage.createdAt)) {
                                    showDateDivider = true;
                                  }
                                } else {
                                  showDateDivider = true;
                                }

                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: Column(
                                        children: [
                                          if (showDateDivider)
                                            DateDivider(
                                                date: message.createdAt),
                                          _isSharedPost(message.content)
                                              ? SharedPostWidget(
                                                  messageContent:
                                                      message.content,
                                                  attachmentUrl:
                                                      message.attachmentUrl,
                                                  attachmentType:
                                                      message.attachmentType,
                                                )
                                              : MessageBubble(
                                                  message: message,
                                                  onLongPress: (msg) =>
                                                      _showMessageOptions(
                                                          context, msg),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                _buildFloatingDateChip(),
              ],
            ),
          ),
          _buildBlockedBanner(),
          if (!_isCurrentUserBlocked && !_isOtherUserBlocked)
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildFloatingDateChip() {
    return AnimatedOpacity(
      opacity: _floatingDate != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      child: Container(
        margin: const EdgeInsets.only(top: 16.0),
        child: FloatingDateChip(
          date: _floatingDate ?? DateTime.now(),
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

  Widget _buildMessageInput() {
    return ChatInputBox(
      messageController: _messageController,
      messageFocusNode: _messageFocusNode,
      toggleEmojiPicker: _toggleEmojiKeyboard,
      pickImage: _pickImage,
      sendMessage: _sendMessage,
      onEmojiSelected: _onEmojiSelected,
      onReplyCancel: () => setState(() => _replyToMessage = null),
      onAudioRecorded: _onAudioRecorded,
      onStartRecording: _startRecording,
      onStopRecording: _stopRecording,
      onImageCancel: () => setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _selectedImageName = null;
      }),
      onAudioCancel: () => setState(() {
        _selectedAudio = null;
        _selectedAudioBytes = null;
        _selectedAudioName = null;
      }),
      showEmojiPicker: _showEmojiPicker,
      isUploading: _isUploading,
      isSending: _isSending,
      isRecordingAudio: _isRecordingAudio,
      uploadProgress: _uploadProgress,
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
      color: Colors.red.withOpacity(0.8),
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
