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
import '../services/voice_recorder_service.dart';
import 'liquid_glass_input_shell.dart';
import 'telegram_voice_recorder_bar.dart';
import 'voice_input_state.dart';

enum _VoiceHapticEvent {
  recordStart,
  recordLock,
  recordCancel,
  recordSend,
  sendTap,
  scheduleTap,
}

class AnimatedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onVoice;
  final VoidCallback? onScheduleMessage;

  // Restored Fields
  final ValueChanged<String>? onChanged;
  final String? replyToContent;
  final String? replyToSenderName;
  final VoidCallback? onCancelReply;
  final Function(File file, int duration)? onVoiceRecorded;
  final Function(String gifUrl)? onGifSelected;
  final ValueChanged<bool>? onEmojiPickerToggled;
  final ValueChanged<double>? onHeightChanged;

  // Autocomplete
  final Function(String? query, String type)?
      onAutocomplete; // type: '@' or '#'

  // State
  final bool enabled;
  final bool isRecording;
  final String? hint;
  final bool reduceEffects;
  final bool allowHeavyEffects;
  final double blurSigma;
  final VoiceInputPreset voicePreset;

  const AnimatedChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.onAttachment,
    this.onVoice,
    this.onScheduleMessage,
    this.onChanged,
    this.replyToContent,
    this.replyToSenderName,
    this.onCancelReply,
    this.onVoiceRecorded,
    this.onGifSelected,
    this.onEmojiPickerToggled,
    this.onHeightChanged,
    this.onAutocomplete, // ✅ New callback
    this.enabled = true,
    this.isRecording = false,
    this.hint,
    this.reduceEffects = false,
    this.allowHeavyEffects = true,
    this.blurSigma = 8.0,
    this.voicePreset = VoiceInputPreset.adaptive,
  });

  @override
  State<AnimatedChatInput> createState() => _AnimatedChatInputState();
}

class _AnimatedChatInputState extends State<AnimatedChatInput>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _hapticDebounce = Duration(milliseconds: 80);
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;
  late Animation<double> _sendButtonRotation;
  late AnimationController _replyController;
  late Animation<Offset> _replySlide;
  late Animation<double> _replyFade;

  // Voice recording - با استفاده از VoiceRecorderService
  final _voiceRecorder = VoiceRecorderService();
  final VoiceInputStateMachine _voiceStateMachine = VoiceInputStateMachine();
  int _recordingDuration = 0;
  List<double> _waveformData = [];
  Timer? _durationTimer;
  StreamSubscription<double>? _amplitudeSub;
  Offset _voiceDragOffset = Offset.zero;
  DateTime? _recordingStartedAt;
  DateTime? _lastWaveUpdateAt;
  bool _isCancelSwipeArmed = false;

  // Emoji
  bool _showEmojiPicker = false;

  bool _hasText = false;
  double _lastReportedHeight = 0.0;
  bool _heightReportScheduled = false;
  DateTime? _lastHapticAt;

  bool get _isRecording => _voiceStateMachine.isRecording;
  bool get _isRecordingLocked => _voiceStateMachine.isLocked;

  VoiceGestureThresholds get _activeVoiceThresholds {
    final mediaQuery = MediaQuery.of(context);
    return VoiceGestureThresholdsResolver.resolve(
      widget.voicePreset,
      devicePixelRatio: mediaQuery.devicePixelRatio,
      shortestSide: mediaQuery.size.shortestSide,
    );
  }

  void _fireHaptic(_VoiceHapticEvent event) {
    final now = DateTime.now();
    if (_lastHapticAt != null &&
        now.difference(_lastHapticAt!) < _hapticDebounce) {
      return;
    }
    _lastHapticAt = now;

    switch (event) {
      case _VoiceHapticEvent.recordStart:
      case _VoiceHapticEvent.recordLock:
        HapticFeedback.mediumImpact();
      case _VoiceHapticEvent.recordCancel:
        HapticFeedback.lightImpact();
      case _VoiceHapticEvent.recordSend:
      case _VoiceHapticEvent.sendTap:
      case _VoiceHapticEvent.scheduleTap:
        HapticFeedback.selectionClick();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    // ✅ گوش دادن به تغییر فوکوس برای بستن پنل ایموجی هنگام باز شدن کیبورد
    widget.focusNode?.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // وقتی کاربر روی text field می‌زنه در حالتی که emoji باز بوده
    if (widget.focusNode?.hasFocus == true && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      widget.onEmojiPickerToggled?.call(false);
      // کیبورد رو مطمئناً نمایش بده (tap روی text field همیشه کیبورد رو نمیاره)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        }
      });
    }
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
      _voiceStateMachine.setTyping(hasText);
      if (hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }

    widget.onChanged?.call(widget.controller.text);
    _checkForAutocomplete();
  }

  void _checkForAutocomplete() {
    if (widget.onAutocomplete == null) return;

    final text = widget.controller.text;
    final selection = widget.controller.selection;

    // Safety checks
    if (!selection.isValid || !selection.isCollapsed) {
      widget.onAutocomplete!(null, '');
      return;
    }

    final cursorPosition = selection.baseOffset;
    if (cursorPosition <= 0) {
      widget.onAutocomplete!(null, '');
      return;
    }

    // Find the word being typed
    // Search backwards for space or start of line
    int start = cursorPosition - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
      start--;
    }
    start++; // Move back to the first character of the word

    if (start >= cursorPosition) {
      widget.onAutocomplete!(null, '');
      return;
    }

    final word = text.substring(start, cursorPosition);

    if (word.startsWith('@')) {
      widget.onAutocomplete!(word.substring(1), '@');
    } else if (word.startsWith('#')) {
      widget.onAutocomplete!(word.substring(1), '#');
    } else {
      widget.onAutocomplete!(null, '');
    }
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
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode?.removeListener(_onFocusChange);
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
    _fireHaptic(_VoiceHapticEvent.recordStart);

    // شروع ضبط با سرویس
    await _voiceRecorder.startRecording();

    if (mounted) {
      _recordingStartedAt = DateTime.now();
      _lastWaveUpdateAt = null;
      _voiceStateMachine.startRecording();
      setState(() {
        _voiceDragOffset = Offset.zero;
        _isCancelSwipeArmed = false;
      });

      // گوش دادن به تغییرات دامنه صدا
      _amplitudeSub = _voiceRecorder.amplitudeStream.listen((amp) {
        if (mounted && _isRecording) {
          final now = DateTime.now();
          final reduceSampling =
              widget.reduceEffects || !widget.allowHeavyEffects;
          if (reduceSampling &&
              _lastWaveUpdateAt != null &&
              now.difference(_lastWaveUpdateAt!) <
                  const Duration(milliseconds: 120)) {
            return;
          }
          _lastWaveUpdateAt = now;
          setState(() {
            _waveformData.add(amp);
            final maxSamples = reduceSampling ? 20 : 40;
            if (_waveformData.length > maxSamples) {
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
    final thresholds = _activeVoiceThresholds;
    if (_recordingStartedAt != null &&
        DateTime.now().difference(_recordingStartedAt!) <
            thresholds.minRecordDuration) {
      await _cancelRecording();
      return;
    }
    final file = await _voiceRecorder.stopRecording();

    if (file != null && mounted) {
      _voiceStateMachine.markPreviewSend();
      _fireHaptic(_VoiceHapticEvent.recordSend);
      widget.onVoiceRecorded?.call(file, _recordingDuration);
    }

    _resetRecording();
  }

  Future<void> _cancelRecording() async {
    _fireHaptic(_VoiceHapticEvent.recordCancel);
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    _voiceStateMachine.markCancelSwipe();

    // لغو ضبط (حذف فایل)
    await _voiceRecorder.cancelRecording();
    _resetRecording();
  }

  void _resetRecording() {
    setState(() {
      _voiceStateMachine.reset(hasText: _hasText);
      _recordingDuration = 0;
      _waveformData = [];
      _voiceDragOffset = Offset.zero;
      _isCancelSwipeArmed = false;
      _recordingStartedAt = null;
    });
  }

  void _lockRecording() {
    _fireHaptic(_VoiceHapticEvent.recordLock);
    setState(() => _voiceStateMachine.lockRecording());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 😊 EMOJI PICKER
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleEmojiPicker() {
    HapticFeedback.selectionClick();

    if (_showEmojiPicker) {
      // Emoji → Keyboard
      setState(() => _showEmojiPicker = false);
      widget.onEmojiPickerToggled?.call(false);
      _showKeyboard();
    } else {
      // Keyboard → Emoji
      // اول به parent اطلاع می‌دیم تا ارتفاع کیبورد رو قبل از dismiss ضبط کنه
      widget.onEmojiPickerToggled?.call(true);
      setState(() => _showEmojiPicker = true);
      widget.focusNode?.unfocus();
    }
  }

  /// نمایش مطمئن کیبورد - هم requestFocus هم TextInput.show
  void _showKeyboard() {
    if (widget.focusNode?.hasFocus == true) {
      // focus داریم، مستقیم کیبورد رو نشون بده
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      widget.focusNode?.requestFocus();
      // بعد از اینکه focus برقرار شد، کیبورد رو نشون بده
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        }
      });
    }
  }

  void _reportHeightIfNeeded() {
    if (widget.onHeightChanged == null || _heightReportScheduled) return;
    _heightReportScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightReportScheduled = false;
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final newHeight = renderBox.size.height;
      if ((newHeight - _lastReportedHeight).abs() >= 1.0) {
        _lastReportedHeight = newHeight;
        widget.onHeightChanged!(newHeight);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInputFocused = widget.focusNode?.hasFocus == true;
    final shouldReduceEffects = widget.reduceEffects ||
        !widget.allowHeavyEffects ||
        widget.blurSigma <= 0.1 ||
        isInputFocused ||
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    final effectiveBlurSigma =
        shouldReduceEffects ? 0.0 : widget.blurSigma.clamp(0.0, 12.0);
    _reportHeightIfNeeded();

    // parent (modern_chat_screen) با Positioned همه positioning را handle می‌کند
    // ما فقط یک فاصله کوچک داخلی نیاز داریم
    const effectiveBottomPadding = 8.0;

    return RepaintBoundary(
      child: Container(
        // کانتینر بیرونی کاملاً شفاف تا پیام‌ها از اطرافش دیده شوند
        color: Colors.transparent,
        padding: EdgeInsets.fromLTRB(6, 2, 6, effectiveBottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🏝️ The Island (جزیره)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                // سایه بسیار ملایم و سبک
                boxShadow: shouldReduceEffects
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LiquidGlassInputShell(
                  reduceEffects: shouldReduceEffects,
                  isDark: isDark,
                  blurSigma: effectiveBlurSigma,
                  background: theme.inputBackgroundColor,
                  borderColor: theme.inputBorderColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildReplyPreview(theme),
                      if (_isRecording)
                        _buildRecordingOverlay(theme)
                      else
                        _buildInputRow(theme),
                    ],
                  ),
                ),
              ),
            ),

            // Emoji panel توسط parent (modern_chat_screen) رندر می‌شه
            // این ویجت فقط toggle را emit می‌کند
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay(ChatTheme theme) {
    return TelegramVoiceRecorderBar(
      theme: theme,
      isLocked: _isRecordingLocked,
      isCanceling: _isCancelSwipeArmed,
      durationSeconds: _recordingDuration,
      swipeProgress: _cancelProgress,
      lockProgress: _lockProgress,
      waveform: _waveformData,
      onCancel: _cancelRecording,
      onLock: _lockRecording,
      onSend: _stopRecording,
      onStopUnlocked: _stopRecording,
    );
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
                      .withValues(alpha: 0.05), // کمی رنگ پس زمینه برای ریپلای
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor
                          .withValues(alpha: 0.1), // خط بسیار محو
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
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: SizedBox(
              width: _hasText ? 0 : null,
              child: _hasText
                  ? const SizedBox.shrink()
                  : _buildIconButton(
                      icon: Icons.attach_file_rounded,
                      onTap: widget.onAttachment,
                      theme: theme,
                    ),
            ),
          ),

          // دکمه Emoji
          _buildIconButton(
            icon: _showEmojiPicker
                ? Icons.keyboard_rounded
                : Icons.emoji_emotions_outlined,
            onTap: _toggleEmojiPicker,
            theme: theme,
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: _hasText
                ? _buildIconButton(
                    icon: Icons.schedule_send_rounded,
                    onTap: () {
                      _fireHaptic(_VoiceHapticEvent.scheduleTap);
                      widget.onScheduleMessage?.call();
                    },
                    theme: theme,
                  )
                : const SizedBox.shrink(),
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

  /// Detect text direction based on first strong character
  TextDirection _detectTextDirection(String text) {
    if (text.isEmpty) return TextDirection.rtl; // Default for Persian app

    // Skip whitespace and find first meaningful character
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // Skip whitespace
      if (char == ' ' || char == '\n' || char == '\t') continue;

      // Special characters @ # stay with their following content
      if (char == '@' || char == '#') {
        // Look at next char to determine direction
        if (i + 1 < text.length) {
          final nextChar = text[i + 1].codeUnitAt(0);
          // If next char is RTL, use RTL
          if ((nextChar >= 0x0600 && nextChar <= 0x06FF) || // Arabic
              (nextChar >= 0x0750 && nextChar <= 0x077F) || // Arabic Supplement
              (nextChar >= 0xFB50 &&
                  nextChar <= 0xFDFF) || // Arabic Presentation Forms-A
              (nextChar >= 0xFE70 && nextChar <= 0xFEFF)) {
            // Arabic Presentation Forms-B
            return TextDirection.rtl;
          }
          return TextDirection.ltr; // Otherwise LTR
        }
        return TextDirection.ltr; // Just @ or # alone - LTR
      }

      // Numbers - continue to next char
      if (code >= 0x30 && code <= 0x39) continue; // 0-9

      // Persian/Arabic digits
      if ((code >= 0x06F0 && code <= 0x06F9) || // Persian digits
          (code >= 0x0660 && code <= 0x0669)) {
        // Arabic digits
        return TextDirection.rtl;
      }

      // Check for RTL characters (Arabic, Persian, Hebrew, etc.)
      if ((code >= 0x0600 && code <= 0x06FF) || // Arabic
          (code >= 0x0750 && code <= 0x077F) || // Arabic Supplement
          (code >= 0xFB50 && code <= 0xFDFF) || // Arabic Presentation Forms-A
          (code >= 0xFE70 && code <= 0xFEFF) || // Arabic Presentation Forms-B
          (code >= 0x0590 && code <= 0x05FF)) {
        // Hebrew
        return TextDirection.rtl;
      }

      // LTR characters (Latin)
      if ((code >= 0x0041 && code <= 0x005A) || // A-Z
          (code >= 0x0061 && code <= 0x007A)) {
        // a-z
        return TextDirection.ltr;
      }

      // Other punctuation - continue
    }

    return TextDirection.rtl; // Default for Persian app
  }

  Widget _buildTextField(ChatTheme theme) {
    // Get current text direction based on content
    final textDirection = _detectTextDirection(widget.controller.text);
    final textAlign =
        textDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left;

    return Focus(
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        maxLines: 5,
        minLines: 1,
        maxLength: 4000,
        textInputAction: TextInputAction.newline,
        textDirection: textDirection,
        textAlign: textAlign,
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
          filled: false, // جلوگیری از رنگ پس‌زمینه پیش‌فرض تم
          hintText: widget.hint ?? 'پیام...',
          hintStyle: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.6),
            fontSize: 15, // فونت کوچک‌تر
          ),
          counterText: "", // Hide the counter
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          // ✅ تنظیم پدینگ برای تراز شدن متن - باریک‌تر و وسط
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12, // افزایش vertical برای تراز بهتر با دکمه‌ها
          ),
          isDense: true,
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
      onLongPressMoveUpdate: (details) => _handleVoiceDragUpdate(details),
      onLongPressUp: _handleVoiceDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, // کوچک‌تر
        height: 40, // کوچک‌تر
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording
              ? theme.errorColor.withValues(alpha: 0.2)
              : theme.sendButtonColor.withValues(alpha: 0.1),
        ),
        child: Icon(
          Icons.mic_rounded,
          color: _isRecording ? theme.errorColor : theme.sendButtonColor,
          size: 22, // آیکون کوچک‌تر
        ),
      ),
    );
  }

  void _handleVoiceDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isRecordingLocked) return;
    final drag = details.offsetFromOrigin;
    final thresholds = _activeVoiceThresholds;

    final cancelReady = drag.dx <= -thresholds.cancelDragDistance;
    final lockReady = drag.dy <= -thresholds.lockDragDistance;

    setState(() {
      _voiceDragOffset = drag;
      _isCancelSwipeArmed = cancelReady;
    });

    if (lockReady && !_isRecordingLocked) {
      _lockRecording();
    } else if (cancelReady) {
      _cancelRecording();
    }
  }

  void _handleVoiceDragEnd() {
    if (!_isRecording || _isRecordingLocked) return;
    if (_isCancelSwipeArmed) {
      _cancelRecording();
      return;
    }
    _stopRecording();
  }

  double get _cancelProgress {
    if (_voiceDragOffset.dx >= 0) return 0;
    return (-_voiceDragOffset.dx / _activeVoiceThresholds.cancelDragDistance)
        .clamp(0.0, 1.0);
  }

  double get _lockProgress {
    if (_voiceDragOffset.dy >= 0) return 0;
    return (-_voiceDragOffset.dy / _activeVoiceThresholds.lockDragDistance)
        .clamp(0.0, 1.0);
  }

  Widget _buildSendButtonWidget(ChatTheme theme) {
    // ✅ در تم تاریک، اگر رنگ sendButtonColor سفید یا خیلی روشن است، از آبی استاندارد استفاده می‌کنیم
    Color buttonColor = theme.sendButtonColor;
    if (theme.isDark && buttonColor.computeLuminance() > 0.8) {
      buttonColor = const Color(0xFF3390EC); // آبی استاندارد رابط
    }

    return GestureDetector(
      onTap: widget.enabled && _hasText
          ? () {
              _fireHaptic(_VoiceHapticEvent.sendTap);
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
                ((buttonColor.b * 255.0).round() + 20).clamp(0, 255),
              ),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.35),
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
