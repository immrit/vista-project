// lib/features/chat/widgets/animated_chat_input.dart
//
// Input پیام با انیمیشن‌های حرفه‌ای - نسخه کامل
//
// ویژگی‌ها:
// ✅ انیمیشن نرم دکمه ارسال
// ✅ تغییر آیکون با انیمیشن
// ✅ نمایش reply با انیمیشن slide
// ✅ انیمیشن expand برای متن چند خطی
// ✅ Emoji picker
// ✅ Voice recording با waveform
// ✅ Attachment sheet
//

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import '../services/chat_attachment_service.dart';
import 'chat_emoji_picker.dart';

class AnimatedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onVoice;
  final ValueChanged<String>? onChanged;

  // Reply
  final String? replyToContent;
  final String? replyToSenderName;
  final VoidCallback? onCancelReply;

  // Voice recording
  final Function(File file, int duration)? onVoiceRecorded;

  // State
  final bool enabled;
  final bool isRecording;
  final String? hint;

  const AnimatedChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.onAttachment,
    this.onVoice,
    this.onChanged,
    this.replyToContent,
    this.replyToSenderName,
    this.onCancelReply,
    this.onVoiceRecorded,
    this.enabled = true,
    this.isRecording = false,
    this.hint,
  });

  @override
  State<AnimatedChatInput> createState() => _AnimatedChatInputState();
}

class _AnimatedChatInputState extends State<AnimatedChatInput>
    with TickerProviderStateMixin {
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;
  late Animation<double> _sendButtonRotation;

  late AnimationController _replyController;
  late Animation<Offset> _replySlide;
  late Animation<double> _replyFade;

  // Voice recording
  final _attachmentService = ChatAttachmentService();
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  int _recordingDuration = 0;
  List<double> _waveformData = [];
  Timer? _durationTimer;

  // Emoji
  bool _showEmojiPicker = false;

  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _setupAnimations() {
    // انیمیشن دکمه ارسال
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sendButtonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sendButtonController,
        curve: Curves.elasticOut,
      ),
    );

    _sendButtonRotation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _sendButtonController,
        curve: Curves.easeOutBack,
      ),
    );

    // انیمیشن Reply
    _replyController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _replySlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _replyController,
        curve: Curves.easeOutCubic,
      ),
    );

    _replyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _replyController,
        curve: Curves.easeOut,
      ),
    );

    if (_hasText) {
      _sendButtonController.forward();
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  void didUpdateWidget(AnimatedChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // انیمیشن Reply
    if (widget.replyToContent != null && oldWidget.replyToContent == null) {
      _replyController.forward();
    } else if (widget.replyToContent == null &&
        oldWidget.replyToContent != null) {
      _replyController.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _sendButtonController.dispose();
    _replyController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 VOICE RECORDING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    final success = await _attachmentService.startVoiceRecording(
      onRecordingStateChanged: (isRecording) {
        if (!isRecording && mounted) {
          _handleRecordingEnd();
        }
      },
      onDurationChanged: (duration) {
        if (mounted) {
          setState(() => _recordingDuration = duration);
        }
      },
      onWaveformDataChanged: (data) {
        if (mounted) {
          setState(() => _waveformData = data);
        }
      },
    );

    if (success && mounted) {
      setState(() => _isRecording = true);

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording) {
          setState(() => _recordingDuration++);
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();

    final file = await _attachmentService.stopVoiceRecording();

    if (file != null && mounted) {
      widget.onVoiceRecorded?.call(file, _recordingDuration);
    }

    _resetRecording();
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    _durationTimer?.cancel();
    await _attachmentService.cancelVoiceRecording();
    _resetRecording();
  }

  void _handleRecordingEnd() {
    _resetRecording();
  }

  void _resetRecording() {
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _recordingDuration = 0;
      _waveformData = [];
    });
  }

  void _lockRecording() {
    HapticFeedback.mediumImpact();
    setState(() => _isRecordingLocked = true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 😊 EMOJI PICKER
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleEmojiPicker() {
    HapticFeedback.lightImpact();

    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      widget.focusNode?.requestFocus();
    } else {
      widget.focusNode?.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: selection.start + emoji.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.inputBackgroundColor,
        boxShadow: theme.inputShadow != null ? [theme.inputShadow!] : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            _buildReplyPreview(theme),

            // Recording overlay یا Input row
            if (_isRecording)
              _buildRecordingOverlay(theme)
            else
              _buildInputRow(theme),

            // Emoji picker
            if (_showEmojiPicker)
              ChatEmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                onBackspace: () {
                  final text = widget.controller.text;
                  if (text.isNotEmpty) {
                    widget.controller.text = text.substring(0, text.length - 1);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay(ChatTheme theme) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Cancel
          IconButton(
            onPressed: _cancelRecording,
            icon: Icon(Icons.delete_rounded, color: theme.errorColor),
          ),

          // Duration
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              color: theme.errorColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          // Waveform indicator
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final height = 4.0 +
                    (_waveformData.isNotEmpty && i < _waveformData.length
                        ? _waveformData[i % _waveformData.length] * 16
                        : (i % 3 + 1) * 4.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 3,
                  height: height,
                  decoration: BoxDecoration(
                    color: theme.errorColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          // Lock or Send
          if (_isRecordingLocked)
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.sendButtonColor,
                      theme.sendButtonColor.withBlue(
                        (theme.sendButtonColor.blue + 30).clamp(0, 255),
                      ),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            )
          else
            IconButton(
              onPressed: _lockRecording,
              icon: Icon(
                Icons.lock_outline_rounded,
                color: theme.secondaryTextColor,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildReplyPreview(ChatTheme theme) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _replyController,
        builder: (context, child) {
          if (_replyController.isDismissed) {
            return const SizedBox.shrink();
          }
          return SlideTransition(
            position: _replySlide,
            child: FadeTransition(
              opacity: _replyFade,
              child: child,
            ),
          );
        },
        child: widget.replyToContent != null
            ? Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.typingColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.replyToSenderName ?? 'پاسخ به',
                            style: TextStyle(
                              color: theme.typingColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.replyToContent!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.iconColor,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onCancelReply?.call();
                      },
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInputRow(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // دکمه Attachment
          _buildIconButton(
            icon: Icons.attach_file_rounded,
            onTap: widget.onAttachment,
            theme: theme,
          ),

          // دکمه Emoji
          _buildIconButton(
            icon: _showEmojiPicker
                ? Icons.keyboard_rounded
                : Icons.emoji_emotions_outlined,
            onTap: _toggleEmojiPicker,
            theme: theme,
          ),

          const SizedBox(width: 4),

          // فیلد متن
          Expanded(
            child: _buildTextField(theme),
          ),

          const SizedBox(width: 8),

          // دکمه ارسال / صدا
          _buildSendButton(theme),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required ChatTheme theme,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: theme.iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(ChatTheme theme) {
    return Focus(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              _isFocused ? theme.backgroundColor : theme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isFocused
                ? theme.sendButtonColor.withOpacity(0.5)
                : theme.inputBorderColor,
            width: _isFocused ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          maxLines: 5,
          minLines: 1,
          textInputAction: TextInputAction.newline,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'پیام خود را بنویسید...',
            hintStyle: TextStyle(
              color: theme.inputHintColor,
              fontSize: 15,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            isDense: true,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _buildSendButton(ChatTheme theme) {
    return AnimatedBuilder(
      animation: _sendButtonController,
      builder: (context, child) {
        // نمایش دکمه صدا یا ارسال
        if (_sendButtonController.isDismissed) {
          // دکمه صدا
          return _buildVoiceButton(theme);
        }

        // دکمه ارسال با انیمیشن
        return Transform.scale(
          scale: _sendButtonScale.value,
          child: Transform.rotate(
            angle: _sendButtonRotation.value * 3.14159,
            child: child,
          ),
        );
      },
      child: _buildSendButtonWidget(theme),
    );
  }

  Widget _buildVoiceButton(ChatTheme theme) {
    return GestureDetector(
      onLongPressStart: (_) {
        _startRecording();
      },
      onLongPressEnd: (_) {
        if (_isRecording && !_isRecordingLocked) {
          _stopRecording();
        }
      },
      onLongPressMoveUpdate: (details) {
        // اگه به بالا بکشه → قفل بشه
        if (details.offsetFromOrigin.dy < -50 && !_isRecordingLocked) {
          _lockRecording();
        }
        // اگه به چپ بکشه → لغو بشه
        if (details.offsetFromOrigin.dx < -100) {
          _cancelRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording
              ? theme.errorColor.withOpacity(0.2)
              : theme.sendButtonColor.withOpacity(0.1),
        ),
        child: Icon(
          Icons.mic_rounded,
          color: _isRecording ? theme.errorColor : theme.sendButtonColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSendButtonWidget(ChatTheme theme) {
    return GestureDetector(
      onTap: widget.enabled && _hasText
          ? () {
              HapticFeedback.lightImpact();
              widget.onSend();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.sendButtonColor,
              theme.sendButtonColor.withBlue(
                (theme.sendButtonColor.blue + 20).clamp(0, 255),
              ),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.sendButtonColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
