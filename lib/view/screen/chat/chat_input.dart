import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/attachment_bottom_sheet.dart';
import '../../widgets/image_preview_bottom_sheet.dart';
import '../../../model/message_model.dart';
import '../../../features/chat/widgets/vista_emoji_panel.dart';

// Callbacks for the parent widget (ChatScreen)
class ChatInput extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;
  final Function(File) onSendVoiceMessage;
  final Function(String, List<File>) onSendImages;
  final Function(File) onFileSelected;
  final Function(String)? onSendGif; // ✅ اضافه شده برای ارسال GIF
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
    this.onSendGif,
    this.replyTo,
    this.onClearReply,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
  bool _showEmojiPicker = false;
  int _recordingDuration = 0;
  Offset? _longPressStartPosition;
  Timer? _recordingTimer;

  // برای جلوگیری از پرش صفحه هنگام سوییچ بین کیبورد و ایموجی
  double _keyboardHeight = 0;
  static const double _defaultEmojiHeight = 280.0;

  // --- Animations ---
  late Animation<double> _micIconScaleAnimation;

  // --- Constants ---
  static const double _lockThreshold = 80.0;
  static const double _cancelThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorderController = RecorderController();
    _textController.addListener(_onTextChanged);

    _micIconAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _micIconScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(
            parent: _micIconAnimationController, curve: Curves.easeOut));

    _slideCancelAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    // لیسنر برای ارتفاع کیبورد جهت تنظیم ارتفاع پنل ایموجی
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    // محاسبه دقیق ارتفاع کیبورد از طریق WidgetsBinding
    if (!mounted) return;

    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom;
    final pixelRatio = view.devicePixelRatio;
    final logicalBottomInset = bottomInset / pixelRatio;

    if (logicalBottomInset > 0) {
      // کیبورد باز است
      if (_keyboardHeight != logicalBottomInset) {
        setState(() {
          _keyboardHeight = logicalBottomInset;
        });
      }
    } else {
      // کیبورد بسته است
      if (_keyboardHeight != 0) {
        setState(() {
          _keyboardHeight = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _toggleEmojiPicker() async {
    if (_showEmojiPicker) {
      // اگر پنل ایموجی باز است، کیبورد را باز کن
      _focusNode.requestFocus();
      setState(() {
        _showEmojiPicker = false;
      });
    } else {
      // اگر کیبورد باز است، اول ارتفاعش را ذخیره کن، بعد ببند و ایموجی را باز کن
      final currentFocus = FocusScope.of(context);
      if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
        FocusManager.instance.primaryFocus?.unfocus();
      }

      // تاخیر کوتاه برای جلوگیری از پرش UI هنگام بستن کیبورد
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      setState(() {
        _showEmojiPicker = true;
      });
    }
  }

  void _onPopInvokedWithResult(bool didPop, dynamic result) {
    if (didPop) return;
    // اگر پنل ایموجی باز بود، آن را می‌بندیم
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
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
        _longPressStartPosition = null;
        _recordingDuration = 0;
      });
    }
  }

  void _lockRecording() {
    _micIconAnimationController.reverse();
    setState(() => _isLocked = true);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // رنگ گلس متناسب با تم
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.65);

    return PopScope(
      canPop: !_showEmojiPicker, // اگر ایموجی باز باشد، اجازه خروج نده
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) _buildReplyPreview(widget.replyTo!),
            // کانتینر اصلی ورودی پیام با افکت شیشه‌ای
            Container(
              decoration: BoxDecoration(
                color: glassColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: _isRecording
                      ? _buildRecordingUI()
                      : _buildStandardInput(),
                ),
              ),
            ),
            // پنل ایموجی (زیر نوار)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showEmojiPicker
                  ? SizedBox(
                      height: _keyboardHeight > 0
                          ? _keyboardHeight
                          : _defaultEmojiHeight,
                      child: _buildEmojiPicker(),
                    )
                  : const SizedBox.shrink(),
            ),
            // یک فضای خالی کوچک برای آیفون‌های بدون دکمه هوم (SafeArea bottom)
            if (!_showEmojiPicker)
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
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
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      key: const ValueKey('standard_input'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // دکمه ایموجی (سمت چپ)
        _buildIconButton(
          icon: _showEmojiPicker
              ? Icons.keyboard_alt_outlined
              : Icons.emoji_emotions_outlined,
          onPressed: _toggleEmojiPicker,
          color: Colors.grey[600],
          activeColor: theme.primaryColor,
          isActive: _showEmojiPicker,
        ),

        // فیلد متنی (وسط)
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              // رنگ پس‌زمینه اینپوت (کمی متفاوت از گلس برای خوانایی)
              color:
                  isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textDirection: TextDirection.rtl, // پشتیبانی صریح از فارسی
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
                      hintText: 'پیام...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                    ),
                  ),
                ),
                // دکمه Attach (داخل فیلد سمت راست)
                _buildIconButton(
                  icon: Icons.attach_file_rounded,
                  onPressed: _showAttachmentBottomSheet,
                  color: Colors.grey[600],
                  padding: const EdgeInsets.only(bottom: 8, right: 8, left: 4),
                  rotate: -0.7, // زاویه دادن مثل تلگرام
                ),
              ],
            ),
          ),
        ),

        // دکمه ارسال / میکروفون (سمت راست)
        Padding(
          padding: const EdgeInsets.only(bottom: 2, right: 4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: _hasText
                ? _buildSendButton(theme) // دکمه ارسال (دایره آبی)
                : _buildMicButton(), // دکمه میکروفون (بدون پس‌زمینه)
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    Color? activeColor,
    bool isActive = false,
    EdgeInsetsGeometry? padding,
    double rotate = 0,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Transform.rotate(
            angle: rotate,
            child: Icon(
              icon,
              color: isActive
                  ? (activeColor ?? Colors.blue)
                  : (color ?? Colors.grey),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    final primaryColor = const Color(0xFF0088CC); // آبی تلگرام

    return Container(
      key: const ValueKey('send'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        onPressed: _handleSendMessage,
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      key: const ValueKey('mic'),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isRecording
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isRecording ? Icons.mic : Icons.mic_none_rounded,
            color: _isRecording ? Colors.red : Colors.grey[600],
            size: 28,
          ),
        ),
      ),
    );
  }

  // 1. این متد را برای مدیریت دریافت گیف اضافه/اصلاح کنید
  void _handleSendGif(String gifUrl) {
    print("🔷 ChatInput: Received GIF from Panel: $gifUrl");

    if (widget.onSendGif != null) {
      print("🔷 ChatInput: Forwarding to ChatScreen...");
      widget.onSendGif!(gifUrl);
    } else {
      print("❌ CRITICAL ERROR: widget.onSendGif is NULL in ChatInput!");
      // فال‌بک موقت: تلاش برای ارسال به عنوان پیام متنی اگر هندلر گیف نبود
      // widget.onSendMessage(gifUrl);
    }
  }

  // 2. متد ساخت پنل ایموجی را دقیقاً به این شکل تغییر دهید
  Widget _buildEmojiPicker() {
    return VistaEmojiPanel(
      // کلید یونیک برای اطمینان از بازسازی ویجت در صورت تغییر
      key: ValueKey('emoji_panel_${widget.onSendGif?.hashCode ?? 0}'),
      controller: _textController,
      height: _keyboardHeight > 0 ? _keyboardHeight : 300,

      // ✅ اتصال مستقیم متد هندلر
      onGifSelected: _handleSendGif,
    );
  }

  Widget _buildRecordingUI() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color primaryColor = theme.colorScheme.primary;
    if (primaryColor.computeLuminance() > 0.8) {
      primaryColor = isDark ? const Color(0xFF5DADEC) : const Color(0xFF3390EC);
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
                        color: Colors.red.withValues(alpha: 0.5 * pulse),
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
          color: Colors.red.withValues(alpha: 0.1),
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
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
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
                    ?.withValues(alpha: 0.5),
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
                color: Colors.grey.withValues(alpha: opacity),
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
              color: Colors.grey.withValues(alpha: 0.6),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
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

    Color buttonColor = primaryColor;
    if (buttonColor.computeLuminance() > 0.8) {
      final isDark = theme.brightness == Brightness.dark;
      buttonColor = isDark ? const Color(0xFF5DADEC) : const Color(0xFF2196F3);
    }

    return GestureDetector(
      onTap: _stopRecordingAndSend,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.4),
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
