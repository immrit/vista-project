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
  String? _replyToMessageId;
  ChannelMessageModel? _replyToMessage;

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
    final canPost = widget.channel.memberRole == 'owner' ||
        widget.channel.memberRole == 'admin' ||
        widget.channel.memberRole == 'member';

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
          // دکمه رفرش
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshChannel(),
          ),
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
          // نمایش پیام reply
          if (_replyToMessage != null) _buildReplyPreview(),
          Expanded(
            child: _buildMessagesList(),
          ),
          if (canPost) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(color: Theme.of(context).primaryColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پاسخ به ${_replyToMessage!.senderName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  _replyToMessage!.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
                _replyToMessageId = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final messagesAsync =
            ref.watch(channelMessagesProvider(widget.channel.id));

        return messagesAsync.when(
          data: (messages) {
            if (messages.isEmpty) {
              return const Center(child: Text('هنوز پیامی ارسال نشده است.'));
            }

            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message.senderName ?? 'ناشناس'),
                  subtitle: Text(message.content),
                  leading: message.senderAvatar != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(message.senderAvatar!),
                        )
                      : const CircleAvatar(child: Icon(Icons.person)),
                );
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // پیش‌نمایش تصویر
          if (_selectedImage != null || _selectedImageBytes != null)
            _buildImagePreview(),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'پیام خود را بنویسید...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isUploading ? null : _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await ref.read(channelNotifierProvider.notifier).sendMessage(
            channelId: widget.channel.id,
            content: _messageController.text.trim(),
            replyToMessageId: _replyToMessageId,
          );

      _messageController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _replyToMessage = null;
        _replyToMessageId = null;
      });

      // اسکرول به پایین
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پیام: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _refreshChannel() async {
    try {
      await ref
          .read(channelNotifierProvider.notifier)
          .refreshChannel(widget.channel.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کانال بروزرسانی شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بروزرسانی: $e')),
        );
      }
    }
  }

  // ... باقی متدها مثل _pickImage، _buildImagePreview، _formatMessageTime
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _selectedImage != null
                ? Image.file(_selectedImage!,
                    fit: BoxFit.cover, width: 100, height: 100)
                : _selectedImageBytes != null
                    ? Image.memory(_selectedImageBytes!,
                        fit: BoxFit.cover, width: 100, height: 100)
                    : Container(),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }
}
