import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../model/message_model.dart';
import '../../../provider/Chat_provider.dart.dart';

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
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());

    // اضافه کردن تأخیر برای اطمینان از اینکه widget کاملاً ساخته شده است
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          // استفاده از safeMessageHandlerProvider
          final handler = ref.read(safeMessageHandlerProvider);
          handler.markAsRead(widget.conversationId);
        } catch (e) {
          print('خطا در علامت‌گذاری به عنوان خوانده شده: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageController.dispose();
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUserAvatar != null &&
                      widget.otherUserAvatar!.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar!)
                  : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
            ),
            const SizedBox(width: 8),
            Text(widget.otherUserName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // نمایش اطلاعات چت
            },
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
                          onPressed: () => ref
                              .refresh(messagesProvider(widget.conversationId)),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF1A1A1A) // رنگ تیره برای حالت تاریک
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black26
                      : Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.photo_library,
                    color: _isUploading
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: _isUploading ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'پیام خود را بنویسید...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF2D2D2D) // رنگ تیره برای حالت تاریک
                          : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isUploading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.send,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
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
    final myTimeColor =
        isLightMode ? Colors.white : Colors.black; // واضح‌تر در حالت تاریک
    final otherTimeColor = isLightMode
        ? Colors.grey[700]
        : Colors.grey[300]; // روشن‌تر در حالت تاریک

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme: IconThemeData(color: Colors.white),
                              ),
                              backgroundColor: Colors.black,
                              body: Center(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    message.attachmentUrl!,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(Icons.broken_image,
                                            size: 50, color: Colors.white),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: 200,
                            minWidth: 150,
                          ),
                          child: Image.network(
                            message.attachmentUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 150,
                                width: 200,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  color: isMe
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 200,
                                color: isLightMode
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image,
                                    size: 50,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey[500]),
                              );
                            },
                          ),
                        ),
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
                            color: isMe ? myTimeColor : otherTimeColor,
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
