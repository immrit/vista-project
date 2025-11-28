// lib/features/chat/widgets/message_input.dart
//
// ورودی پیام مدرن با امکانات کامل
//
// ویژگی‌ها:
// ✅ Auto-expand textarea
// ✅ دکمه Attachment
// ✅ دکمه Voice Record
// ✅ انیمیشن Send Button
// ✅ Reply Preview

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../model/message_model.dart';

class ModernMessageInput extends StatefulWidget {
  final Function(String content) onSend;
  final Function()? onAttachmentPressed;
  final Function()? onVoicePressed;
  final Function(String conversationId)? onTyping;
  final MessageModel? replyToMessage;
  final VoidCallback? onCancelReply;
  final bool isEnabled;
  final String? conversationId;

  const ModernMessageInput({
    super.key,
    required this.onSend,
    this.onAttachmentPressed,
    this.onVoicePressed,
    this.onTyping,
    this.replyToMessage,
    this.onCancelReply,
    this.isEnabled = true,
    this.conversationId,
  });

  @override
  State<ModernMessageInput> createState() => _ModernMessageInputState();
}

class _ModernMessageInputState extends State<ModernMessageInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _isSending = false;

  // Typing indicator debounce
  Timer? _typingTimer;

  // انیمیشن دکمه ارسال
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    // ارسال Typing Indicator
    if (hasText && widget.conversationId != null) {
      _sendTypingIndicator();
    }
  }

  void _sendTypingIndicator() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onTyping?.call(widget.conversationId!);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _sendButtonController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    // انیمیشن دکمه
    await _sendButtonController.forward();
    await _sendButtonController.reverse();

    _controller.clear();
    widget.onSend(text);

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════════════════
            // Reply Preview
            // ═══════════════════════════════════════════════════════════
            if (widget.replyToMessage != null) _buildReplyPreview(theme),

            // ═══════════════════════════════════════════════════════════
            // Input Row
            // ═══════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // دکمه Attachment
                  _buildIconButton(
                    icon: Icons.attach_file,
                    onPressed: widget.onAttachmentPressed,
                  ),

                  // TextField
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.isEnabled,
                        maxLines: 5,
                        minLines: 1,
                        textDirection: TextDirection.rtl,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'پیام خود را بنویسید...',
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          // Emoji Button
                          prefixIcon: IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              // TODO: Show emoji picker
                            },
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // دکمه ارسال یا ضبط صدا
                  ScaleTransition(
                    scale: _sendButtonScale,
                    child: _hasText
                        ? _buildSendButton(theme)
                        : _buildVoiceButton(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reply Preview
  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyToMessage!.senderName ?? 'کاربر',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.replyToMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  /// دکمه آیکون
  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: Colors.grey.shade600,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// دکمه ارسال
  Widget _buildSendButton(ThemeData theme) {
    return Material(
      color: theme.primaryColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: _isSending ? null : _handleSend,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }

  /// دکمه ضبط صدا
  Widget _buildVoiceButton(ThemeData theme) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: widget.onVoicePressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            Icons.mic,
            color: Colors.grey.shade700,
            size: 24,
          ),
        ),
      ),
    );
  }
}

