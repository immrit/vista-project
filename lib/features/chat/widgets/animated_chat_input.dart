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
    this.onHeightChanged,
    this.onAutocomplete, // ✅ New callback
    this.enabled = true,
    this.isRecording = false,
    this.hint,
    this.reduceEffects = false,
    this.allowHeavyEffects = true,
    this.blurSigma = 8.0,
  });

  @override
  State<AnimatedChatInput> createState() => _AnimatedChatInputState();
}

class _AnimatedChatInputState extends State<AnimatedChatInput>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  double _lastReportedHeight = 0.0;
  bool _heightReportScheduled = false;

  // ── Keyboard animation tracking ──
  bool _isKeyboardAnimating = false;
  double _lastKeyboardHeight = 0.0;
  Timer? _keyboardAnimTimer;

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
    if (widget.focusNode?.hasFocus == true && _showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
      widget.onEmojiPickerToggled?.call(false);
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
  void didChangeMetrics() {
    // تشخیص تغییر ارتفاع کیبورد → فعال‌سازی حالت سبک (بدون BackdropFilter)
    final newHeight = WidgetsBinding
            .instance.platformDispatcher.views.first.viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if ((newHeight - _lastKeyboardHeight).abs() > 1.0) {
      _lastKeyboardHeight = newHeight;
      if (!_isKeyboardAnimating) {
        setState(() => _isKeyboardAnimating = true);
      }
      _keyboardAnimTimer?.cancel();
      _keyboardAnimTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _isKeyboardAnimating = false);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardAnimTimer?.cancel();
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
        _isKeyboardAnimating ||
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    final effectiveBlurSigma =
        shouldReduceEffects ? 0.0 : widget.blurSigma.clamp(0.0, 12.0);
    _reportHeightIfNeeded();

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
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: shouldReduceEffects
                    ? Container(
                        decoration: BoxDecoration(
                          color: theme.inputBackgroundColor.withOpacity(0.9),
                          border: Border.all(
                            color: theme.inputBorderColor.withOpacity(0.25),
                            width: 0.5,
                          ),
                        ),
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
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: effectiveBlurSigma,
                          sigmaY: effectiveBlurSigma,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.inputBackgroundColor.withOpacity(0.75),
                            border: Border.all(
                              color: theme.inputBorderColor.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
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
            ),

            // Emoji Picker (اگر باز باشد)
            if (_showEmojiPicker)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.inputBackgroundColor,
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
            color: theme.secondaryTextColor.withOpacity(0.6),
            fontSize: 15, // فونت کوچک‌تر
          ),
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
      buttonColor = const Color(0xFF3390EC); // آبی استاندارد رابط
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
