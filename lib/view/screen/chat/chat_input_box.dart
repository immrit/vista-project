import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

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

  // انیمیشن‌ها
  late Animation<double> _replyAnimation;
  late Animation<double> _sendButtonAnimation;
  late Animation<double> _recordingAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _recordingColorAnimation;

  // وضعیت‌ها
  bool _hasText = false;
  bool _hasFiles = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
    _updateInitialStates();
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
  }

  void _stopRecordingAnimation() {
    _recordingController.reverse();
    _pulseController.stop();
    _pulseController.reset();
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    _replyController.dispose();
    _sendButtonController.dispose();
    _recordingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
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
    // اطلاعات نام فایل را می‌توان در خود AudioPlayerWidget یا در یک ویجت جداگانه نمایش داد.
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
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // دکمه‌های عملیات
          ..._buildActionButtons(colorScheme),

          // فیلد متن
          _buildTextField(isDark, colorScheme),

          // دکمه ارسال
          _buildSendButton(colorScheme),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(ColorScheme colorScheme) {
    final buttons = <Widget>[];

    // دکمه میکروفون
    if (widget.onAudioRecorded != null) {
      buttons.add(
        AnimatedBuilder(
          animation: _recordingAnimation,
          builder: (context, child) {
            return AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final pulseScale = widget.isRecordingAudio
                    ? 1.0 + (_pulseAnimation.value * 0.1)
                    : 1.0;

                return Transform.scale(
                  scale: pulseScale,
                  child: _buildActionButton(
                    icon: widget.isRecordingAudio
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    onTap: widget.isRecordingAudio
                        ? widget.onStopRecording
                        : widget.onStartRecording,
                    tooltip: widget.isRecordingAudio ? 'توقف ضبط' : 'ضبط صوت',
                    isActive: widget.isRecordingAudio,
                    color: widget.isRecordingAudio
                        ? Colors.red
                        : colorScheme.onSurface.withOpacity(0.6),
                    colorScheme: colorScheme,
                  ),
                );
              },
            );
          },
        ),
      );
    }

    // دکمه انتخاب تصویر
    buttons.add(
      _buildActionButton(
        icon: Icons.photo_camera_rounded,
        onTap: widget.pickImage,
        tooltip: 'ارسال تصویر',
        colorScheme: colorScheme,
      ),
    );

    // دکمه ایموجی
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
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 40,
          maxHeight: 120,
        ),
        child: TextField(
          controller: widget.messageController,
          focusNode: widget.messageFocusNode,
          enabled: !widget.isRecordingAudio,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          maxLines: null,
          minLines: 1,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            height: 1.4,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onSubmitted: (_) {
            if (_canSendMessage()) {
              widget.sendMessage();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSendButton(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _sendButtonAnimation,
      builder: (context, child) {
        final canSend = _canSendMessage();

        return Transform.scale(
          scale: 0.7 + (_sendButtonAnimation.value * 0.3),
          child: Container(
            margin: const EdgeInsets.all(4),
            child: Material(
              color: canSend
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              elevation: canSend ? 2 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: canSend ? widget.sendMessage : null,
                child: Container(
                  width: 40,
                  height: 40,
                  child: _buildSendButtonContent(colorScheme),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButtonContent(ColorScheme colorScheme) {
    if (widget.isUploading || widget.isSending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return const Icon(
      Icons.send_rounded,
      color: Colors.white,
      size: 20,
    );
  }

  bool _canSendMessage() {
    return (_hasText || _hasFiles) &&
        !widget.isSending &&
        !widget.isRecordingAudio;
  }
}
