import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

  // پارامترهای اضافی که ممکن است نیاز باشد
  final Function()? onReplyCancel;
  final String? replyToMessage;
  final String? replyToUser;
  final bool isSending;
  final double uploadProgress;

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
    this.onReplyCancel,
    this.replyToMessage,
    this.replyToUser,
    this.isSending = false,
    this.uploadProgress = 0.0,
  }) : super(key: key);

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox>
    with TickerProviderStateMixin {
  late AnimationController _replyAnimationController;
  late AnimationController _sendButtonController;
  late Animation<double> _replyAnimation;
  late Animation<double> _sendButtonAnimation;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _replyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _replyAnimation = CurvedAnimation(
      parent: _replyAnimationController,
      curve: Curves.easeInOut,
    );
    _sendButtonAnimation = CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.elasticOut,
    );

    widget.messageController.addListener(_onTextChanged);

    if (widget.replyToMessage != null) {
      _replyAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(ChatInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyToMessage != null && oldWidget.replyToMessage == null) {
      _replyAnimationController.forward();
    } else if (widget.replyToMessage == null &&
        oldWidget.replyToMessage != null) {
      _replyAnimationController.reverse();
    }
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      if (hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _replyAnimationController.dispose();
    _sendButtonController.dispose();
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

    return Column(
      children: [
        // Reply Preview با انیمیشن
        if (widget.replyToMessage != null)
          SizeTransition(
            sizeFactor: _replyAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(_replyAnimation),
              child: _buildReplyPreview(isDark),
            ),
          ),

        // Selected Image Preview (اگر عکس انتخاب شده باشد)
        if (widget.selectedImagePreview != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: widget.selectedImagePreview!,
          ),

        // Progress Indicator برای آپلود
        if (widget.isUploading)
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0, end: widget.uploadProgress),
            builder: (context, value, child) {
              return Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              );
            },
          ),

        // Input Container اصلی
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // دکمه انتخاب عکس
              _buildActionButton(
                icon: Icons.photo_camera_rounded,
                onTap: widget.pickImage,
                tooltip: 'ارسال عکس',
              ),

              // دکمه ایموجی
              _buildActionButton(
                icon: widget.showEmojiPicker
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_rounded,
                onTap: widget.toggleEmojiPicker,
                tooltip:
                    widget.showEmojiPicker ? 'نمایش کیبورد' : 'نمایش ایموجی',
                isActive: widget.showEmojiPicker,
              ),

              // Text Field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 120,
                  ),
                  child: TextField(
                    controller: widget.messageController,
                    focusNode: widget.messageFocusNode,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'پیام خود را بنویسید...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (_hasText && !widget.isSending) {
                        widget.sendMessage();
                      }
                    },
                    onChanged: (text) {
                      // این خط برای سازگاری با کد قبلی شما
                      setState(() => _hasText = text.trim().isNotEmpty);
                    },
                  ),
                ),
              ),

              // دکمه ارسال
              AnimatedBuilder(
                animation: _sendButtonAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.7 + (_sendButtonAnimation.value * 0.3),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      child: Material(
                        color: _hasText || widget.isSending
                            ? primaryColor
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: (_hasText && !widget.isSending)
                              ? widget.sendMessage
                              : null,
                          child: Container(
                            width: 40,
                            height: 40,
                            child: widget.isUploading || widget.isSending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  isActive ? primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? primaryColor
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 18,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پاسخ به ${widget.replyToUser ?? 'کاربر'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyToMessage ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.onReplyCancel != null)
            IconButton(
              onPressed: widget.onReplyCancel,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
