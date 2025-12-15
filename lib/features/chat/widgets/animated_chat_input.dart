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
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import '../services/voice_recorder_service.dart';
import 'vista_emoji_panel.dart';

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

  // GIF
  final Function(String gifUrl)? onGifSelected;

  // ✅ Emoji picker toggle callback
  final ValueChanged<bool>? onEmojiPickerToggled;

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
    this.onGifSelected,
    this.onEmojiPickerToggled,
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

  // Voice recording - با استفاده از VoiceRecorderService
  final _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  int _recordingDuration = 0;
  List<double> _waveformData = [];
  Timer? _durationTimer;
  StreamSubscription<double>? _amplitudeSub;

  // Emoji
  bool _showEmojiPicker = false;

  bool _hasText = false;

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
    _amplitudeSub?.cancel();
    _voiceRecorder.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 VOICE RECORDING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    // شروع ضبط با سرویس
    await _voiceRecorder.startRecording();

    if (mounted) {
      setState(() => _isRecording = true);

      // گوش دادن به تغییرات دامنه صدا
      _amplitudeSub = _voiceRecorder.amplitudeStream.listen((amp) {
        if (mounted && _isRecording) {
          setState(() {
            _waveformData.add(amp);
            // نگه داشتن آخر 40 مقدار برای display
            if (_waveformData.length > 40) {
              _waveformData.removeAt(0);
            }
          });
        }
      });

      // تایمر برای شمارش زمان
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording) {
          setState(() => _recordingDuration++);
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();

    // توقف ضبط و دریافت فایل
    final file = await _voiceRecorder.stopRecording();

    if (file != null && mounted) {
      widget.onVoiceRecorded?.call(file, _recordingDuration);
    }

    _resetRecording();
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();

    // لغو ضبط (حذف فایل)
    await _voiceRecorder.cancelRecording();
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
      widget.onEmojiPickerToggled?.call(false); // ✅ اضافه شد
    } else {
      widget.focusNode?.unfocus();
      setState(() => _showEmojiPicker = true);
      widget.onEmojiPickerToggled?.call(true); // ✅ اضافه شد
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // دریافت safe area برای پدینگ داخلی خود جزیره
    // توجه: ما در صفحه اصلی این ویجت را بالای کیبورد قرار می‌دهیم،
    // اما اگر کیبورد بسته باشد، باید فاصله از پایین (Home Indicator) را رعایت کنیم.
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // اگر کیبورد باز است، فاصله پایین کمی بیشتر باشد تا پیام‌ها از زیر دیده شوند
    // اگر بسته است، کمی فاصله بدهیم که روی خط هوم نیفتد
    final effectiveBottomPadding = keyboardHeight > 0
        ? 8.0
        : (bottomPadding > 0 ? bottomPadding + 4.0 : 14.0);

    return Container(
      // کانتینر بیرونی کاملاً شفاف تا پیام‌ها از اطرافش دیده شوند
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(6, 2, 6, effectiveBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🏝️ The Island (جزیره)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24), // باریک‌تر و ظریف‌تر
              // سایه ملایم برای جدا شدن از زمینه
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24), // باریک‌تر و ظریف‌تر
              child: BackdropFilter(
                // 💎 افکت شیشه‌ای (Blur) - کاهش یافته چون پس‌زمینه هم بلور است
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    // رنگ پس‌زمینه نیمه‌شفاف - کاهش opacity برای افکت شیشه‌ای بهتر
                    color: isDark
                        ? const Color(0xFF1C1C1E)
                            .withOpacity(0.70) // کاهش یافته برای شیشه‌ای بیشتر
                        : const Color(0xFFF9F9F9)
                            .withOpacity(0.65), // کاهش یافته برای شیشه‌ای بیشتر
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply Preview
                      _buildReplyPreview(theme),

                      // Input Row or Recording
                      if (_isRecording)
                        _buildRecordingOverlay(theme)
                      else
                        _buildInputRow(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Emoji Picker (اگر باز باشد)
          if (_showEmojiPicker)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: VistaEmojiPanel(
                  controller: widget.controller,
                  height: 300,
                  onGifSelected: (gifUrl) {
                    if (widget.onGifSelected != null) {
                      widget.onGifSelected!(gifUrl);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingOverlay(ChatTheme theme) {
    return Container(
      height: 50, // باریک‌تر
      margin:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // فاصله کمتر
      decoration: BoxDecoration(
        color: theme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24), // باریک‌تر
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
                padding: const EdgeInsets.fromLTRB(
                    12, 10, 12, 6), // پدینگ کمتر و باریک‌تر
                decoration: BoxDecoration(
                  color: theme.dividerColor
                      .withOpacity(0.05), // کمی رنگ پس زمینه برای ریپلای
                  border: Border(
                    bottom: BorderSide(
                      color:
                          theme.dividerColor.withOpacity(0.1), // خط بسیار محو
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36, // ارتفاع کمتر
                      decoration: BoxDecoration(
                        color: theme.typingColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8), // فاصله کمتر
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
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // باریک‌تر
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // تراز وسط برای دکمه‌ها
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

          const SizedBox(width: 3), // فاصله کمتر

          // فیلد متن
          Expanded(
            child: _buildTextField(theme),
          ),

          const SizedBox(width: 6), // فاصله کمتر

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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6), // باریک‌تر
          child: Icon(
            icon,
            color: theme.iconColor,
            size: 22, // آیکون کوچک‌تر
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(ChatTheme theme) {
    return Focus(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // ✅ حذف دکوریشن اضافی چون الان داخل یک جزیره هستیم
        // فقط اگر بخواهید فیلد متمایز باشد نگه دارید، اما برای استایل تلگرام X معمولا ترنسپرنت بهتر است
        decoration: const BoxDecoration(
          color: Colors.transparent,
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
            fontSize: 15, // فونت کمی کوچک‌تر
            fontFamily: 'Vazir',
            fontFamilyFallback: const [
              'Apple Color Emoji',
              'Segoe UI Emoji',
              'Noto Color Emoji',
            ],
          ),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'پیام...',
            hintStyle: TextStyle(
              color: theme.secondaryTextColor.withOpacity(0.6),
              fontSize: 15, // فونت کوچک‌تر
            ),
            border: InputBorder.none,
            // ✅ تنظیم پدینگ برای تراز شدن متن - باریک‌تر و وسط
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 12, // افزایش vertical برای تراز بهتر با دکمه‌ها
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
        width: 40, // کوچک‌تر
        height: 40, // کوچک‌تر
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording
              ? theme.errorColor.withOpacity(0.2)
              : theme.sendButtonColor.withOpacity(0.1),
        ),
        child: Icon(
          Icons.mic_rounded,
          color: _isRecording ? theme.errorColor : theme.sendButtonColor,
          size: 22, // آیکون کوچک‌تر
        ),
      ),
    );
  }

  Widget _buildSendButtonWidget(ChatTheme theme) {
    // ✅ در تم تاریک، اگر رنگ sendButtonColor سفید یا خیلی روشن است، از آبی استاندارد استفاده می‌کنیم
    Color buttonColor = theme.sendButtonColor;
    if (theme.isDark && buttonColor.computeLuminance() > 0.8) {
      buttonColor = const Color(0xFF3390EC); // آبی استاندارد تلگرام
    }

    return GestureDetector(
      onTap: widget.enabled && _hasText
          ? () {
              HapticFeedback.lightImpact();
              widget.onSend();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, // کوچک‌تر
        height: 40, // کوچک‌تر
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              buttonColor,
              buttonColor.withBlue(
                (buttonColor.blue + 20).clamp(0, 255),
              ),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.35),
              blurRadius: 6, // سایه کوچک‌تر
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 18, // آیکون کوچک‌تر
        ),
      ),
    );
  }
}
