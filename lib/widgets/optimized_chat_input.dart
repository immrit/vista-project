import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ✅ Optimized Chat Input - الهام‌گرفته از تلگرام
/// با Keyboard Warm-up برای باز شدن سریع‌تر
class OptimizedChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onAttachmentTap;
  final String? hintText;
  final int? maxLines;

  const OptimizedChatInput({
    super.key,
    required this.onSendMessage,
    this.onAttachmentTap,
    this.hintText,
    this.maxLines,
  });

  @override
  State<OptimizedChatInput> createState() => _OptimizedChatInputState();
}

class _OptimizedChatInputState extends State<OptimizedChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isKeyboardWarmedUp = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    // ✅ Keyboard Warm-up - الهام‌گرفته از تلگرام
    _warmUpKeyboard();
  }

  /// ✅ Pre-warming keyboard برای باز شدن سریع‌تر
  void _warmUpKeyboard() {
    // منتظر بمان تا اولین frame رندر شود
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ✅ فوکوس موقت برای warm-up کردن input system
      _focusNode.requestFocus();

      // بلافاصله unfocus کن (کاربر متوجه نمی‌شود)
      Future.microtask(() {
        if (mounted) {
          _focusNode.unfocus();
          _isKeyboardWarmedUp = true;
          print('✅ Keyboard warmed up');
        }
      });
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // ✅ Attachment Button
            if (widget.onAttachmentTap != null)
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: widget.onAttachmentTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

            if (widget.onAttachmentTap != null) const SizedBox(width: 8),

            // ✅ Text Input
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'پیام خود را بنویسید...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: widget.maxLines,
                textInputAction: TextInputAction.newline,
                // ✅ تنظیمات بهینه‌سازی
                autocorrect: true,
                enableSuggestions: true,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => _handleSend(),
              ),
            ),

            const SizedBox(width: 8),

            // ✅ Send Button
            IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
              onPressed: _handleSend,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}







