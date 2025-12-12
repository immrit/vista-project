import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../widgets/attachment_bottom_sheet.dart';
import '../../widgets/image_preview_bottom_sheet.dart';
import '../../../model/message_model.dart';

// Callbacks for the parent widget (ChatScreen)
class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File) onSendVoiceMessage;
  final Function(String, List<File>) onSendImages;
  final Function(File) onFileSelected;
  final BuildContext parentContext;
  final MessageModel? replyTo;
  final VoidCallback? onClearReply;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onSendVoiceMessage,
    required this.onSendImages,
    required this.onFileSelected,
    required this.parentContext,
    this.replyTo,
    this.onClearReply,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  // --- Controllers ---
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final RecorderController _recorderController;
  late final AnimationController _micIconAnimationController;
  late final AnimationController _slideCancelAnimationController;

  // --- State ---
  bool _hasText = false;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isPaused = false;
  bool _showEmojiPicker = false;
  int _recordingDuration = 0;
  Offset? _longPressStartPosition;
  Timer? _recordingTimer;

  // ✅ Flag برای کنترل animation کیبورد
  bool _isKeyboardReady = false;
  Timer? _keyboardReadyTimer;

  // --- Animations ---
  late Animation<double> _micIconScaleAnimation;
  late Animation<Offset> _slideCancelAnimation;

  // --- Constants ---
  static const double _lockThreshold = 80.0;
  static const double _cancelThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _textController.addListener(_onTextChanged);

    _micIconAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _micIconScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(
            parent: _micIconAnimationController, curve: Curves.easeOut));

    _slideCancelAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideCancelAnimation =
        Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideCancelAnimationController,
                curve: Curves.easeInOut));

    // ✅ آماده‌سازی کیبورد با تأخیر کوتاه
    _prepareKeyboardForFastOpen();
  }

  void _prepareKeyboardForFastOpen() {
    // بعد از 100ms، کیبورد آماده باز شدن سریع است
    _keyboardReadyTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isKeyboardReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _keyboardReadyTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _recorderController.dispose();
    _micIconAnimationController.dispose();
    _slideCancelAnimationController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    final newHasText = _textController.text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
    }
  }

  void _toggleEmojiPicker() {
    // ساده و بدون هیچ delay
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });

    if (!_showEmojiPicker) {
      // اگه emoji picker بسته شد، focus رو بده به text field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    } else {
      // اگه emoji picker باز شد، focus رو بردار
      _focusNode.unfocus();
    }
  }

  Future<void> _startRecording(Offset position) async {
    final hasPermission = await _recorderController.checkPermission();
    if (!hasPermission) return;

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorderController.record(path: path);

    _micIconAnimationController.forward();
    _slideCancelAnimationController.forward();

    setState(() {
      _isRecording = true;
      _isLocked = false;
      _longPressStartPosition = position;
      _recordingDuration = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingDuration++);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _recorderController.stop();
    _resetRecordingState();
    if (path != null) {
      widget.onSendVoiceMessage(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    await _recorderController.stop();
    _resetRecordingState();
  }

  void _resetRecordingState() {
    _micIconAnimationController.reverse();
    _slideCancelAnimationController.reverse();
    _recordingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _isPaused = false;
        _longPressStartPosition = null;
        _recordingDuration = 0;
      });
    }
  }

  void _lockRecording() {
    _micIconAnimationController.reverse();
    setState(() => _isLocked = true);
  }

  Future<void> _pauseRecording() async {
    await _recorderController.pause();
    _recordingTimer?.cancel();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    // RecorderController در audio_waveforms از resume پشتیبانی نمی‌کند
    // بنابراین ضبط جدید شروع می‌کنیم
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorderController.record(path: path);

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingDuration++);
    });
    setState(() => _isPaused = false);
  }

  void _handleSendMessage() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onSendMessage(_textController.text.trim());
      _textController.clear();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AttachmentBottomSheet(
        onImageSelected: (file) {
          // Single image selection - open preview
          showModalBottomSheet(
            context: widget.parentContext,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => ImagePreviewBottomSheet(
              files: [file],
              onConfirm: (confirmedFiles, caption) {
                if (confirmedFiles.isNotEmpty) {
                  widget.onSendImages(caption ?? '', confirmedFiles);
                }
              },
            ),
          );
        },
        onImagesSelected: (files) {
          // Multiple images selection - open preview
          showModalBottomSheet(
            context: widget.parentContext,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => ImagePreviewBottomSheet(
              files: files,
              onConfirm: (confirmedFiles, caption) {
                if (confirmedFiles.isNotEmpty) {
                  widget.onSendImages(caption ?? '', confirmedFiles);
                }
              },
            ),
          );
        },
        onFileSelected: widget.onFileSelected,
        onCameraSelected: () async {
          // This will be handled by the attachment bottom sheet
        },
        parentContext: widget.parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyTo != null) _buildReplyPreview(widget.replyTo!),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150), // کاهش مدت انیمیشن
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _isRecording ? _buildRecordingUI() : _buildStandardInput(),
            ),
          ),
          // ✅ بهینه‌سازی: استفاده از AnimatedSize به جای AnimatedContainer
          AnimatedSize(
            duration: const Duration(milliseconds: 200), // ✅ کاهش از ۳۰۰ به ۲۰۰
            curve: Curves.easeInOut,
            child: _showEmojiPicker
                ? SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        final text = _textController.text;
                        final selection = _textController.selection;
                        final newText = text.replaceRange(
                          selection.start,
                          selection.end,
                          emoji.emoji,
                        );
                        _textController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                            offset: selection.start + emoji.emoji.length,
                          ),
                        );
                      },
                      config: Config(
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          columns: 7,
                          emojiSizeMax: 32,
                          verticalSpacing: 0,
                          horizontalSpacing: 0,
                          gridPadding: EdgeInsets.zero,
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          iconColor: Colors.grey,
                          iconColorSelected:
                              Theme.of(context).colorScheme.primary,
                        ),
                        skinToneConfig: const SkinToneConfig(
                          enabled: true,
                        ),
                        bottomActionBarConfig: BottomActionBarConfig(
                          enabled: false,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(), // ✅ وقتی بسته است خالی
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(MessageModel reply) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.replyToSenderName ?? reply.senderName ?? 'کاربر',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reply.replyToContent?.isNotEmpty == true
                      ? reply.replyToContent!
                      : (reply.content.isNotEmpty
                          ? reply.content
                          : (reply.attachmentType == 'image'
                              ? ''
                              : reply.attachmentType == 'audio'
                                  ? 'صوت'
                                  : reply.attachmentType == 'document'
                                      ? 'فایل'
                                      : '')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              // Clear reply state in parent
              widget.onClearReply?.call();
              // Keep focus on input
              _focusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInput() {
    return Row(
      key: const ValueKey('standard_input'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
              _showEmojiPicker
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.7)),
          onPressed: _toggleEmojiPicker,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A) // رنگ تیره‌تر و حرفه‌ای‌تر برای تم تاریک
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('message_input'),
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // متن سفید برای تم تاریک
                          : Colors.black87, // متن تیره برای تم روشن
                      fontSize: 16,
                    ),
                    // ✅ بهینه‌سازی‌های performance برای کیبورد:
                    enableInteractiveSelection: true,
                    enableSuggestions: false, // غیرفعال برای عملکرد بهتر
                    autocorrect: false, // غیرفعال برای عملکرد بهتر
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    // ✅ کاهش rebuilds
                    buildCounter: null,
                    onTap: () {
                      if (!_isKeyboardReady) {
                        print('⌨️ Keyboard not ready yet - delaying');
                        return;
                      }

                      // فقط اگر emoji picker باز است، آن را ببند
                      if (_showEmojiPicker && mounted) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '...پیام',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[500] // hint تیره‌تر برای تم تاریک
                            : Colors.grey[600], // hint برای تم روشن
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isCollapsed: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: IconButton(
                    icon: Icon(Icons.attach_file_rounded,
                        color: Theme.of(context)
                            .iconTheme
                            .color
                            ?.withOpacity(0.7)),
                    onPressed: _showAttachmentBottomSheet,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150), // کاهش مدت زمان انیمیشن
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _hasText ? _buildSendButton() : _buildMicButton(),
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // ✅ استفاده از رنگ primary از theme، اما اگر سفید بود از رنگ جایگزین استفاده می‌کنیم
    Color primaryColor = theme.colorScheme.primary;
    
    // اگر رنگ primary سفید یا خیلی روشن است، از رنگ جایگزین استفاده می‌کنیم
    if (primaryColor.computeLuminance() > 0.8) {
      primaryColor = isDark 
          ? const Color(0xFF5DADEC) // آبی روشن برای تم تاریک
          : const Color(0xFF3390EC); // آبی استاندارد برای تم روشن
    }

    return Container(
      key: ValueKey(_isLocked ? 'locked_view' : 'recording_view'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // دکمه حذف با انیمیشن (فقط در حالت قفل شده)
          if (_isLocked)
            _buildAnimatedDeleteButton()
          else
            // نقطه قرمز ضربان‌دار + تایمر
            _buildPulsingRecordIndicator(),

          const SizedBox(width: 12),

          // ناحیه اصلی
          Expanded(
            child: _isLocked ? _buildLockedWaveform() : _buildSlideToCancel(),
          ),

          const SizedBox(width: 8),

          // دکمه‌های سمت راست
          _isLocked
              ? _buildSendVoiceButton(primaryColor)
              : _buildLockAndStopButtons(primaryColor),
        ],
      ),
    );
  }

  /// نقطه قرمز ضربان‌دار با تایمر
  Widget _buildPulsingRecordIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // نقطه قرمز ضربان‌دار
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return AnimatedBuilder(
              animation: _micIconAnimationController,
              builder: (context, child) {
                final pulse = 0.8 + (_micIconAnimationController.value * 0.4);
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

  /// دکمه حذف با انیمیشن
  Widget _buildAnimatedDeleteButton() {
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

  /// Waveform در حالت قفل شده
  Widget _buildLockedWaveform() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
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
              size: Size(double.infinity, 32),
              recorderController: _recorderController,
              waveStyle: WaveStyle(
                waveColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : const Color(0xFF3390EC),
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

  /// Slide to cancel با انیمیشن شورون
  Widget _buildSlideToCancel() {
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dx < -15) {
          _cancelRecording();
        }
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
              "برای لغو بکشید",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شورون‌های متحرک سبک تلگرام
  Widget _buildAnimatedChevrons() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
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
                color: Colors.grey.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }

  /// دکمه‌های قفل و توقف
  Widget _buildLockAndStopButtons(Color primaryColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // آیکون قفل با نشانگر کشیدن به بالا
        Column(
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
                _isLocked ? Icons.lock : Icons.lock_open_outlined,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// دکمه ارسال صدا
  Widget _buildSendVoiceButton(Color primaryColor) {
    final theme = Theme.of(context);
    
    // اگر رنگ primary سفید یا خیلی روشن است، از رنگ جایگزین استفاده می‌کنیم
    Color buttonColor = primaryColor;
    if (buttonColor.computeLuminance() > 0.8) {
      final isDark = theme.brightness == Brightness.dark;
      buttonColor = isDark 
          ? const Color(0xFF5DADEC) // آبی روشن برای تم تاریک
          : const Color(0xFF2196F3); // آبی استاندارد برای تم روشن
    }
    
    return GestureDetector(
      onTap: _stopRecordingAndSend,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor, // استفاده از رنگ solid
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white, // همیشه سفید برای کنتراست بهتر
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // ✅ در تم تاریک همیشه از رنگ آبی استاندارد استفاده می‌کنیم
    // در تم روشن از رنگ primary استفاده می‌کنیم
    final primaryColor = isDark 
        ? const Color(0xFF3390EC) // آبی استاندارد تلگرام برای تم تاریک
        : theme.colorScheme.primary;
    
    return InkWell(
      key: const ValueKey('send_button'),
      onTap: _handleSendMessage,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primaryColor,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white, // همیشه سفید برای کنتراست بهتر
          size: 24,
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onLongPressStart: (details) => _startRecording(details.globalPosition),
      onLongPressEnd: (details) {
        if (_isLocked) return;
        final dragOffsetX =
            details.globalPosition.dx - (_longPressStartPosition?.dx ?? 0);
        if (dragOffsetX < -_cancelThreshold) {
          _cancelRecording();
        } else {
          _stopRecordingAndSend();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (_isLocked) return;
        final dragOffsetY =
            details.globalPosition.dy - (_longPressStartPosition?.dy ?? 0);
        if (dragOffsetY < -_lockThreshold) {
          _lockRecording();
        }
      },
      // اضافه کردن gesture برای تشخیص slide to cancel
      onPanUpdate: (details) {
        if (!_isRecording || _isLocked) return;
        final dragOffsetX =
            details.globalPosition.dx - (_longPressStartPosition?.dx ?? 0);
        if (dragOffsetX < -_cancelThreshold) {
          _cancelRecording();
        }
      },
      child: ScaleTransition(
        scale: _micIconScaleAnimation,
        child: Container(
          key: const ValueKey('mic_button'),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200])!
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.mic_rounded,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300] // خاکستری روشن برای تم تاریک
                : Colors.grey[700], // خاکستری تیره برای تم روشن
            size: 24,
          ),
        ),
      ),
    );
  }
}
