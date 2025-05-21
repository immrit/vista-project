import 'package:Vista/view/screen/chat/ChatScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatInputBox extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final bool showEmojiPicker;
  final Function() toggleEmojiPicker;
  final Function() pickImage;
  final Function() sendMessage;
  final Function(String) onEmojiSelected;
  final bool isUploading;
  final Widget? selectedImagePreview;

  const ChatInputBox({
    Key? key,
    required this.messageController,
    required this.messageFocusNode,
    required this.showEmojiPicker,
    required this.toggleEmojiPicker,
    required this.pickImage,
    required this.sendMessage,
    required this.onEmojiSelected,
    required this.isUploading,
    this.selectedImagePreview,
  }) : super(key: key);

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    widget.messageController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.messageController.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    final isComposing = widget.messageController.text.isNotEmpty;
    if (_isComposing != isComposing) {
      setState(() => _isComposing = isComposing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.pickImage,
                icon: const Icon(Icons.image),
                splashRadius: 20,
              ),
              IconButton(
                icon: Icon(widget.showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined),
                onPressed: widget.toggleEmojiPicker,
                splashRadius: 20,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 100,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[100]
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Scrollbar(
                    child: TextField(
                      controller: widget.messageController,
                      focusNode: widget.messageFocusNode,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (text) {
                        setState(() => _isComposing = text.isNotEmpty);
                      },
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.isUploading
                    ? Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _isComposing ? widget.sendMessage : null,
                        icon: const Icon(Icons.send),
                        color: _isComposing
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        splashRadius: 20,
                      ),
              ),
            ],
          ),
          if (widget.selectedImagePreview != null) widget.selectedImagePreview!,
        ],
      ),
    );
  }
}
