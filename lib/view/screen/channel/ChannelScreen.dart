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

class ChannelScreen extends ConsumerStatefulWidget {
  final ChannelModel channel;

  const ChannelScreen({Key? key, required this.channel}) : super(key: key);

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _isUploading = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isCurrentUserBlocked = false;
  bool _isOtherUserBlocked = false;

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
    // مقدار memberRole رو پرینت می‌کنیم برای دیباگ
    print('Current member role: ${widget.channel.memberRole}');

    // شرط رو ساده‌تر می‌کنیم
    final canPost = widget.channel.memberRole != null;

    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: widget.channel.avatarUrl != null
                ? CachedNetworkImageProvider(widget.channel.avatarUrl!)
                : null,
            child: widget.channel.avatarUrl == null
                ? Text(widget.channel.name[0].toUpperCase())
                : null,
          ),
          title: Text(
            widget.channel.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${widget.channel.memberCount} عضو'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChannelSettingsScreen(channel: widget.channel),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          // فقط شرط canPost رو چک می‌کنیم
          if (canPost) _buildMessageInput(),
        ],
      ),
      // اضافه کردن FAB برای ارسال پست جدید برای ادمین‌ها
      // floatingActionButton: canPost
      //     ? FloatingActionButton(
      //         onPressed: () => _showPostDialog(),
      //         child: const Icon(Icons.post_add),
      //       )
      //     : null,
    );
  }

  Widget _buildMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final messagesAsync =
            ref.watch(channelMessagesProvider(widget.channel.id));

        return messagesAsync.when(
          data: (messages) {
            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageItem(message);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('خطا در دریافت پیام‌ها: $error'),
          ),
        );
      },
    );
  }

  Widget _buildMessageItem(ChannelMessageModel message) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: message.senderAvatar != null
            ? CachedNetworkImageProvider(message.senderAvatar!)
            : null,
        child: message.senderAvatar == null
            ? Text(message.senderName?[0].toUpperCase() ?? 'U')
            : null,
      ),
      title: Text(message.senderName ?? 'کاربر'),
      subtitle: Text(message.content),
      trailing: Text(
        _formatMessageTime(message.createdAt),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

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
    );
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(channelProvider.notifier).sendMessage(
          channelId: widget.channel.id,
          content: content,
        );

    _messageController.clear();
  }

  // اضافه کردن دیالوگ ارسال پست
  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ارسال محتوای جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'متن پست...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: () {
                    // اضافه کردن تصویر
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () {
                    // اضافه کردن لینک
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                _sendMessage();
                Navigator.pop(context);
              }
            },
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
  }

  void _toggleEmojiKeyboard() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _messageFocusNode.unfocus();
      } else {
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.baseOffset + emoji.length),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در انتخاب تصویر')),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (_selectedImage != null)
            Image.file(_selectedImage!, fit: BoxFit.cover)
          else if (_selectedImageBytes != null)
            Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'چند لحظه پیش';
    }
  }
}
