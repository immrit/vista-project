// lib/features/chat/widgets/telegram_style_input.dart
//
// تکست‌باکس سبک تلگرام - پیاده‌سازی کامل و تخصصی
//
// ویژگی‌ها:
// ✅ افکت شیشه‌ای (Glassmorphism) با Blur
// ✅ انیمیشن ارتفاع دینامیک (تا 5 خط)
// ✅ دکمه‌های کناری (Emoji, Attach, Send/Voice)
// ✅ انیمیشن مورفینگ دکمه صدا/ارسال
// ✅ حالت ضبط صدا با Waveform
// ✅ Slide to Cancel
// ✅ Haptic Feedback
// ✅ Ripple Effects
//
// نحوه استفاده:
// ```dart
// TelegramStyleChatInput(
//   onSendMessage: (text) {
//     // ارسال پیام متنی
//     _chatRepository.sendMessage(text);
//   },
//   onSendVoiceMessage: (file) {
//     // ارسال پیام صوتی
//     _chatRepository.sendVoiceMessage(file);
//   },
//   onTextChanged: (text) {
//     // در حال تایپ...
//     _chatRepository.updateTypingStatus();
//   },
//   onAttachPressed: () {
//     // نمایش منوی ضمیمه
//     _showAttachmentMenu();
//   },
//   onGifSelected: (gifUrl) {
//     // ارسال GIF
//     _chatRepository.sendGif(gifUrl);
//   },
//   hint: 'پیام...',
//   enabled: true,
// )
// ```
//

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'vista_emoji_panel.dart';

class TelegramStyleChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File)? onSendVoiceMessage;
  final Function(String)? onTextChanged;
  final Function()? onAttachPressed;
  final Function(String)? onGifSelected;
  final String? hint;
  final bool enabled;

  const TelegramStyleChatInput({
    super.key,
    required this.onSendMessage,
    this.onSendVoiceMessage,
    this.onTextChanged,
    this.onAttachPressed,
    this.onGifSelected,
    this.hint,
    this.enabled = true,
  });

  @override
  State<TelegramStyleChatInput> createState() =>
      _TelegramStyleChatInputState();
}

class _TelegramStyleChatInputState extends State<TelegramStyleChatInput>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final RecorderController _recorderController;

  // State
  bool _hasText = false;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _showEmojiPicker = false;
  int _recordingDuration = 0;
  int _lineCount = 1;
  double _slideProgress = 0.0;
  Offset? _longPressStartPosition;

  // Animations
  late AnimationController _sendButtonController;
  late AnimationController _micIconController;
  late AnimationController _slideCancelController;
  late Animation<double> _micIconScaleAnimation;

  // Timers
  Timer? _recordingTimer;

  // Constants
  static const double _minHeight = 48.0;
  static const double _lineHeight = 20.0;
  static const double _maxLines = 5.0;
  static const double _lockThreshold = 80.0;
  static const double _cancelThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupRecorder();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _setupAnimations() {
    // انیمیشن دکمه ارسال
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // انیمیشن آیکون میکروفون
    _micIconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _micIconScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _micIconController,
        curve: Curves.easeOut,
      ),
    );

    // انیمیشن Slide to Cancel
    _slideCancelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupRecorder() {
    _recorderController = RecorderController();
  }

  void _onTextChanged() {
    if (!mounted) return;

    // محاسبه تعداد خطوط
    final text = _controller.text;
    final newLineCount = '\n'.allMatches(text).length + 1;
    final clampedLineCount = newLineCount.clamp(1, _maxLines.toInt());

    if (clampedLineCount != _lineCount) {
      setState(() => _lineCount = clampedLineCount);
    }

    // بررسی وجود متن
    final newHasText = text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
      if (newHasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }

    widget.onTextChanged?.call(text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  Future<void> _toggleEmojiPicker() async {
    HapticFeedback.lightImpact();

    if (_showEmojiPicker) {
      _focusNode.requestFocus();
      setState(() => _showEmojiPicker = false);
    } else {
      _focusNode.unfocus();
      // تاخیر کوتاه برای جلوگیری از پرش UI
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      setState(() => _showEmojiPicker = true);
    }
  }

  Future<void> _startRecording(Offset position) async {
    final hasPermission = await _recorderController.checkPermission();
    if (!hasPermission) return;

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorderController.record(path: path);

    _micIconController.forward();
    _slideCancelController.forward();

    setState(() {
      _isRecording = true;
      _isLocked = false;
      _longPressStartPosition = position;
      _recordingDuration = 0;
      _slideProgress = 0.0;
    });

    // تایمر برای شمارش زمان
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration++);
      }
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _recorderController.stop();
    _resetRecordingState();

    if (path != null && widget.onSendVoiceMessage != null) {
      widget.onSendVoiceMessage!(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    await _recorderController.stop();
    _resetRecordingState();
  }

  void _resetRecordingState() {
    _micIconController.reverse();
    _slideCancelController.reverse();
    _recordingTimer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _longPressStartPosition = null;
        _recordingDuration = 0;
        _slideProgress = 0.0;
      });
    }
  }

  void _lockRecording() {
    HapticFeedback.mediumImpact();
    _micIconController.reverse();
    setState(() => _isLocked = true);
  }

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSendMessage(_controller.text.trim());
      _controller.clear();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorderController.dispose();
    _sendButtonController.dispose();
    _micIconController.dispose();
    _slideCancelController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: keyboardHeight > 0 ? 8 : (bottomPadding > 0 ? bottomPadding + 4 : 8),
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // UI اصلی (Input یا Recording)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _isRecording
                    ? _buildRecordingUI(theme, isDark)
                    : _buildInputUI(theme, isDark),
              ),

              // Emoji Picker
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _showEmojiPicker
                    ? Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: keyboardHeight > 0 ? keyboardHeight : 300,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: VistaEmojiPanel(
                            controller: _controller,
                            height: keyboardHeight > 0 ? keyboardHeight : 300,
                            onGifSelected: widget.onGifSelected,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputUI(ThemeData theme, bool isDark) {
    return Container(
      key: const ValueKey('input'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // دکمه Emoji
          _buildIconButton(
            icon: _showEmojiPicker
                ? Icons.keyboard_alt_outlined
                : Icons.emoji_emotions_outlined,
            onPressed: _toggleEmojiPicker,
            isActive: _showEmojiPicker,
            theme: theme,
          ),
          const SizedBox(width: 4),

          // فیلد متنی با افکت شیشه‌ای
          Expanded(
            child: _buildTextField(theme, isDark),
          ),
          const SizedBox(width: 4),

          // دکمه Attach (فقط وقتی متن خالیه)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: !_hasText
                ? _buildIconButton(
                    key: const ValueKey('attach'),
                    icon: Icons.attach_file,
                    onPressed: widget.onAttachPressed ?? () {},
                    theme: theme,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          const SizedBox(width: 4),

          // دکمه Send/Voice
          _buildSendVoiceButton(theme),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      constraints: BoxConstraints(
        minHeight: _minHeight,
        maxHeight: _minHeight + (_lineCount - 1) * _lineHeight,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            maxLines: _maxLines.toInt(),
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            textDirection: TextDirection.rtl,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
              fontFamily: 'Vazir',
              fontFamilyFallback: const [
                'Apple Color Emoji',
                'Segoe UI Emoji',
                'Noto Color Emoji',
              ],
            ),
            enableInteractiveSelection: true,
            enableSuggestions: false,
            autocorrect: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            decoration: InputDecoration(
              hintText: widget.hint ?? 'پیام...',
              hintStyle: TextStyle(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    Key? key,
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
    bool isActive = false,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(24),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 24,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildSendVoiceButton(ThemeData theme) {
    if (_hasText) {
      // دکمه ارسال
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _sendMessage,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.send,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      // دکمه میکروفون با قابلیت long press
      return GestureDetector(
        onLongPressStart: (details) =>
            _startRecording(details.globalPosition),
        onLongPressEnd: (details) {
          if (_isLocked) return;
          final dragOffsetX = details.globalPosition.dx -
              (_longPressStartPosition?.dx ?? 0);
          if (dragOffsetX < -_cancelThreshold) {
            _cancelRecording();
          } else {
            _stopRecordingAndSend();
          }
        },
        onLongPressMoveUpdate: (details) {
          if (_isLocked) return;
          final dragOffsetY = details.globalPosition.dy -
              (_longPressStartPosition?.dy ?? 0);
          if (dragOffsetY < -_lockThreshold) {
            _lockRecording();
          }
          final dragOffsetX = details.globalPosition.dx -
              (_longPressStartPosition?.dx ?? 0);
          if (dragOffsetX < -_cancelThreshold) {
            _cancelRecording();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.mic,
                size: 22,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildRecordingUI(ThemeData theme, bool isDark) {
    return Container(
      key: ValueKey(_isLocked ? 'locked' : 'recording'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // دکمه حذف (فقط در حالت قفل شده)
          if (_isLocked)
            _buildDeleteButton(theme)
          else
            // نقطه قرمز ضربان‌دار + تایمر
            _buildPulsingRecordIndicator(theme),

          const SizedBox(width: 12),

          // ناحیه اصلی (Waveform یا Slide to Cancel)
          Expanded(
            child: _isLocked
                ? _buildLockedWaveform(theme, isDark)
                : _buildSlideToCancel(theme),
          ),

          const SizedBox(width: 8),

          // دکمه‌های سمت راست
          _isLocked
              ? _buildSendVoiceButtonInRecording(theme)
              : _buildLockButton(theme),
        ],
      ),
    );
  }

  Widget _buildPulsingRecordIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // نقطه قرمز ضربان‌دار
        AnimatedBuilder(
          animation: _micIconScaleAnimation,
          builder: (context, child) {
            final pulse = 0.8 + (_micIconScaleAnimation.value * 0.4);
            return Container(
              width: 12 * pulse,
              height: 12 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5 * pulse),
                    blurRadius: 8 * pulse,
                    spreadRadius: 2 * pulse,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        // تایمر
        Text(
          _formatDuration(_recordingDuration),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(ThemeData theme) {
    return GestureDetector(
      onTap: _cancelRecording,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.1),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.red,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLockedWaveform(ThemeData theme, bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // تایمر
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // Waveform
          Expanded(
            child: AudioWaveforms(
              size: const Size(double.infinity, 32),
              recorderController: _recorderController,
              waveStyle: WaveStyle(
                waveColor: isDark ? Colors.white70 : const Color(0xFF3390EC),
                extendWaveform: true,
                showMiddleLine: false,
                spacing: 4,
                waveThickness: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideToCancel(ThemeData theme) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (!_isRecording || _isLocked) return;
        setState(() {
          _slideProgress = (details.localPosition.dx / MediaQuery.of(context).size.width).clamp(0.0, 1.0);
          if (_slideProgress < 0.3) {
            _cancelRecording();
          }
        });
      },
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شورون‌های متحرک
            _buildAnimatedChevrons(),
            const SizedBox(width: 8),
            // متن
            Text(
              'برای لغو بکشید',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(
                  1.0 - _slideProgress,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedChevrons() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      onEnd: () {
        if (mounted && _isRecording && !_isLocked) {
          setState(() {});
        }
      },
      builder: (context, value, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((value + delay) % 1.0);
            final opacity = (1.0 - animValue).clamp(0.2, 0.8);
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.chevron_left,
                size: 16,
                color: Colors.grey.withOpacity(opacity * (1.0 - _slideProgress)),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLockButton(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.keyboard_arrow_up,
          size: 16,
          color: Colors.grey.withOpacity(0.6),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.1),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.lock_open_outlined,
            size: 18,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSendVoiceButtonInRecording(ThemeData theme) {
    return GestureDetector(
      onTap: _stopRecordingAndSend,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

