import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../main.dart' show supabase;
import '../../../model/channel_message_model.dart';
import '../../../model/channel_model.dart';
import '../../../provider/channel_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../chat/chat_input_box.dart';
import 'ChannelSettingsScreen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  final ChannelModel channel;

  const ChannelScreen({Key? key, required this.channel}) : super(key: key);

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _isUploading = false;
  bool _isSending = false;
  double _uploadProgress = 0.0;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  ChannelMessageModel? _replyToMessage;
  final FocusNode _editFocusNode = FocusNode(); // فوکوس جدید برای ویرایش
  final TextEditingController _editController =
      TextEditingController(); // کنترلر جدید برای ویرایش

  @override
  void initState() {
    super.initState();
    _debugPrintChannelInfo();
  }

  void _debugPrintChannelInfo() {
    print('=== Channel Debug Info ===');
    print('Channel ID: ${widget.channel.id}');
    print('Channel Name: ${widget.channel.name}');
    print('Member Role: ${widget.channel.memberRole}');
    print('Creator ID: ${widget.channel.creatorId}');
    print('Current User ID: ${supabase.auth.currentUser?.id}');
    print('Is Subscribed: ${widget.channel.isSubscribed}');
    print('=======================');
  }

  @override
  Widget build(BuildContext context) {
    final canPost = widget.channel.memberRole == 'owner';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    final replyToMessage = ref.watch(replyToMessageProvider);

    if (isKeyboardVisible && _showEmojiPicker) {
      _showEmojiPicker = false;
    }

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // نمایش بنر reply
          if (replyToMessage != null) _buildReplyBanner(replyToMessage),

          Expanded(child: _buildMessagesList()),

          if (canPost) _buildChatInputBox(),
        ],
      ),
    );
  }

  // 💬 بنر نمایش پیام reply
  Widget _buildReplyBanner(ChannelMessageModel replyMessage) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(
            color: Colors.blue.shade500,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: Colors.blue.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'پاسخ به ${replyMessage.senderName ?? widget.channel.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyMessage.content.isNotEmpty
                      ? replyMessage.content
                      : (replyMessage.attachmentUrl != null
                          ? '📷 تصویر'
                          : 'پیام خالی'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(channelNotifierProvider.notifier).cancelReply();
            },
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final messagesAsync = ref.watch(channelMessagesProvider(widget.channel.id));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        // پیام‌ها را از قدیمی به جدید مرتب کن
        final sortedMessages = List<ChannelMessageModel>.from(messages)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // اضافه کردن این بخش برای اسکرول به پایین پس از بارگذاری پیام‌ها
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // اطمینان از اینکه ویجت هنوز در درخت ویجت‌ها وجود دارد و کنترلر اسکرول کلاینت دارد
          if (mounted && _scrollController.hasClients) {
            _scrollToBottom();
          }
        });

        return ListView.builder(
          controller: _scrollController,
          reverse: false, // مهم: باید false باشد
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: sortedMessages.length,
          itemBuilder: (context, index) {
            final message = sortedMessages[index];
            final previousMessage =
                index > 0 ? sortedMessages[index - 1] : null;
            final showDateDivider =
                _isFirstMessageOfDay(message, previousMessage);

            return Column(
              children: [
                if (showDateDivider) _buildDateDivider(message.createdAt),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildMessageItem(message),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'خطا در بارگذاری پیام‌ها',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(channelMessagesProvider(widget.channel.id));
              },
              child: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChannelMessageModel message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final editingMessageId = ref.watch(editingMessageProvider);
    final isEditing = editingMessageId == message.id;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // آواتار کانال خارج از حباب
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade500,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.channel.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.channel.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          _buildChannelInitialSmall(),
                    ),
                  )
                : _buildChannelInitialSmall(),
          ),

          const SizedBox(width: 8),

          // حباب پیام با لبه
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: CustomPaint(
                painter: MessageBubblePainter(
                  color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                  isDarkMode: isDarkMode,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // هدر پیام
                      Row(
                        children: [
                          Text(
                            widget.channel.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.blue.shade600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'کانال',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // پیام پاسخ داده شده
                      if (message.replyToMessageId != null)
                        _buildReplyMessage(message),

                      // محتوای پیام یا ورودی ویرایش
                      if (isEditing)
                        _buildEditingInput(message)
                      else ...[
                        // محتوای پیام
                        if (message.content.isNotEmpty)
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.grey[100]
                                  : Colors.black87,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.1,
                            ),
                          ),

                        // نمایش وضعیت ویرایش
                        if (message.isEdited)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ویرایش شده',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],

                      // تصویر پیام
                      if (message.attachmentUrl != null && !isEditing)
                        _buildMessageImage(message.attachmentUrl!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 ورودی ویرایش پیام
  Widget _buildEditingInput(ChannelMessageModel message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withOpacity(0.3)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _editController,
            focusNode: _editFocusNode,
            maxLines: null,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'پیام خود را ویرایش کنید...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(channelNotifierProvider.notifier).cancelEditing();
                  _editController.clear();
                },
                child: Text(
                  'لغو',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (_editController.text.trim().isNotEmpty) {
                    try {
                      await ref
                          .read(channelNotifierProvider.notifier)
                          .editMessage(
                            messageId: message.id,
                            channelId: widget.channel.id,
                            newContent: _editController.text.trim(),
                          );
                      _editController.clear();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('پیام ویرایش شد')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در ویرایش: $e')),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade500,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📋 منوی گزینه‌های پیام
  void _showMessageOptions(ChannelMessageModel message) {
    final currentUserId = supabase.auth.currentUser?.id;
    final isOwner = message.senderId == currentUserId;
    final canDelete = isOwner || widget.channel.memberRole == 'owner';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دسته
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // گزینه پاسخ
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('پاسخ'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(channelNotifierProvider.notifier)
                    .setReplyToMessage(message);
                _messageFocusNode.requestFocus();
              },
            ),

            // گزینه کپی
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('کپی'),
              onTap: () {
                Navigator.pop(context);
                if (message.content.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('متن کپی شد')),
                  );
                }
              },
            ),

            // گزینه ویرایش (فقط برای صاحب پیام)
            if (isOwner && message.content.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('ویرایش'),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(channelNotifierProvider.notifier)
                      .startEditingMessage(message.id, message.content);
                  _editController.text = message.content;

                  // اسکرول به پیام و فوکوس
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _editFocusNode.requestFocus();
                  });
                },
              ),
            ],

            // گزینه حذف
            if (canDelete) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(message);
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ❌ تایید حذف پیام
  void _showDeleteConfirmation(ChannelMessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پیام'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پیام را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(channelNotifierProvider.notifier)
                    .deleteMessage(message.id, widget.channel.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پیام حذف شد')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف پیام: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // ... existing code برای سایر متدها ...

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final replyToMessage = ref.read(replyToMessageProvider);

    if (content.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref.read(channelNotifierProvider.notifier).sendMessage(
            channelId: widget.channel.id,
            content: content,
            imageFile: _selectedImage,
            replyToMessageId: replyToMessage?.id, // اضافه کردن reply
          );

      _messageController.clear();
      _selectedImage = null;
      _selectedImageBytes = null;

      // پاک کردن reply
      ref.read(channelNotifierProvider.notifier).cancelReply();

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پیام: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      title: Row(
        children: [
          // آواتار کانال با طراحی جدید
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade500,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.channel.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.channel.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          _buildChannelInitial(),
                    ),
                  )
                : _buildChannelInitial(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channel.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.channel.memberCount} عضو فعال',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.grey[800]?.withOpacity(0.6)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              size: 22,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChannelSettingsScreen(channel: widget.channel),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildChannelInitial() {
    final String initial = widget.channel.name.isNotEmpty
        ? widget.channel.name[0].toUpperCase()
        : '#';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  bool _isFirstMessageOfDay(
      ChannelMessageModel current, ChannelMessageModel? previous) {
    if (previous == null) return true;

    final currentDate = DateTime(
      current.createdAt.year,
      current.createdAt.month,
      current.createdAt.day,
    );
    final previousDate = DateTime(
      previous.createdAt.year,
      previous.createdAt.month,
      previous.createdAt.day,
    );

    return !currentDate.isAtSameMomentAs(previousDate);
  }

  Widget _buildDateDivider(DateTime date) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate.isAtSameMomentAs(today)) {
      dateText = 'امروز';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      dateText = 'دیروز';
    } else {
      dateText = DateFormat('EEEE، d MMMM y', 'fa').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // آیکون انیمیشنی
          TweenAnimationBuilder(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade500,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'به ${widget.channel.name} خوش آمدید! 🎉',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'هنوز پیامی در این کانال ارسال نشده است\nاولین نفری باشید که پیام می‌فرستد!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // دکمه تشویقی
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.blue.shade600.withOpacity(0.2)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'از پایین شروع کنید',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelInitialSmall() {
    final String initial = widget.channel.name.isNotEmpty
        ? widget.channel.name[0].toUpperCase()
        : '#';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildReplyMessage(ChannelMessageModel message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer(
      builder: (context, ref, child) {
        // دریافت پیام اصلی که به آن پاسخ داده شده
        final messagesAsync =
            ref.watch(channelMessagesProvider(widget.channel.id));

        return messagesAsync.when(
          data: (messages) {
            final replyToMessage = messages.firstWhere(
              (msg) => msg.id == message.replyToMessageId,
              orElse: () => ChannelMessageModel(
                id: '',
                channelId: '',
                content: 'پیام حذف شده',
                createdAt: DateTime.now(),
                senderName: 'نامشخص',
                senderAvatar: null,
                senderId: '',
                isMe: false,
              ),
            );

            return GestureDetector(
              onTap: () => _scrollToMessage(message.replyToMessageId!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]?.withOpacity(0.4)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    right: BorderSide(
                      color: Colors.blue.shade500,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: Colors.blue.shade500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پاسخ به ${replyToMessage.senderName ?? widget.channel.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (replyToMessage.content != null &&
                                    replyToMessage.content!.isNotEmpty)
                                ? replyToMessage.content!
                                : (replyToMessage.attachmentUrl != null
                                    ? '📷 تصویر' // Display icon if it's an image reply
                                    : 'پیام خالی'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey[800]?.withOpacity(0.4)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'در حال بارگذاری...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          error: (error, stack) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'خطا در بارگذاری پیام',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToMessage(String messageId) async {
    final messagesAsync = ref.read(channelMessagesProvider(widget.channel.id));

    messagesAsync.whenData((messages) {
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);

      if (messageIndex != -1 && _scrollController.hasClients) {
        // محاسبه موقعیت پیام (تقریبی)
        final position = messageIndex * 120.0; // ارتفاع تقریبی هر پیام

        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        // هایلایت کردن پیام برای مدت کوتاه
        Future.delayed(const Duration(milliseconds: 600), () {
          // می‌توانید اینجا انیمیشن هایلایت اضافه کنید
        });
      }
    });
  }

  Widget _buildMessageImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
        maxHeight: 280,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(imageUrl),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.blue.shade500,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'در حال بارگذاری...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade400,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'خطا در بارگذاری تصویر',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputBox() {
    return ChatInputBox(
      messageController: _messageController,
      messageFocusNode: _messageFocusNode,
      showEmojiPicker: _showEmojiPicker,
      toggleEmojiPicker: _toggleEmojiKeyboard,
      pickImage: _pickImage,
      sendMessage: _sendMessage,
      onEmojiSelected: _onEmojiSelected,
      isUploading: _isUploading,
      isSending: _isSending,
      uploadProgress: _uploadProgress,
      selectedImagePreview:
          _selectedImage != null || _selectedImageBytes != null
              ? _buildSelectedImagePreview()
              : null,
      replyToMessage: _replyToMessage?.content,
      replyToUser: widget.channel.name,
      onReplyCancel: () => setState(() => _replyToMessage = null),
    );
  }

  Widget? _buildSelectedImagePreview() {
    if (_selectedImage == null && _selectedImageBytes == null) return null;

    return Container(
      margin: const EdgeInsets.all(8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _selectedImage != null
                ? (kIsWeb
                    ? Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image, size: 40),
                      )
                    : Image.file(
                        _selectedImage!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ))
                : (_selectedImageBytes != null
                    ? Image.memory(
                        _selectedImageBytes!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      )
                    : Container()),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedImage = null;
                _selectedImageBytes = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MM/dd').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'الان';
    }
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isUploading = true);

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _isUploading = false;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _editController.dispose(); // dispose کردن کنترلر جدید
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _editFocusNode.dispose(); // dispose کردن فوکوس جدید
    super.dispose();
  }
}

class MessageBubblePainter extends CustomPainter {
  final Color color;
  final bool isDarkMode;

  MessageBubblePainter({required this.color, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = isDarkMode
          ? Colors.black.withOpacity(0.2)
          : Colors.grey.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // ابعاد و موقعیت‌های کلیدی
    const double cornerRadius = 16.0;
    const double tailSize = 8.0;
    const double tailPosition = 20.0;

    // رسم سایه
    final shadowPath = _createBubblePath(
      size: Size(size.width + 2, size.height + 2),
      cornerRadius: cornerRadius,
      tailSize: tailSize,
      tailPosition: tailPosition,
      offset: const Offset(1, 1),
    );

    canvas.drawPath(shadowPath, shadowPaint);

    // رسم حباب اصلی
    final bubblePath = _createBubblePath(
      size: size,
      cornerRadius: cornerRadius,
      tailSize: tailSize,
      tailPosition: tailPosition,
      offset: Offset.zero,
    );

    canvas.drawPath(bubblePath, paint);

    // رسم border ظریف
    final borderPaint = Paint()
      ..color = isDarkMode
          ? Colors.grey[700]!.withOpacity(0.3)
          : Colors.grey[200]!.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawPath(bubblePath, borderPaint);
  }

  Path _createBubblePath({
    required Size size,
    required double cornerRadius,
    required double tailSize,
    required double tailPosition,
    required Offset offset,
  }) {
    final path = Path();

    // شروع از گوشه بالا سمت راست
    path.moveTo(cornerRadius + offset.dx, offset.dy);

    // خط بالا
    path.lineTo(size.width - cornerRadius + offset.dx, offset.dy);

    // گوشه بالا راست
    path.quadraticBezierTo(
      size.width + offset.dx,
      offset.dy,
      size.width + offset.dx,
      cornerRadius + offset.dy,
    );

    // خط سمت راست
    path.lineTo(size.width + offset.dx, size.height - cornerRadius + offset.dy);

    // گوشه پایین راست
    path.quadraticBezierTo(
      size.width + offset.dx,
      size.height + offset.dy,
      size.width - cornerRadius + offset.dx,
      size.height + offset.dy,
    );

    // خط پایین
    path.lineTo(cornerRadius + offset.dx, size.height + offset.dy);

    // گوشه پایین چپ
    path.quadraticBezierTo(
      offset.dx,
      size.height + offset.dy,
      offset.dx,
      size.height - cornerRadius + offset.dy,
    );

    // خط سمت چپ تا نقطه شروع tail
    path.lineTo(offset.dx, tailPosition + tailSize + offset.dy);

    // رسم tail (لبه اشاره‌کننده به آواتار)
    path.quadraticBezierTo(
      offset.dx - tailSize * 0.7,
      tailPosition + (tailSize / 2) + offset.dy,
      offset.dx,
      tailPosition + offset.dy,
    );

    // ادامه خط سمت چپ تا گوشه بالا
    path.lineTo(offset.dx, cornerRadius + offset.dy);

    // گوشه بالا چپ
    path.quadraticBezierTo(
      offset.dx,
      offset.dy,
      cornerRadius + offset.dx,
      offset.dy,
    );

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is MessageBubblePainter) {
      return color != oldDelegate.color || isDarkMode != oldDelegate.isDarkMode;
    }
    return true;
  }
}
