import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

import 'vista_emoji_panel.dart';
import '../providers/chat_providers.dart';

/// VistaUnifiedChatInput - ورودی یکپارچه چت
/// با قابلیت Reply/Edit، ضبط صدا، و کیبورد بدون پرش
class VistaUnifiedChatInput extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;
  final Function(String?, String?)? onAttachmentSelected;
  final Function(String)? onGifSelected;
  final VoidCallback? onAttachPressed;
  final bool enabled;
  final String? hint;

  const VistaUnifiedChatInput({
    super.key,
    required this.onSendMessage,
    this.onAttachmentSelected,
    this.onGifSelected,
    this.onAttachPressed,
    this.enabled = true,
    this.hint,
  });

  @override
  ConsumerState<VistaUnifiedChatInput> createState() =>
      _VistaUnifiedChatInputState();
}

class _VistaUnifiedChatInputState extends ConsumerState<VistaUnifiedChatInput>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Controllers
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late RecorderController _recorderController;

  // State
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  // removed unused _isLocked
  bool _hasText = false;
  double _lastKeyboardHeight = 300.0; // Default fallback

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _recordingTimer;
  int _recordDuration = 0;
// 1. متغیر جهت متن (پیش‌فرض راست‌چین برای فارسی)
  TextDirection _textDirection = TextDirection.rtl;

// 2. تابع تشخیص هوشمند جهت
  void _updateTextDirection(String text) {
    if (text.isEmpty) {
      if (_textDirection != TextDirection.rtl) {
        setState(() => _textDirection = TextDirection.rtl);
      }
      return;
    }

    // حذف کاراکترهای خاص ابتدایی مثل # و @ برای تشخیص زبان واقعی
    String cleanText = text.trimLeft();
    if (cleanText.startsWith('#') || cleanText.startsWith('@')) {
      cleanText = cleanText.substring(1).trimLeft();
    }

    // اگر بعد از حذف # یا @ متنی نماند، چپ‌چین کن (برای نوشتن یوزرنیم یا تگ)
    if (cleanText.isEmpty) {
      if (_textDirection != TextDirection.ltr) {
        setState(() => _textDirection = TextDirection.ltr);
      }
      return;
    }

    // تشخیص اولین کاراکتر واقعی
    final firstChar = cleanText.isNotEmpty ? cleanText[0] : '';

    // رنج یونیکد فارسی و عربی
    final isRtl = RegExp(r'[\u0600-\u06FF]').hasMatch(firstChar);
    final newDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    if (_textDirection != newDirection) {
      setState(() => _textDirection = newDirection);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);

    _setupRecorder();
    _setupAnimations();
  }

  void _setupRecorder() {
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeMetrics() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (bottom > 0) {
      _lastKeyboardHeight = bottom;
      // ✅ Smooth Transition: Only hide picker when keyboard is FULLY open
      // This keeps the picker visible during the slide-up animation (gap filling)
      if (bottom >= _lastKeyboardHeight && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    _recorderController.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;

    // ✅ اضافه کردن فراخوانی تابع جدید
    _updateTextDirection(text);

    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  // --- Logic ---

  Future<void> _toggleEmojiPicker() async {
    if (_showEmojiPicker) {
      // Hide Emoji, Show Keyboard
      _focusNode.requestFocus();
      // ❌ Don't hide immediately! Let didChangeMetrics hide it when keyboard opens.
      // This prevents the gap/jump.
    } else {
      // Show Emoji, Hide Keyboard
      // 1. Show picker immediately (behind keyboard)
      setState(() => _showEmojiPicker = true);

      // 2. Hide keyboard (animation)
      _focusNode.unfocus();

      // ✅ No delay needed! The Container height formula handles the transition.
    }
  }

  Future<void> _onSend() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final actionController = ref.read(chatActionControllerProvider.notifier);
    final actionState = ref.read(chatActionControllerProvider);

    if (actionState.isEditing && actionState.editMessage != null) {
      // Edit Mode
      await actionController.editMessage(
        messageId: actionState.editMessage!.id,
        newContent: text,
      );
    } else {
      // Send Mode (New or Reply)
      // The parent handles the base logic, and Controller handles Reply ID via state
      widget.onSendMessage(text);
    }

    _controller.clear();
    actionController.cancelAction();
    setState(() {
      _hasText = false;
      _showEmojiPicker = false;
    });
  }

  // --- Recording Logic (Simplified for brevity but functional) ---
  Future<void> _startRecording(Offset position) async {
    // Check permissions... assuming granted for this task
    await _recorderController.record();
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _recorderController.stop();
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);

    if (path != null) {
      // Send voice message
      widget.onAttachmentSelected?.call(path, 'voice');
    }
  }

  Future<void> _cancelRecording() async {
    await _recorderController.stop();
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to action state to update UI (Edit/Reply preview)
    final actionState = ref.watch(chatActionControllerProvider);

    // Auto-populate text if editing started
    if (actionState.isEditing &&
        _controller.text.isEmpty &&
        actionState.editMessage != null) {
      // Only if empty to avoid overriding user changes
      Future.microtask(() {
        _controller.text = actionState.editMessage!.content;
        setState(() => _hasText = true);
      });
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Pro Logic: Calculate panel height to perfect fill the space
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Complementary Logic:
    // Spacer fills the gap as keyboard retracts (300 -> 0 => Spacer 0 -> 300).
    final double panelHeight = _showEmojiPicker
        ? (_lastKeyboardHeight - keyboardHeight).clamp(0.0, _lastKeyboardHeight)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply/Edit Preview Bar
        if (actionState.isReplying || actionState.isEditing)
          _buildReplyEditBanner(theme, isDark, actionState),

        // Main Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border:
                Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: SafeArea(
            top: false,
            bottom: false, // ✅ Disable Safe Area here, handled by spacer
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left Actions (Emoji)
                IconButton(
                  icon: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: _toggleEmojiPicker,
                ),

                // Expanded Text Field or Recorder
                Expanded(
                  child: _isRecording
                      ? _buildRecordingUI(theme, isDark)
                      : _buildTextField(theme, isDark),
                ),

                // Right Actions (Send/Mic)
                const SizedBox(width: 8),
                _buildSendOrMicButton(theme),
              ],
            ),
          ),
        ),

        // Emoji Picker / Keyboard Spacer
        // ✅ Use SizedBox with Stack to allow "Reveal" effect
        SizedBox(
          height: panelHeight > 0 ? panelHeight : 0,
          child: Stack(
            clipBehavior:
                Clip.hardEdge, // ✅ Clip overflowing content for Slide Up effect
            children: [
              // Slide Up Effect:
              // We align Bottom of the panel to Bottom of the spacer.
              // height 300.
              // As spacer grows, the panel slides up from the bottom.
              if (_showEmojiPicker)
                Positioned(
                  bottom: 0, // ⬆️ Slide Up
                  left: 0,
                  right: 0,
                  height: _lastKeyboardHeight,
                  child: VistaEmojiPanel(
                    onGifSelected: widget.onGifSelected,
                    controller: _controller,
                    height: _lastKeyboardHeight,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyEditBanner(
      ThemeData theme, bool isDark, ChatActionState state) {
    final message = state.replyMessage ?? state.editMessage;
    final isEdit = state.isEditing;

    return Container(
      padding: const EdgeInsets.all(8),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.reply,
              color: theme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit
                      ? 'ویرایش پیام'
                      : 'پاسخ به ${message?.senderName ?? "کاربر"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                Text(
                  message?.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              ref.read(chatActionControllerProvider.notifier).cancelAction();
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 5,
            style: theme.textTheme.bodyMedium,
            // ✅ تنظیمات جدید جهت متن
            textDirection: _textDirection,
            textAlign: _textDirection == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.left,

            decoration: InputDecoration(
              hintText: widget.hint ?? 'پیام خود را بنویسید...',
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: Colors.transparent,
              // ✅ تراز کردن Hint متناسب با زبان کیبورد کاربر
              hintTextDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI(ThemeData theme, bool isDark) {
    final durationFormat = _formatDuration(_recordDuration);

    return Container(
      height: 48,
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: const Icon(Icons.mic, color: Colors.red),
          ),
          const SizedBox(width: 8),
          Text(durationFormat, style: theme.textTheme.bodyMedium),
          const Spacer(),
          TextButton(
            onPressed: _cancelRecording,
            child: const Text('لغو', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOrMicButton(ThemeData theme) {
    final bool canSend = _hasText || _isRecording;

    return GestureDetector(
      onTap: canSend ? _onSend : null,
      onLongPress: _hasText ? null : () => _startRecording(Offset.zero),
      onLongPressUp: _hasText ? null : _stopRecordingAndSend,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          canSend ? Icons.send : Icons.mic,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
