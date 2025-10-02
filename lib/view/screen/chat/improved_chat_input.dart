import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
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
      setState(() => _isRecording = true);
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
    });
  }

  void _cancelRecording() {
    _voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
      _dragOffset = 0.0;
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
      child: Row(
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
    );
  }

  Widget _buildRecordingUI(ColorScheme colorScheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final slideToCancelThreshold = screenWidth * 0.3;
    bool isCanceling = _dragOffset < -slideToCancelThreshold;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.mic, color: Colors.red.shade400, size: 28),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              color: Colors.red.shade400,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: AudioWaveforms(
              size: Size(MediaQuery.of(context).size.width, 30.0),
              recorderController: _voiceService.recorderController,
              enableSeekGesture: false,
              waveStyle: WaveStyle(
                waveColor: Colors.red.shade400,
                showDurationLabel: false,
                spacing: 8.0,
                waveThickness: 3.0,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "برای لغو بکشید",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const Icon(Icons.chevron_left, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSendButton(ColorScheme colorScheme) {
    return ScaleTransition(
      scale: _sendButtonAnimation,
      child: GestureDetector(
        onLongPress: _startRecording,
        onLongPressEnd: (details) {
          if (_dragOffset.abs() > 100) {
            _cancelRecording();
          } else {
            _stopRecording();
          }
        },
        onLongPressMoveUpdate: (details) {
          setState(() {
            _dragOffset = details.globalPosition.dx -
                (MediaQuery.of(context).size.width - 50);
          });
        },
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
    // Placeholder for emoji picker.
    // In a real app, this would be the EmojiPickerFlutter widget.
    return Container(
      height: 250,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : Colors.grey.shade100,
      child: const Center(child: Text("Emoji Picker Area")),
    );
  }
}