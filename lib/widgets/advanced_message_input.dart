import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'animated_send_button.dart';

class AdvancedMessageInput extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onVoiceRecordStart;
  final VoidCallback? onVoiceRecordEnd;
  final String? replyToMessage;
  final VoidCallback? onCancelReply;

  const AdvancedMessageInput({
    super.key,
    required this.onSendMessage,
    this.onVoiceRecordStart,
    this.onVoiceRecordEnd,
    this.replyToMessage,
    this.onCancelReply,
  });

  @override
  ConsumerState<AdvancedMessageInput> createState() =>
      _AdvancedMessageInputState();
}

class _AdvancedMessageInputState extends ConsumerState<AdvancedMessageInput>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isComposing = false;
  int _characterCount = 0;
  static const _maxLength = 1000;
  late AnimationController _replyAnimationController;
  late Animation<double> _replyAnimation;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);

    _replyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _replyAnimation = CurvedAnimation(
      parent: _replyAnimationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(AdvancedMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyToMessage != null && oldWidget.replyToMessage == null) {
      _replyAnimationController.forward();
    } else if (widget.replyToMessage == null && oldWidget.replyToMessage != null) {
      _replyAnimationController.reverse();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _replyAnimationController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {
      _isComposing = _textController.text.trim().isNotEmpty;
      _characterCount = _textController.text.length;
    });
  }

  void _handleSubmit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text);
    _textController.clear();
    setState(() {
      _isComposing = false;
      _characterCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply Preview
        if (widget.replyToMessage != null)
          SizeTransition(
            sizeFactor: _replyAnimation,
            child: _buildReplyPreview(),
          ),

        // Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment Button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _handleAttachment,
                  color: Colors.blue,
                ),

                // Text Field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      maxLength: _maxLength,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        counterText: _characterCount > 800
                            ? '$_characterCount / $_maxLength'
                            : '',
                        counterStyle: TextStyle(
                          color: _characterCount > _maxLength
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send/Voice Button
                _buildActionButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(
            color: Colors.blue.shade600,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'پاسخ به',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyToMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCancelReply,
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isComposing) {
      return AnimatedSendButton(
        onPressed: _handleSubmit,
        enabled: _characterCount <= _maxLength,
      );
    }

    return IconButton(
      icon: const Icon(Icons.mic),
      onPressed: widget.onVoiceRecordStart,
      color: Colors.blue,
    );
  }

  void _handleAttachment() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('تصویر'),
              onTap: () {
                Navigator.pop(context);
                // Handle image
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.green),
              title: const Text('ویدیو'),
              onTap: () {
                Navigator.pop(context);
                // Handle video
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
              title: const Text('فایل'),
              onTap: () {
                Navigator.pop(context);
                // Handle file
              },
            ),
          ],
        ),
      ),
    );
  }
}















