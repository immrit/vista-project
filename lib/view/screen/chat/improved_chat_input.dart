import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/telegram_voice_service.dart';

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
  final String type;

  const SelectedFile({
    this.file,
    this.bytes,
    this.name,
    required this.type,
  });

  bool get hasFile => file != null || bytes != null;
}

/// باکس ورودی چت بهبود یافته به سبک تلگرام
class ImprovedChatInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final VoidCallback toggleEmojiPicker;
  final VoidCallback pickImage;
  final VoidCallback sendMessage;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback pickFile;
  final VoidCallback? onReplyCancel;
  final Function(File?, Uint8List?, String?, List<double>?)? onAudioRecorded;
  final VoidCallback? onImageCancel;
  final VoidCallback? onAudioCancel;
  final bool showEmojiPicker;
  final bool isUploading;
  final bool isSending;
  final double uploadProgress;
  final ReplyData? replyData;
  final SelectedFile? selectedImage;
  final SelectedFile? selectedAudio;
  final String? conversationId;

  const ImprovedChatInput({
    super.key,
    required this.messageController,
    required this.messageFocusNode,
    required this.toggleEmojiPicker,
    required this.pickImage,
    required this.sendMessage,
    required this.onEmojiSelected,
    required this.pickFile,
    this.onReplyCancel,
    this.onAudioRecorded,
    this.onImageCancel,
    this.onAudioCancel,
    this.showEmojiPicker = false,
    this.isUploading = false,
    this.isSending = false,
    this.uploadProgress = 0.0,
    this.replyData,
    this.selectedImage,
    this.selectedAudio,
    this.conversationId,
  });

  @override
  State<ImprovedChatInput> createState() => _ImprovedChatInputState();
}

class _ImprovedChatInputState extends State<ImprovedChatInput>
    with TickerProviderStateMixin {
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;
  bool _hasText = false;

  // Voice Recording State
  final TelegramVoiceService _voiceService = TelegramVoiceService();
  bool _isRecording = false;
  int _recordingDuration = 0;
  double _dragOffset = 0.0;
  Offset? _startPosition;

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();

    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _sendButtonAnimation =
        Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.easeInOut,
    ));

    widget.messageController.addListener(_onTextChanged);
    _onTextChanged(); // Initial check
  }

  Future<void> _initializeVoiceService() async {
    await _voiceService.initialize();
    _voiceService.setCallbacks(
      onRecordingStateChanged: (isRecording) {
        if (mounted) setState(() => _isRecording = isRecording);
      },
      onDurationChanged: (duration) {
        if (mounted) setState(() => _recordingDuration = duration);
      },
    );
  }

  @override
  void dispose() {
    _sendButtonController.dispose();
    widget.messageController.removeListener(_onTextChanged);
    _voiceService.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = widget.messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
      if (_hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startRecording() async {
    final success = await _voiceService.startRecording();
    if (success) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isRecording = true;
        _dragOffset = 0.0;
        _startPosition = null;
      });
    } else {
      // Show permission denied message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'دسترسی به میکروفون لازم است. لطفاً از تنظیمات برنامه مجوز را فعال کنید.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _stopRecording() async {
    final recordingData = await _voiceService.stopRecording();
    if (recordingData != null) {
      widget.onAudioRecorded?.call(
        File(recordingData.filePath),
        null, // No bytes needed as we have a file
        recordingData.filePath.split('/').last,
        recordingData.waveformData,
      );
    }
    setState(() {
      _isRecording = false;
      _dragOffset = 0.0;
      _startPosition = null;
    });
  }

  void _cancelRecording() {
    _voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
      _dragOffset = 0.0;
      _startPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      elevation: 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            _buildRecordingUI(colorScheme)
          else
            _buildStandardInput(colorScheme),
          if (widget.showEmojiPicker && !_isRecording) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildStandardInput(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show selected audio preview if exists
          if (widget.selectedAudio?.hasFile == true)
            _buildAudioPreview(colorScheme),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  widget.showEmojiPicker
                      ? Icons.keyboard_rounded
                      : Icons.emoji_emotions_outlined,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                onPressed: widget.toggleEmojiPicker,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.messageController,
                          focusNode: widget.messageFocusNode,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: 'پیام',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.attach_file_rounded,
                            color: colorScheme.onSurface.withOpacity(0.7)),
                        onPressed: widget.pickImage,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSendButton(colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'پیام صوتی آماده ارسال',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onAudioCancel,
            icon: Icon(
              Icons.close,
              color: colorScheme.primary.withOpacity(0.7),
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI(ColorScheme colorScheme) {
    final isCanceling = _dragOffset.abs() > 80;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Stop button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    color: isCanceling ? Colors.red : Colors.red.shade400,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCanceling ? "رها کنید تا لغو شود" : "برای لغو بکشید",
                  style: TextStyle(
                      color: isCanceling ? Colors.red : Colors.grey.shade600,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: AudioWaveforms(
              size: Size(MediaQuery.of(context).size.width, 30.0),
              recorderController: _voiceService.recorderController,
              waveStyle: WaveStyle(
                waveColor: isCanceling ? Colors.red : Colors.red.shade400,
                showDurationLabel: false,
                spacing: 8.0,
                waveThickness: 3.0,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(isCanceling ? Icons.close : Icons.chevron_left,
              color: isCanceling ? Colors.red : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSendButton(ColorScheme colorScheme) {
    return ScaleTransition(
      scale: _sendButtonAnimation,
      child: GestureDetector(
        onLongPressStart: _isRecording
            ? null
            : (details) {
                _startPosition = details.globalPosition;
                _startRecording();
              },
        onLongPressEnd: _isRecording
            ? (details) {
                if (_dragOffset.abs() > 80) {
                  _cancelRecording();
                } else {
                  _stopRecording();
                }
                // Reset drag state
                setState(() {
                  _dragOffset = 0.0;
                  _startPosition = null;
                });
              }
            : null,
        onLongPressMoveUpdate: _isRecording
            ? (details) {
                if (_startPosition != null) {
                  setState(() {
                    _dragOffset =
                        details.globalPosition.dx - _startPosition!.dx;
                  });
                }
              }
            : null,
        onTap: _isRecording ? _stopRecording : null,
        child: FloatingActionButton(
          onPressed: _hasText ? widget.sendMessage : null,
          backgroundColor: colorScheme.primary,
          elevation: 2,
          child: _isRecording
              ? const Icon(Icons.stop, color: Colors.white)
              : Icon(
                  _hasText ? Icons.send : Icons.mic,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          widget.onEmojiSelected(emoji.emoji);
        },
        config: Config(
          height: 256,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 7,
            emojiSizeMax: 32,
            verticalSpacing: 0,
            horizontalSpacing: 0,
            gridPadding: EdgeInsets.zero,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            loadingIndicator: const SizedBox.shrink(),
            recentsLimit: 28,
            noRecents: const Text(
              'No Recents',
              style: TextStyle(fontSize: 20, color: Colors.black26),
              textAlign: TextAlign.center,
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            tabIndicatorAnimDuration: kTabScrollDuration,
            categoryIcons: const CategoryIcons(),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            indicatorColor: Theme.of(context).colorScheme.primary,
            iconColor: Colors.grey,
            iconColorSelected: Theme.of(context).colorScheme.primary,
            backspaceColor: Theme.of(context).colorScheme.primary,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            buttonColor: Theme.of(context).colorScheme.primary,
            buttonIconColor: Colors.white,
          ),
          skinToneConfig: SkinToneConfig(
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
