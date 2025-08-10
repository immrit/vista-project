import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async'; // اضافه کردن import برای Timer
import 'dart:math' as math; // اضافه کردن برای محاسبات ریاضی
import '../../widgets/audio_player_widget.dart';

/// مدل داده‌های پیام پاسخ
class ReplyData {
  final String message;
  final String user;

  const ReplyData({
    required this.message,
    required this.user,
  });
}

/// مدل داده‌های فایل انتخاب شده
class SelectedFile {
  final File? file;
  final Uint8List? bytes;
  final String? name;
  final String type; // 'image' یا 'audio'

  const SelectedFile({
    this.file,
    this.bytes,
    this.name,
    required this.type,
  });

  bool get hasFile => file != null || bytes != null;
}

/// ویجت اصلی جعبه ورودی چت
class ChatInputBox extends StatefulWidget {
  // کنترلرها و فوکوس
  final TextEditingController messageController;
  final FocusNode messageFocusNode;

  // رفتارها
  final VoidCallback toggleEmojiPicker;
  final VoidCallback pickImage;
  final VoidCallback sendMessage;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onReplyCancel;

  // رفتارهای صوتی
  final Function(File?, Uint8List?, String?)? onAudioRecorded;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;

  // وضعیت‌ها
  final bool showEmojiPicker;
  final bool isUploading;
  final bool isSending;
  final bool isRecordingAudio;
  final double uploadProgress;

  // داده‌ها
  final ReplyData? replyData;
  final SelectedFile? selectedImage;
  final SelectedFile? selectedAudio;
  final Widget? customImagePreview;
  final Function()? onAudioCancel;
  final Uint8List? selectedAudioBytes;
  final VoidCallback? onImageCancel;

  const ChatInputBox({
    Key? key,
    required this.messageController,
    required this.messageFocusNode,
    required this.toggleEmojiPicker,
    required this.pickImage,
    required this.sendMessage,
    required this.onEmojiSelected,
    this.onReplyCancel,
    this.onAudioRecorded,
    this.onStartRecording,
    this.onStopRecording,
    this.showEmojiPicker = false,
    this.isUploading = false,
    this.isSending = false,
    this.isRecordingAudio = false,
    this.uploadProgress = 0.0,
    this.replyData,
    this.selectedImage,
    this.selectedAudio,
    this.customImagePreview,
    this.onAudioCancel,
    this.selectedAudioBytes,
    this.onImageCancel,
  }) : super(key: key);

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox>
    with TickerProviderStateMixin {
  // کنترلرهای انیمیشن
  late AnimationController _replyController;
  late AnimationController _sendButtonController;
  late AnimationController _recordingController;
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _shakeController; // کنترلر لرزش برای خطا
  late AnimationController _successController; // کنترلر موفقیت

  // انیمیشن‌ها
  late Animation<double> _replyAnimation;
  late Animation<double> _sendButtonAnimation;
  late Animation<double> _recordingAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _recordingColorAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _shakeAnimation; // انیمیشن لرزش
  late Animation<double> _successAnimation; // انیمیشن موفقیت
  late Animation<double> _audioLevelAnimation; // انیمیشن سطح صدا
  late Animation<double> _recordingGlowAnimation; // انیمیشن درخشش ضبط

  // وضعیت‌ها
  bool _hasText = false;
  bool _hasFiles = false;
  double _recordingDuration = 0.0;
  double _audioLevel = 0.0;
  bool _isLongPress = false; // برای تشخیص لمس طولانی
  bool _showRecordingHint = false; // نمایش راهنما
  int _typingIndicator = 0; // برای نمایش نقطه‌های تایپ

  // متغیرهای جدید برای ضبط مدرن
  List<double> _audioLevels = []; // تاریخچه سطح صدا
  Timer? _audioLevelTimer; // تایمر برای به‌روزرسانی سطح صدا
  double _maxAudioLevel = 0.0; // حداکثر سطح صدا
  bool _isRecordingActive = false; // وضعیت فعال بودن ضبط

  // انیمیشن‌های جدید برای ضبط مدرن
  late AnimationController _audioLevelController;
  late AnimationController _recordingGlowController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
    _updateInitialStates();
    _startTypingIndicator();
  }

  void _addAudioLevel(double level) {
    setState(() {
      _audioLevels.add(level);
      if (_audioLevels.length > 120) {
        // طول موج روی صفحه
        _audioLevels.removeAt(0);
      }
    });
  }

  void _initializeAnimations() {
    // انیمیشن پاسخ
    _replyController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _replyAnimation = CurvedAnimation(
      parent: _replyController,
      curve: Curves.easeInOut,
    );

    // انیمیشن دکمه ارسال
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _sendButtonAnimation = CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.elasticOut,
    );

    // انیمیشن ضبط
    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _recordingAnimation = CurvedAnimation(
      parent: _recordingController,
      curve: Curves.easeInOut,
    );

    // انیمیشن پالس ضبط
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // انیمیشن رنگ ضبط
    _recordingColorAnimation = ColorTween(
      begin: Colors.grey[600],
      end: Colors.red,
    ).animate(_recordingAnimation);

    // انیمیشن طیف صدا
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _waveformAnimation = CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    );

    // انیمیشن لرزش
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticInOut,
    ));

    // انیمیشن موفقیت
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    // انیمیشن‌های جدید برای ضبط مدرن
    _audioLevelController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _audioLevelAnimation = CurvedAnimation(
      parent: _audioLevelController,
      curve: Curves.easeOut,
    );

    _recordingGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _recordingGlowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _recordingGlowController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupListeners() {
    widget.messageController.addListener(_onTextChanged);
  }

  void _updateInitialStates() {
    _hasText = widget.messageController.text.trim().isNotEmpty;
    _hasFiles = _checkHasFiles();

    if (widget.replyData != null) {
      _replyController.forward();
    }

    if (_hasText || _hasFiles) {
      _sendButtonController.forward();
    }

    if (widget.isRecordingAudio) {
      _startRecordingAnimation();
    }
  }

  @override
  void didUpdateWidget(ChatInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // مدیریت انیمیشن پاسخ
    if (widget.replyData != null && oldWidget.replyData == null) {
      _replyController.forward();
    } else if (widget.replyData == null && oldWidget.replyData != null) {
      _replyController.reverse();
    }

    // مدیریت انیمیشن ضبط
    if (widget.isRecordingAudio && !oldWidget.isRecordingAudio) {
      _startRecordingAnimation();
    } else if (!widget.isRecordingAudio && oldWidget.isRecordingAudio) {
      _stopRecordingAnimation();
    }

    // بررسی تغییر فایل‌ها
    final newHasFiles = _checkHasFiles();
    if (newHasFiles != _hasFiles) {
      setState(() => _hasFiles = newHasFiles);
      _updateSendButtonState();
    }
  }

  bool _checkHasFiles() {
    return (widget.selectedImage?.hasFile ?? false) ||
        (widget.selectedAudio?.hasFile ?? false);
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      _updateSendButtonState();
    }
  }

  void _updateSendButtonState() {
    if (_hasText || _hasFiles) {
      _sendButtonController.forward();
    } else {
      _sendButtonController.reverse();
    }
  }

  void _startRecordingAnimation() {
    _recordingController.forward();
    _pulseController.repeat(reverse: true);
    _waveformController.repeat(reverse: true);
    _audioLevelController.repeat(reverse: true);
    _recordingGlowController.repeat(reverse: true);
    _startRecordingTimer();
    _startAudioLevelSimulation();
    setState(() {
      _isRecordingActive = true;
      _audioLevels.clear();
      _maxAudioLevel = 0.0;
    });
  }

  void _stopRecordingAnimation() {
    _recordingController.reverse();
    _pulseController.stop();
    _pulseController.reset();
    _waveformController.stop();
    _waveformController.reset();
    _audioLevelController.stop();
    _audioLevelController.reset();
    _recordingGlowController.stop();
    _recordingGlowController.reset();
    _stopRecordingTimer();
    _stopAudioLevelSimulation();
    setState(() {
      _isRecordingActive = false;
    });
  }

  void _startRecordingTimer() {
    _recordingDuration = 0.0;
    _updateRecordingDuration();
  }

  void _stopRecordingTimer() {
    _recordingDuration = 0.0;
    setState(() {});
  }

  void _updateRecordingDuration() {
    if (widget.isRecordingAudio) {
      setState(() {
        _recordingDuration += 0.1;
        // شبیه‌سازی سطح صدا (در حالت واقعی از میکروفون دریافت می‌شود)
        _audioLevel =
            0.3 + (0.7 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
      });
      Future.delayed(
          const Duration(milliseconds: 100), _updateRecordingDuration);
    }
  }

  void _startAudioLevelSimulation() {
    _audioLevelTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isRecordingActive) return;

      final time = DateTime.now().millisecondsSinceEpoch / 1000;
      final baseLevel =
          0.3 + 0.25 * math.sin(time * 2) + 0.15 * math.sin(time * 4);
      final noise = (math.Random().nextDouble() - 0.5) * 0.1;
      final newLevel = (baseLevel + noise).clamp(0.0, 1.0);

      setState(() {
        _audioLevels.add(newLevel);
        if (_audioLevels.length > 60) {
          _audioLevels.removeAt(0);
        }
      });
    });
  }

  void _stopAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startTypingIndicator() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && !widget.isRecordingAudio) {
        setState(() {
          _typingIndicator = (_typingIndicator + 1) % 4;
        });
      }
    });
  }

  void _shakeOnError() {
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  void _showSuccessAnimation() {
    _successController.forward().then((_) => _successController.reverse());
  }

  void _handleLongPress() {
    if (!widget.isRecordingAudio && widget.onStartRecording != null) {
      setState(() => _isLongPress = true);
      widget.onStartRecording!();
    }
  }

  void _handleLongPressEnd() {
    if (_isLongPress && widget.onStopRecording != null) {
      setState(() => _isLongPress = false);
      widget.onStopRecording!();
      _showSuccessAnimation();
    }
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    _audioLevelTimer?.cancel();
    _replyController.dispose();
    _sendButtonController.dispose();
    _recordingController.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    _audioLevelController.dispose();
    _recordingGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // نمایش راهنما
        _buildOldRecordingHint(colorScheme),

        // پیش‌نمایش پاسخ
        _buildReplyPreview(isDark, colorScheme),

        // پیش‌نمایش فایل‌های انتخاب شده
        _buildFilePreview(isDark, colorScheme),

        // نوار پیشرفت آپلود
        _buildUploadProgress(colorScheme),

        // جعبه ورودی اصلی
        _buildMainInputBox(isDark, colorScheme),
      ],
    );
  }

  Widget _buildOldRecordingHint(ColorScheme colorScheme) {
    if (!_showRecordingHint) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              _shakeAnimation.value * 10 * (_typingIndicator % 2 == 0 ? 1 : -1),
              0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'برای ضبط صدا، دکمه میکروفون را نگه دارید',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(bool isDark, ColorScheme colorScheme) {
    if (widget.replyData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return SizeTransition(
      sizeFactor: _replyAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(_replyAnimation),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.8)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              right: BorderSide(
                color: colorScheme.primary,
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.reply_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پاسخ به ${widget.replyData!.user}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.replyData!.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.onReplyCancel != null)
                _buildActionButton(
                  icon: Icons.close_rounded,
                  onTap: widget.onReplyCancel!,
                  size: 32,
                  iconSize: 16,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(bool isDark, ColorScheme colorScheme) {
    final widgets = <Widget>[];

    // پیش‌نمایش تصویر
    if (widget.customImagePreview != null) {
      widgets.add(_buildFilePreviewCard(
        child: widget.customImagePreview!,
        onRemove: () => _removeFile('image'),
        colorScheme: colorScheme,
      ));
    } else if (widget.selectedImage?.hasFile ?? false) {
      widgets.add(_buildFilePreviewCard(
        child: _buildImagePreview(),
        onRemove: () => _removeFile('image'),
        colorScheme: colorScheme,
      ));
    }

    // پیش‌نمایش صوت
    if (widget.selectedAudio?.hasFile ?? false) {
      widgets.add(_buildFilePreviewCard(
        child: _buildAudioPreview(colorScheme),
        onRemove: () => _removeFile('audio'),
        colorScheme: colorScheme,
      ));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: widgets),
    );
  }

  Widget _buildFilePreviewCard({
    required Widget child,
    required VoidCallback onRemove,
    required ColorScheme colorScheme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close_rounded,
            onTap: onRemove,
            size: 32,
            iconSize: 16,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.image_rounded,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'تصویر انتخاب شده',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPreview(ColorScheme colorScheme) {
    // این تابع باید خود AudioPlayerWidget را برگرداند تا پیش‌نمایش پخش‌کننده نمایش داده شود.
    // اطلاعات نام فایل را می‌توان در خود AudioPlayerWidget یا در یک ویجت جداگانه نمایش دهید.
    return AudioPlayerWidget(
      audioUrl: widget.selectedAudio!.file != null
          ? widget.selectedAudio!.file!.path
          : '',
      audioBytes: widget.selectedAudio!.bytes,
      isPreview: true, // اضافه شد: برای نمایش حالت فشرده‌تر
      isMe: true, // فرض بر این است که این پیش‌نمایش برای کاربر فعلی است
      // می‌توانید نام فایل را به AudioPlayerWidget پاس دهید یا در اینجا نمایش دهید
      // مثلاً: title: widget.selectedAudio?.name,
    );
  }

  void _removeFile(String type) {
    if (type == 'audio') {
      if (widget.onAudioCancel != null) {
        widget.onAudioCancel!();
      }
    } else if (type == 'image') {
      if (widget.onImageCancel != null) {
        widget.onImageCancel!();
      }
    }
  }

  Widget _buildUploadProgress(ColorScheme colorScheme) {
    if (!widget.isUploading) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: widget.uploadProgress),
      builder: (context, value, child) {
        return Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: colorScheme.outline.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        );
      },
    );
  }

  Widget _buildMainInputBox(bool isDark, ColorScheme colorScheme) {
    final isTyping = _hasText || _hasFiles;
    final showCompactMode = isTyping && !widget.isRecordingAudio;
    final isRecording = widget.isRecordingAudio;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: isRecording
            ? colorScheme.error.withOpacity(0.1)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isRecording
                ? colorScheme.error.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: isRecording ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isRecording
              ? colorScheme.error.withOpacity(0.6)
              : showCompactMode
                  ? colorScheme.primary.withOpacity(0.4)
                  : colorScheme.outline.withOpacity(0.2),
          width: isRecording ? 2 : (showCompactMode ? 2 : 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // دکمه‌های عملیات - فقط عکس در حالت تایپ مخفی می‌شود، ایموجی همیشه نمایش داده می‌شود
          if (!isRecording)
            ..._buildActionButtons(colorScheme, showCompactMode),

          // فیلد متن یا نمایش ضبط صدا
          Expanded(
            child: isRecording
                ? _buildRecordingDisplay(colorScheme)
                : _buildTextField(isDark, colorScheme),
          ),

          // دکمه ارسال/توقف ضبط
          _buildSendButton(colorScheme),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
      ColorScheme colorScheme, bool showCompactMode) {
    final buttons = <Widget>[];

    // دکمه انتخاب تصویر - فقط در حالت تایپ مخفی می‌شود
    if (!showCompactMode) {
      buttons.add(
        _buildActionButton(
          icon: Icons.photo_camera_rounded,
          onTap: widget.pickImage,
          tooltip: 'ارسال تصویر',
          colorScheme: colorScheme,
        ),
      );
    }

    // دکمه ایموجی - همیشه نمایش داده می‌شود
    buttons.add(
      _buildActionButton(
        icon: widget.showEmojiPicker
            ? Icons.keyboard_rounded
            : Icons.emoji_emotions_rounded,
        onTap: widget.toggleEmojiPicker,
        tooltip: widget.showEmojiPicker ? 'نمایش کیبورد' : 'نمایش ایموجی',
        isActive: widget.showEmojiPicker,
        colorScheme: colorScheme,
      ),
    );

    return buttons;
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
    bool isActive = false,
    Color? color,
    double size = 40,
    double iconSize = 22,
    required ColorScheme colorScheme,
  }) {
    final effectiveColor = color ??
        (isActive
            ? colorScheme.primary
            : colorScheme.onSurface.withOpacity(0.6));

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.all(4),
          alignment: Alignment.center, // تراز در وسط
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Icon(
            icon,
            color: effectiveColor,
            size: iconSize,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }

    return button;
  }

  Widget _buildTextField(bool isDark, ColorScheme colorScheme) {
    final isTyping = _hasText || _hasFiles;
    final showCompactMode = isTyping && !widget.isRecordingAudio;
    final charCount = widget.messageController.text.length;
    final hasLongText = charCount > 100;

    return Container(
      constraints: BoxConstraints(
        minHeight: 36,
        maxHeight: showCompactMode && hasLongText ? 120 : 60,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // تراز در وسط
        children: [
          Expanded(
            child: Center(
              // تراز در وسط
              child: TextField(
                controller: widget.messageController,
                focusNode: widget.messageFocusNode,
                enabled: !widget.isRecordingAudio,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: showCompactMode && hasLongText ? 6 : 2,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: widget.isRecordingAudio
                      ? 'در حال ضبط صوت...'
                      : 'پیام خود را بنویسید...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true, // کاهش فضای داخلی
                ),
                onSubmitted: (_) {
                  if (_canSendMessage()) {
                    widget.sendMessage();
                  }
                },
              ),
            ),
          ),
          // نمایش تعداد کاراکترها فقط برای پیام‌های طولانی
          if (showCompactMode && hasLongText)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$charCount کاراکتر',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingDisplay(ColorScheme colorScheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // لغو ضبط
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.secondary),
            onPressed: widget.onAudioCancel,
          ),

          // موج میله‌ای
          Expanded(child: _buildModernWaveform(colorScheme)),

          const SizedBox(width: 8),

          // تایمر
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(width: 8),

          // توقف
          // InkWell(
          //   onTap: widget.onStopRecording,
          //   borderRadius: BorderRadius.circular(30),
          //   child: Container(
          //     padding: const EdgeInsets.all(8),
          //     decoration: const BoxDecoration(
          //       color: Colors.red,
          //       shape: BoxShape.circle,
          //     ),
          //     child:
          //         const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildModernWaveform(ColorScheme colorScheme) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomPaint(
        painter: ModernBarWaveformPainter(
          audioLevels: _audioLevels,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildRecordingStatus(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // آیکون ضبط با انیمیشن پالس
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3 * _pulseAnimation.value),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 2 * _pulseAnimation.value,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(width: 12),

        // زمان ضبط
        Text(
          _formatDuration(_recordingDuration),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            fontFamily: 'monospace',
          ),
        ),

        const SizedBox(width: 12),

        // نمایش سطح صدا فعلی
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.outline.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AnimatedBuilder(
              animation: _audioLevelAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _audioLevel,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getAudioLevelColor(_audioLevel, colorScheme),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingHint(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _recordingGlowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary
                .withOpacity(0.1 * _recordingGlowAnimation.value),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary
                  .withOpacity(0.3 * _recordingGlowAnimation.value),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'در حال ضبط صدا...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getAudioLevelColor(double level, ColorScheme colorScheme) {
    if (level < 0.3) return Colors.green;
    if (level < 0.7) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSendButton(ColorScheme colorScheme) {
    final isTyping = _hasText || _hasFiles;
    final showCompactMode = isTyping && !widget.isRecordingAudio;
    final isRecording = widget.isRecordingAudio;
    final canSend = _canSendMessage();

    return AnimatedBuilder(
      animation: _sendButtonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_sendButtonAnimation.value * 0.2),
          child: Container(
            margin: const EdgeInsets.all(4),
            child: Material(
              color: isRecording
                  ? Colors.red
                  : canSend
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              elevation: canSend ? 2 : 0,
              child: AnimatedBuilder(
                animation: isRecording
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(0.0),
                builder: (context, child) {
                  return Container(
                    decoration: isRecording
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red
                                    .withOpacity(0.3 * _pulseAnimation.value),
                                blurRadius: 8 * _pulseAnimation.value,
                                spreadRadius: 2 * _pulseAnimation.value,
                              ),
                            ],
                          )
                        : null,
                    child: GestureDetector(
                      onLongPress:
                          !isTyping && canSend ? _handleLongPress : null,
                      onLongPressEnd:
                          _isLongPress ? (_) => _handleLongPressEnd() : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isRecording
                            ? widget.onStopRecording
                            : canSend
                                ? (isTyping
                                    ? widget.sendMessage
                                    : widget.onStartRecording)
                                : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: _buildSendButtonContent(
                              colorScheme, isTyping, isRecording),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButtonContent(
      ColorScheme colorScheme, bool isTyping, bool isRecording) {
    if (widget.isUploading || widget.isSending) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    // اگر در حال ضبط صدا است، آیکون توقف نمایش بده
    if (isRecording) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9 + (_pulseAnimation.value * 0.1),
            child: const Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 20,
            ),
          );
        },
      );
    }

    // اگر در حال تایپ است، آیکون ارسال نمایش بده
    if (isTyping) {
      return const Icon(
        Icons.send_rounded,
        color: Colors.white,
        size: 20,
      );
    }

    // در غیر این صورت، آیکون میکروفون نمایش بده
    return const Icon(
      Icons.mic_rounded,
      color: Colors.white,
      size: 20,
    );
  }

  bool _canSendMessage() {
    // اگر در حال آپلود یا ارسال است، غیرفعال
    if (widget.isSending) {
      return false;
    }

    // اگر در حال ضبط صدا است، همیشه فعال (برای توقف)
    if (widget.isRecordingAudio) {
      return true;
    }

    // اگر متن یا فایل دارد، می‌تواند ارسال کند
    if (_hasText || _hasFiles) {
      return true;
    }

    // اگر هیچ چیز ندارد، می‌تواند ضبط صوت کند
    if (widget.onStartRecording != null) {
      return true;
    }

    return false;
  }
}

class ModernBarWaveformPainter extends CustomPainter {
  final List<double> audioLevels;
  final Color color;

  ModernBarWaveformPainter({
    required this.audioLevels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioLevels.isEmpty) return;

    const barWidth = 3.0;
    const space = 2.0;
    int maxBars = (size.width / (barWidth + space)).floor();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < maxBars && i < audioLevels.length; i++) {
      final level = audioLevels[audioLevels.length - 1 - i];
      final barHeight = level * size.height;
      final dx = size.width - (i * (barWidth + space)) - barWidth;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, (size.height - barHeight) / 2, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
