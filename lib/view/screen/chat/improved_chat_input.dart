import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import '../../../services/telegram_voice_integration_service.dart';
import '../../../services/telegram_voice_service.dart' as voice_service;

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
  final VoidCallback pickFile; // دکمه ضمیمه فایل پیشرفته
  final Function(String?)? onVideoSelected; // callback برای انتخاب ویدیو
  final Function(String?)? onDocumentSelected; // callback برای انتخاب فایل
  final VoidCallback? onReplyCancel;
  final Function(File?, Uint8List?, String?)? onAudioRecorded;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onImageCancel;
  final VoidCallback? onAudioCancel;
  final bool showEmojiPicker;
  final bool isUploading;
  final bool isSending;
  final bool isRecordingAudio;
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
    this.onVideoSelected,
    this.onDocumentSelected,
    this.onReplyCancel,
    this.onAudioRecorded,
    this.onStartRecording,
    this.onStopRecording,
    this.onImageCancel,
    this.onAudioCancel,
    this.showEmojiPicker = false,
    this.isUploading = false,
    this.isSending = false,
    this.isRecordingAudio = false,
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
  late AnimationController _expandController;
  late AnimationController _sendButtonController;
  late AnimationController _pulseController;

  late Animation<double> _sendButtonAnimation;
  late Animation<double> _pulseAnimation;

  bool _isExpanded = false;
  final bool _isLongPressing = false;
  bool _showAttachmentMenu = false; // برای نمایش منوی ضمیمه فایل پیشرفته
  int _selectedEmojiCategory = 0; // دسته‌بندی انتخاب شده ایموجی‌ها
  String _emojiSearchQuery = ''; // جستجوی ایموجی
  List<String> _recentEmojis = []; // ایموجی‌های اخیر

  // Voice Recording State (Telegram Style)
  bool _isVoiceRecording = false;
  bool _isVoiceLocked = false;
  bool _isVoiceCanceling = false;
  int _voiceRecordingDuration = 0;
  Offset _dragOffset = Offset.zero;
  double _dragDistance = 0.0;

  // Telegram Voice Integration Service
  final TelegramVoiceIntegrationService _voiceIntegrationService =
      TelegramVoiceIntegrationService();

  // برای تشخیص اندازه صفحه
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sendButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    widget.messageController.addListener(_onTextChanged);

    // مقداردهی اولیه سرویس وویس یکپارچه
    _initializeVoiceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  void dispose() {
    _expandController.dispose();
    _sendButtonController.dispose();
    _pulseController.dispose();
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _isExpanded) {
      setState(() {
        _isExpanded = hasText;
      });

      if (hasText) {
        _expandController.forward();
        _sendButtonController.forward();
      } else {
        _expandController.reverse();
        _sendButtonController.reverse();
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply Preview
          if (widget.replyData != null && !_isVoiceRecording)
            _buildReplyPreview(isDark, colorScheme),

          // File Preview
          if ((widget.selectedImage != null || widget.selectedAudio != null) &&
              !_isVoiceRecording)
            _buildFilePreview(isDark, colorScheme),

          // Attachment Menu
          if (_showAttachmentMenu && !_isVoiceRecording)
            _buildAttachmentMenu(isDark, colorScheme),

          // Main Input Area - همیشه نمایش داده می‌شود
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _screenWidth * 0.04, // 4% of screen width
              vertical: 8,
            ),
            child: _isVoiceRecording
                ? _buildTelegramVoiceRecorder(colorScheme)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Attachment Button (اول)
                      _buildAttachmentButton(colorScheme),
                      SizedBox(width: _screenWidth * 0.02),

                      // Emoji Button (دوم)
                      _buildEmojiButton(colorScheme),
                      SizedBox(width: _screenWidth * 0.03), // 3% spacing

                      // Text Input
                      Expanded(
                        child: _buildTextInput(isDark, colorScheme),
                      ),

                      SizedBox(width: _screenWidth * 0.03), // 3% spacing

                      // Send/Record Button
                      _buildSendButton(isDark, colorScheme),
                    ],
                  ),
          ),

          // Emoji Picker - در پایین باکس ورودی (مثل تلگرام)
          if (widget.showEmojiPicker && !_isVoiceRecording) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _screenWidth * 0.04, // 4% of screen width
        8,
        _screenWidth * 0.04,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.8)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(
            color: colorScheme.primary,
            width: 3,
          ),
        ),
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
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyData!.message,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.onReplyCancel != null)
            GestureDetector(
              onTap: widget.onReplyCancel,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePreview(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _screenWidth * 0.04,
        8,
        _screenWidth * 0.04,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.8)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.selectedImage != null ? Icons.image : Icons.audiotrack,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedImage != null ? 'تصویر' : 'صوت',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (widget.isUploading)
                  LinearProgressIndicator(
                    value: widget.uploadProgress,
                    backgroundColor:
                        colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
              ],
            ),
          ),
          if (widget.onImageCancel != null || widget.onAudioCancel != null)
            GestureDetector(
              onTap: widget.selectedImage != null
                  ? widget.onImageCancel
                  : widget.onAudioCancel,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTelegramVoiceRecorder(ColorScheme colorScheme) {
    // اگر در حال لغو هستیم، نشان ساده لغو
    if (_isVoiceCanceling) {
      return Container(
        margin: EdgeInsets.symmetric(
          horizontal: _screenWidth * 0.04,
          vertical: 8,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'لغو شد',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _screenWidth * 0.04,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isVoiceLocked ? Colors.blue.shade600 : Colors.red.shade500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // آیکون ضبط با انیمیشن
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _isVoiceLocked ? Icons.lock_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          // اطلاعات ضبط
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(_voiceRecordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isVoiceLocked
                      ? 'قفل شده - برای ارسال نگه دارید'
                      : 'در حال ضبط...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // دکمه اکشن
          GestureDetector(
            onTap: _isVoiceLocked ? _stopVoiceRecording : null,
            onPanStart: !_isVoiceLocked
                ? (details) {
                    _dragOffset = details.localPosition;
                  }
                : null,
            onPanUpdate: !_isVoiceLocked
                ? (details) {
                    final currentOffset = details.localPosition;
                    final deltaX = currentOffset.dx - _dragOffset.dx;
                    final deltaY = _dragOffset.dy - currentOffset.dy;
                    setState(() {
                      _dragDistance =
                          deltaX.abs() > deltaY.abs() ? deltaX : deltaY;
                    });
                  }
                : null,
            onPanEnd: !_isVoiceLocked
                ? (details) {
                    if (_dragDistance < -100) {
                      _cancelVoiceRecording();
                    } else if (_dragDistance > 100) {
                      _voiceIntegrationService.lockVoiceRecording();
                    } else {
                      _stopVoiceRecording();
                    }
                    setState(() {
                      _dragDistance = 0.0;
                      _dragOffset = Offset.zero;
                    });
                  }
                : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isVoiceLocked ? Icons.send_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Voice Recording Methods (Telegram Style)
  Future<void> _initializeVoiceService() async {
    await _voiceIntegrationService.initialize();

    // تنظیم conversationId اگر موجود باشد
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      _voiceIntegrationService.setCurrentConversation(widget.conversationId!);
    }

    // تنظیم callbacks برای سرویس وویس جدید
    _voiceIntegrationService.startVoiceRecording(
      onRecordingStateChanged: (isRecording) {
        if (mounted) {
          setState(() {
            _isVoiceRecording = isRecording;
            if (isRecording) {
              _pulseController.repeat(reverse: true);
            } else {
              _pulseController.stop();
            }
          });
        }
      },
      onDurationChanged: (duration) {
        if (mounted) {
          setState(() {
            _voiceRecordingDuration = duration;
          });
        }
      },
      onWaveformDataChanged: (data) {
        // waveform توسط سرویس مدیریت می‌شود
      },
      onLockedStateChanged: (isLocked) {
        if (mounted) {
          setState(() {
            _isVoiceLocked = isLocked;
          });
        }
      },
      onCancelingStateChanged: (isCanceling) {
        if (mounted) {
          setState(() {
            _isVoiceCanceling = isCanceling;
          });
        }
      },
      onPausedStateChanged: (isPaused) {
        // وضعیت pause توسط سرویس مدیریت می‌شود
      },
      onAmplitudeChanged: (amplitude) {
        // برای نمایش قدرت صدا
      },
    );
  }

  void _startVoiceRecording() async {
    print('🎙️ شروع ضبط وویس - conversationId: ${widget.conversationId}');
    try {
      final success = await _voiceIntegrationService.startVoiceRecording();
      print('🎙️ نتیجه شروع ضبط: $success');
      if (success) {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('❌ خطا در شروع ضبط: $e');
    }
  }

  void _stopVoiceRecording() async {
    final recordedFile = await _voiceIntegrationService.stopVoiceRecording();

    if (recordedFile != null) {
      await _uploadVoiceFileTelegram(recordedFile);
      HapticFeedback.lightImpact();
    }
  }

  void _cancelVoiceRecording() async {
    await _voiceIntegrationService.cancelVoiceRecording();
    HapticFeedback.mediumImpact();
  }

  Future<void> _uploadVoiceFileTelegram(
      voice_service.VoiceRecordingData recordingData) async {
    try {
      // آپلود با سرویس جدید تلگرام
      final uploadResult = await _voiceIntegrationService.uploadVoiceRecording(
        recordingData,
        onProgress: (progress) {
          print('پیشرفت آپلود: ${(progress * 100).round()}%');
        },
        onStatusChanged: (status) {
          print('وضعیت آپلود: $status');
        },
      );

      if (uploadResult.isSuccess) {
        // ارسال پیام صوتی
        widget.onAudioRecorded?.call(
          File(recordingData.filePath),
          null,
          recordingData.filePath.split('/').last,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('خطا در ارسال پیام صوتی: ${uploadResult.error}')),
          );
        }
      }
    } catch (e) {
      print('خطا در آپلود فایل صوتی: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پیام صوتی: $e')),
        );
      }
    }
  }

  Widget _buildEmojiButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        widget.toggleEmojiPicker();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.showEmojiPicker
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: widget.showEmojiPicker
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Icon(
          widget.showEmojiPicker
              ? Icons.keyboard_outlined
              : Icons.emoji_emotions_outlined,
          color: widget.showEmojiPicker
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.7),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 320,
      margin: EdgeInsets.fromLTRB(
        _screenWidth * 0.04,
        0,
        _screenWidth * 0.04,
        8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Search
          _buildEmojiHeader(),

          // Category Tabs
          _buildEmojiCategoryTabs(),

          // Emoji Grid
          Expanded(
            child: _buildEmojiGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Title and Close Button
          Row(
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ایموجی‌ها',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  widget.toggleEmojiPicker();
                },
                child: Icon(
                  Icons.keyboard_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Search Bar
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _emojiSearchQuery = value;
                });
              },
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'جستجوی ایموجی...',
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiCategoryTabs() {
    final categories = [
      {'emoji': '🕒', 'label': 'اخیر', 'key': 'recent'},
      {'emoji': '😊', 'label': 'خوشحالی', 'key': 'happy'},
      {'emoji': '❤️', 'label': 'عشق', 'key': 'love'},
      {'emoji': '😂', 'label': 'خنده', 'key': 'laugh'},
      {'emoji': '😢', 'label': 'ناراحتی', 'key': 'sad'},
      {'emoji': '😮', 'label': 'تعجب', 'key': 'surprise'},
      {'emoji': '👍', 'label': 'حمایت', 'key': 'support'},
      {'emoji': '🎉', 'label': 'جشن', 'key': 'celebration'},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedEmojiCategory == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedEmojiCategory = index;
                _emojiSearchQuery = ''; // Clear search when changing category
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category['emoji']!,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category['label']!,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final emojis = _getEmojisForCategory(_selectedEmojiCategory);

    if (emojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'ایموجی‌ای یافت نشد',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () {
            widget.onEmojiSelected(emoji);
            widget.messageController.text += emoji;
            _addToRecentEmojis(emoji);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _getEmojisForCategory(int category) {
    if (_emojiSearchQuery.isNotEmpty) {
      return _searchEmojis(_emojiSearchQuery);
    }

    switch (category) {
      case 0: // اخیر
        return _recentEmojis;
      case 1: // خوشحالی
        return [
          '😀',
          '😃',
          '😄',
          '😁',
          '😆',
          '😅',
          '😂',
          '🤣',
          '😊',
          '😇',
          '🙂',
          '🙃',
          '😉',
          '😌',
          '😍',
          '🥰',
          '😘',
          '😗',
          '😙',
          '😚',
          '😋',
          '😛',
          '😝',
          '😜',
          '🤪',
          '😎',
          '🤓',
          '🧐',
          '🥳',
          '🤠',
        ];
      case 2: // عشق
        return [
          '❤️',
          '🧡',
          '💛',
          '💚',
          '💙',
          '💜',
          '🤎',
          '🖤',
          '🤍',
          '💕',
          '💞',
          '💓',
          '💗',
          '💖',
          '💘',
          '💝',
          '💟',
          '❣️',
          '💔',
          '❤️‍🔥',
          '💋',
          '💌',
          '😘',
          '😍',
          '🥰',
          '😻',
          '💑',
          '👫',
          '👬',
          '👭',
        ];
      case 3: // خنده
        return [
          '😂',
          '🤣',
          '😆',
          '😅',
          '😄',
          '😃',
          '😀',
          '😁',
          '😊',
          '🙂',
          '😉',
          '😌',
          '😍',
          '🥰',
          '😘',
          '😗',
          '😙',
          '😚',
          '😋',
          '😛',
          '😝',
          '😜',
          '🤪',
          '🤠',
          '🥳',
          '😎',
          '🤓',
          '🧐',
          '😺',
          '😸',
        ];
      case 4: // ناراحتی
        return [
          '😢',
          '😭',
          '😔',
          '😪',
          '😴',
          '😷',
          '🤒',
          '🤕',
          '🤢',
          '🤮',
          '🤧',
          '🥵',
          '🥶',
          '🥴',
          '😵',
          '🤯',
          '😕',
          '😟',
          '🙁',
          '☹️',
          '😞',
          '😓',
          '😩',
          '😫',
          '🥱',
          '😤',
          '😡',
          '😠',
          '🤬',
          '😈',
        ];
      case 5: // تعجب
        return [
          '😮',
          '😯',
          '😲',
          '😳',
          '🥺',
          '😦',
          '😧',
          '😨',
          '😰',
          '😥',
          '😓',
          '😩',
          '😫',
          '🥱',
          '😤',
          '😡',
          '😠',
          '🤬',
          '😈',
          '👿',
          '💀',
          '☠️',
          '💩',
          '🤡',
          '👹',
          '👺',
          '👻',
          '👽',
          '👾',
          '🤖',
        ];
      case 6: // حمایت
        return [
          '👍',
          '👎',
          '👊',
          '✊',
          '🤛',
          '🤜',
          '👏',
          '🙌',
          '👐',
          '🤲',
          '🤝',
          '🙏',
          '✍️',
          '💅',
          '🤳',
          '💪',
          '🦾',
          '🦿',
          '🦵',
          '🦶',
          '👋',
          '🤚',
          '🖐️',
          '✋',
          '🖖',
          '👌',
          '🤌',
          '🤏',
          '✌️',
          '🤞',
        ];
      case 7: // جشن
        return [
          '🎉',
          '🎊',
          '🎈',
          '🎂',
          '🎁',
          '🎀',
          '🎇',
          '🎆',
          '✨',
          '🌟',
          '💫',
          '⭐',
          '🌠',
          '🎪',
          '🎭',
          '🎨',
          '🎵',
          '🎶',
          '🎤',
          '🎧',
          '🎸',
          '🥁',
          '🎺',
          '🎷',
          '🎹',
          '🎻',
          '🎲',
          '🎯',
          '🎳',
          '🎮',
        ];
      default:
        return _recentEmojis;
    }
  }

  List<String> _searchEmojis(String query) {
    final allEmojis = <String, List<String>>{
      'خوشحال': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '😎',
        '🤓',
        '🧐',
        '🥳',
        '🤠'
      ],
      'عشق': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🤎',
        '🖤',
        '🤍',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '❣️',
        '💔',
        '❤️‍🔥',
        '💋',
        '💌',
        '😘',
        '😍',
        '🥰',
        '😻',
        '💑',
        '👫',
        '👬',
        '👭'
      ],
      'خنده': [
        '😂',
        '🤣',
        '😆',
        '😅',
        '😄',
        '😃',
        '😀',
        '😁',
        '😊',
        '🙂',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '🤠',
        '🥳',
        '😎',
        '🤓',
        '🧐',
        '😺',
        '😸'
      ],
      'ناراحت': [
        '😢',
        '😭',
        '😔',
        '😪',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🤢',
        '🤮',
        '🤧',
        '🥵',
        '🥶',
        '🥴',
        '😵',
        '🤯',
        '😕',
        '😟',
        '🙁',
        '☹️',
        '😞',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈'
      ],
      'تعجب': [
        '😮',
        '😯',
        '😲',
        '😳',
        '🥺',
        '😦',
        '😧',
        '😨',
        '😰',
        '😥',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈',
        '👿',
        '💀',
        '☠️',
        '💩',
        '🤡',
        '👹',
        '👺',
        '👻',
        '👽',
        '👾',
        '🤖'
      ],
      'حمایت': [
        '👍',
        '👎',
        '👊',
        '✊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💅',
        '🤳',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞'
      ],
      'جشن': [
        '🎉',
        '🎊',
        '🎈',
        '🎂',
        '🎁',
        '🎀',
        '🎇',
        '🎆',
        '✨',
        '🌟',
        '💫',
        '⭐',
        '🌠',
        '🎪',
        '🎭',
        '🎨',
        '🎵',
        '🎶',
        '🎤',
        '🎧',
        '🎸',
        '🥁',
        '🎺',
        '🎷',
        '🎹',
        '🎻',
        '🎲',
        '🎯',
        '🎳',
        '🎮'
      ],
      'happy': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '😎',
        '🤓',
        '🧐',
        '🥳',
        '🤠'
      ],
      'love': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🤎',
        '🖤',
        '🤍',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '❣️',
        '💔',
        '❤️‍🔥',
        '💋',
        '💌',
        '😘',
        '😍',
        '🥰',
        '😻',
        '💑',
        '👫',
        '👬',
        '👭'
      ],
      'laugh': [
        '😂',
        '🤣',
        '😆',
        '😅',
        '😄',
        '😃',
        '😀',
        '😁',
        '😊',
        '🙂',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '🤠',
        '🥳',
        '😎',
        '🤓',
        '🧐',
        '😺',
        '😸'
      ],
      'sad': [
        '😢',
        '😭',
        '😔',
        '😪',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🤢',
        '🤮',
        '🤧',
        '🥵',
        '🥶',
        '🥴',
        '😵',
        '🤯',
        '😕',
        '😟',
        '🙁',
        '☹️',
        '😞',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈'
      ],
      'surprise': [
        '😮',
        '😯',
        '😲',
        '😳',
        '🥺',
        '😦',
        '😧',
        '😨',
        '😰',
        '😥',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈',
        '👿',
        '💀',
        '☠️',
        '💩',
        '🤡',
        '👹',
        '👺',
        '👻',
        '👽',
        '👾',
        '🤖'
      ],
      'support': [
        '👍',
        '👎',
        '👊',
        '✊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💅',
        '🤳',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞'
      ],
      'celebration': [
        '🎉',
        '🎊',
        '🎈',
        '🎂',
        '🎁',
        '🎀',
        '🎇',
        '🎆',
        '✨',
        '🌟',
        '💫',
        '⭐',
        '🌠',
        '🎪',
        '🎭',
        '🎨',
        '🎵',
        '🎶',
        '🎤',
        '🎧',
        '🎸',
        '🥁',
        '🎺',
        '🎷',
        '🎹',
        '🎻',
        '🎲',
        '🎯',
        '🎳',
        '🎮'
      ],
    };

    final results = <String>[];
    final queryLower = query.toLowerCase();

    for (final entry in allEmojis.entries) {
      if (entry.key.contains(queryLower)) {
        results.addAll(entry.value);
      }
    }

    // Remove duplicates and return
    return results.toSet().toList();
  }

  void _addToRecentEmojis(String emoji) {
    _recentEmojis.remove(emoji); // Remove if already exists
    _recentEmojis.insert(0, emoji); // Add to beginning

    // Keep only last 20 emojis
    if (_recentEmojis.length > 20) {
      _recentEmojis = _recentEmojis.take(20).toList();
    }
  }

  Widget _buildAttachmentMenu(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _screenWidth * 0.04,
        0,
        _screenWidth * 0.04,
        8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'اشتراک‌گذاری',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attachment Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAttachmentOption(
                icon: Icons.image_outlined,
                label: 'عکس',
                color: Colors.blue,
                onTap: () {
                  setState(() => _showAttachmentMenu = false);
                  widget.pickImage();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.videocam_outlined,
                label: 'ویدیو',
                color: Colors.purple,
                onTap: () {
                  setState(() => _showAttachmentMenu = false);
                  widget.onVideoSelected?.call(null);
                },
              ),
              _buildAttachmentOption(
                icon: Icons.insert_drive_file_outlined,
                label: 'فایل',
                color: Colors.orange,
                onTap: () {
                  setState(() => _showAttachmentMenu = false);
                  widget.onDocumentSelected?.call(null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAttachmentMenu = !_showAttachmentMenu;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _showAttachmentMenu
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.attach_file_rounded,
          color: _showAttachmentMenu
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.7),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTextInput(bool isDark, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(
        minHeight: 40,
        maxHeight: _screenHeight * 0.3, // حداکثر 30% ارتفاع صفحه
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isExpanded ? colorScheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: TextField(
          controller: widget.messageController,
          focusNode: widget.messageFocusNode,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          textAlign: TextAlign.right, // راست‌چین کردن متن
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            height: 1.2, // کاهش ارتفاع خط برای جلوگیری از فضای اضافی
          ),
          decoration: InputDecoration(
            hintText: 'پیام...',
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 16,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            // برای وسط قرار دادن hintText
            alignLabelWithHint: true,
            isDense: true, // کاهش فاصله اضافی
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(bool isDark, ColorScheme colorScheme) {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    final hasFile =
        widget.selectedImage != null || widget.selectedAudio != null;

    // رنگ‌های شخصی‌سازی شده برای تم تاریک
    Color getSendButtonColor() {
      if (hasText || hasFile) {
        return isDark ? const Color(0xFF0088CC) : colorScheme.primary;
      }
      return isDark
          ? const Color(0xFF3A3A3A)
          : colorScheme.onSurface.withValues(alpha: 0.1);
    }

    Color getIconColor() {
      if (hasText || hasFile) {
        return Colors.white;
      }
      return isDark
          ? const Color(0xFF8A8A8A)
          : colorScheme.onSurface.withValues(alpha: 0.7);
    }

    return GestureDetector(
      onTapDown: hasText || hasFile
          ? null
          : (_) {
              if (!_isVoiceRecording) {
                _startVoiceRecording();
              }
            },
      onTapUp: hasText || hasFile
          ? null
          : (_) {
              if (_isVoiceRecording && !_isVoiceLocked) {
                _stopVoiceRecording();
              }
            },
      onTapCancel: hasText || hasFile
          ? null
          : () {
              if (_isVoiceRecording && !_isVoiceLocked) {
                _cancelVoiceRecording();
              }
            },
      onPanStart: hasText || hasFile
          ? null
          : (details) {
              if (!_isVoiceRecording) {
                _startVoiceRecording();
                _dragOffset = details.localPosition;
              }
            },
      onPanUpdate: hasText || hasFile
          ? null
          : (details) {
              if (_isVoiceRecording && !_isVoiceLocked) {
                final currentOffset = details.localPosition;
                final deltaX = currentOffset.dx - _dragOffset.dx;
                final deltaY = _dragOffset.dy - currentOffset.dy;
                setState(() {
                  _dragDistance = deltaX.abs() > deltaY.abs() ? deltaX : deltaY;
                });
              }
            },
      onPanEnd: hasText || hasFile
          ? null
          : (details) {
              if (_isVoiceRecording && !_isVoiceLocked) {
                if (_dragDistance < -100) {
                  _cancelVoiceRecording();
                } else if (_dragDistance > 100) {
                  _voiceIntegrationService.lockVoiceRecording();
                } else {
                  _stopVoiceRecording();
                }
                setState(() {
                  _dragDistance = 0.0;
                  _dragOffset = Offset.zero;
                });
              }
            },
      onTap: hasText || hasFile ? widget.sendMessage : null,
      child: AnimatedBuilder(
        animation: _sendButtonAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * _sendButtonAnimation.value),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: getSendButtonColor(),
                borderRadius: BorderRadius.circular(20),
                border: _isLongPressing
                    ? Border.all(
                        color: isDark
                            ? const Color(0xFF0088CC)
                            : colorScheme.primary,
                        width: 2,
                      )
                    : null,
                boxShadow: (hasText || hasFile)
                    ? [
                        BoxShadow(
                          color: (isDark
                                  ? const Color(0xFF0088CC)
                                  : colorScheme.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Main Icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      (hasText || hasFile)
                          ? Icons.send_rounded
                          : Icons.mic_rounded,
                      key: ValueKey((hasText || hasFile) ? 'send' : 'mic'),
                      color: getIconColor(),
                      size: 20,
                    ),
                  ),

                  // Loading Indicator
                  if (widget.isSending)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
