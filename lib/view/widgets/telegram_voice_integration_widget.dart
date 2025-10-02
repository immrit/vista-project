import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../provider/MusicProvider.dart';
import '../../services/telegram_voice_integration_service.dart';
import '../../services/telegram_voice_service.dart';
import '../../services/telegram_voice_upload_service.dart';
import '../../services/telegram_voice_player_service.dart' as voice_service;
import 'telegram_voice_recorder_widget.dart';
import 'telegram_voice_player_widget.dart';

/// ویجت یکپارچه وویس تلگرام - ترکیب ضبط و پخش
class TelegramVoiceIntegrationWidget extends StatefulWidget {
  final String? conversationId;
  final bool enableRecording;
  final bool enablePlayback;
  final bool enableUpload;
  final Function(VoiceRecordingData)? onRecordingComplete;
  final Function(VoiceUploadResult)? onUploadComplete;
  final Function(String)? onError;
  final RecordingConfig? recordingConfig;
  final voice_service.PlaybackConfig? playbackConfig;

  const TelegramVoiceIntegrationWidget({
    super.key,
    this.conversationId,
    this.enableRecording = true,
    this.enablePlayback = true,
    this.enableUpload = true,
    this.onRecordingComplete,
    this.onUploadComplete,
    this.onError,
    this.recordingConfig,
    this.playbackConfig,
  });

  @override
  State<TelegramVoiceIntegrationWidget> createState() =>
      _TelegramVoiceIntegrationWidgetState();
}

class _TelegramVoiceIntegrationWidgetState
    extends State<TelegramVoiceIntegrationWidget> {
  // Integration service
  final TelegramVoiceIntegrationService _integrationService =
      TelegramVoiceIntegrationService();

  // State
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String _statusText = 'آماده';
  double _uploadProgress = 0.0;

  // Current voice data
  VoiceRecordingData? _currentRecording;
  VoiceUploadResult? _currentUpload;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _integrationService.initialize();
      if (widget.conversationId != null) {
        _integrationService.setCurrentConversation(widget.conversationId!);
      }

      setState(() {
        _isInitialized = true;
        _statusText = 'آماده';
      });
    } catch (e) {
      _showError('خطا در راه‌اندازی سرویس: $e');
    }
  }

  @override
  void dispose() {
    _integrationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status bar
        _buildStatusBar(),

        const SizedBox(height: 8),

        // Voice recorder
        if (widget.enableRecording)
          TelegramVoiceRecorderWidget(
            conversationId: widget.conversationId,
            enableUpload: widget.enableUpload,
            enableLock: true,
            enablePause: true,
            recordingConfig: widget.recordingConfig,
            onRecordingComplete: _onRecordingComplete,
            onRecordingCancel: _onRecordingCancel,
            onUploadProgress: _onUploadProgress,
            onUploadStatus: _onUploadStatus,
          ),

        // Voice player (if we have a recording)
        if (widget.enablePlayback && _currentUpload != null)
          _buildVoicePlayer(),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Icon(
            _isRecording
                ? Icons.mic
                : _isUploading
                    ? Icons.cloud_upload
                    : Icons.check_circle,
            color: _isRecording
                ? Colors.red
                : _isUploading
                    ? Colors.blue
                    : Colors.green,
            size: 16,
          ),

          const SizedBox(width: 8),

          // Status text
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),

          // Upload progress
          if (_isUploading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: _uploadProgress,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoicePlayer() {
    if (_currentUpload == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TelegramVoicePlayerWidget(
        audioUrl: _currentUpload!.fileUrl,
        duration: _currentUpload!.duration,
        waveformData: _currentRecording?.waveformData ?? [],
        isMe: true,
        isPreview: false,
        playbackConfig: widget.playbackConfig,
        onDelete: _onDeleteVoice,
        onReply: _onReplyVoice,
        onForward: _onForwardVoice,
      ),
    );
  }

  // Recording callbacks
  void _onRecordingComplete(VoiceRecordingData recordingData) {
    setState(() {
      _currentRecording = recordingData;
      _statusText = 'ضبط کامل شد';
    });

    widget.onRecordingComplete?.call(recordingData);

    // آپلود خودکار
    if (widget.enableUpload) {
      _uploadRecording(recordingData);
    }
  }

  void _onRecordingCancel(String reason) {
    setState(() {
      _currentRecording = null;
      _statusText = reason;
    });
  }

  // Upload callbacks
  void _onUploadProgress(double progress) {
    setState(() {
      _uploadProgress = progress;
      _statusText = 'در حال آپلود... ${(progress * 100).round()}%';
    });
  }

  void _onUploadStatus(String status) {
    setState(() {
      _statusText = status;
    });
  }

  Future<void> _uploadRecording(VoiceRecordingData recordingData) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final result = await _integrationService.uploadVoiceRecording(
        recordingData,
        onProgress: _onUploadProgress,
        onStatusChanged: _onUploadStatus,
      );

      setState(() {
        _isUploading = false;
        _currentUpload = result;
        _statusText = result.isSuccess ? 'آپلود موفق' : 'خطا در آپلود';
      });

      if (result.isSuccess) {
        widget.onUploadComplete?.call(result);
        HapticFeedback.lightImpact();
      } else {
        _showError(result.error ?? 'خطا در آپلود');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusText = 'خطا در آپلود';
      });
      _showError('خطا در آپلود: $e');
    }
  }

  // Player callbacks
  void _onDeleteVoice() {
    if (_currentUpload != null) {
      _integrationService.deleteVoice(_currentUpload!.fileUrl);
      setState(() {
        _currentUpload = null;
        _currentRecording = null;
        _statusText = 'وویس حذف شد';
      });
    }
  }

  void _onReplyVoice() {
    // پیاده‌سازی پاسخ به وویس
    HapticFeedback.lightImpact();
  }

  void _onForwardVoice() {
    // پیاده‌سازی فوروارد وویس
    HapticFeedback.lightImpact();
  }

  // Utility methods
  void _showError(String message) {
    widget.onError?.call(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Public methods
  void startRecording() {
    if (_isInitialized && !_isRecording) {
      _integrationService.startVoiceRecording(
        config: widget.recordingConfig,
        onRecordingStateChanged: (isRecording) {
          setState(() {
            _isRecording = isRecording;
          });
        },
      );
    }
  }

  void stopRecording() {
    if (_isRecording) {
      _integrationService.stopVoiceRecording();
    }
  }

  void cancelRecording() {
    if (_isRecording) {
      _integrationService.cancelVoiceRecording();
    }
  }

  Map<String, dynamic> getCurrentState() {
    return _integrationService.getCurrentState();
  }
}
