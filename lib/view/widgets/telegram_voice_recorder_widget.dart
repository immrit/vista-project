import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/telegram_voice_service.dart';
import '../../services/telegram_voice_upload_service.dart';

/// ویجت ضبط وویس پیشرفته مثل تلگرام
class TelegramVoiceRecorderWidget extends StatefulWidget {
  final Function(VoiceRecordingData)? onRecordingComplete;
  final Function(String)? onRecordingCancel;
  final Function(double)? onUploadProgress;
  final Function(String)? onUploadStatus;
  final String? conversationId;
  final bool enableUpload;
  final bool enableLock;
  final bool enablePause;
  final RecordingConfig? recordingConfig;

  const TelegramVoiceRecorderWidget({
    super.key,
    this.onRecordingComplete,
    this.onRecordingCancel,
    this.onUploadProgress,
    this.onUploadStatus,
    this.conversationId,
    this.enableUpload = true,
    this.enableLock = true,
    this.enablePause = true,
    this.recordingConfig,
  });

  @override
  State<TelegramVoiceRecorderWidget> createState() =>
      _TelegramVoiceRecorderWidgetState();
}

class _TelegramVoiceRecorderWidgetState
    extends State<TelegramVoiceRecorderWidget> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _lockController;
  late AnimationController _cancelController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _lockAnimation;
  late Animation<double> _cancelAnimation;

  // Voice service
  final TelegramVoiceService _voiceService = TelegramVoiceService();
  final TelegramVoiceUploadService _uploadService =
      TelegramVoiceUploadService();

  // Recording state
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isCanceling = false;
  bool _isPaused = false;
  int _recordingDuration = 0;
  List<double> _waveformData = [];

  // Gesture tracking
  Offset _dragOffset = Offset.zero;
  double _dragDistance = 0.0;

  // UI state
  String _statusText = 'برای ضبط نگه دارید';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVoiceService();
  }

  void _initializeAnimations() {
    // Pulse animation for recording button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Waveform animation
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _waveformAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    ));

    // Lock animation
    _lockController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _lockAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lockController,
      curve: Curves.elasticOut,
    ));

    // Cancel animation
    _cancelController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _cancelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cancelController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeVoiceService() {
    _voiceService.setCallbacks(
      onRecordingStateChanged: (isRecording) {
        if (mounted) {
          setState(() {
            _isRecording = isRecording;
            if (isRecording) {
              _pulseController.repeat(reverse: true);
              _waveformController.forward();
              _statusText = 'در حال ضبط...';
              _statusColor = Colors.red;
            } else {
              _pulseController.stop();
              _waveformController.reverse();
              _statusText = 'برای ضبط نگه دارید';
              _statusColor = Colors.grey;
            }
          });
        }
      },
      onDurationChanged: (duration) {
        if (mounted) {
          setState(() {
            _recordingDuration = duration;
            _statusText = 'در حال ضبط... ${_formatDuration(duration)}';
          });
        }
      },
      onWaveformDataChanged: (data) {
        if (mounted) {
          setState(() {
            _waveformData = data;
          });
        }
      },
      onLockedStateChanged: (isLocked) {
        if (mounted) {
          setState(() {
            _isLocked = isLocked;
            if (isLocked) {
              _lockController.forward();
              _statusText = 'ضبط قفل شد';
              _statusColor = Colors.orange;
            } else {
              _lockController.reverse();
              _statusText = 'در حال ضبط...';
              _statusColor = Colors.red;
            }
          });
        }
      },
      onCancelingStateChanged: (isCanceling) {
        if (mounted) {
          setState(() {
            _isCanceling = isCanceling;
            if (isCanceling) {
              _cancelController.forward();
              _statusText = 'در حال لغو...';
              _statusColor = Colors.red;
            }
          });
        }
      },
      onPausedStateChanged: (isPaused) {
        if (mounted) {
          setState(() {
            _isPaused = isPaused;
            if (isPaused) {
              _statusText = 'ضبط مکث شد';
              _statusColor = Colors.orange;
            } else {
              _statusText = 'در حال ضبط...';
              _statusColor = Colors.red;
            }
          });
        }
      },
      onAmplitudeChanged: (amplitude) {
        // amplitude تغییرات در waveform نمایش داده می‌شود
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveformController.dispose();
    _lockController.dispose();
    _cancelController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Recording button
          _buildRecordingButton(isDark, colorScheme),

          const SizedBox(width: 16),

          // Waveform and controls
          Expanded(
            child: _buildWaveformAndControls(isDark, colorScheme),
          ),

          const SizedBox(width: 16),

          // Action buttons
          _buildActionButtons(isDark, colorScheme),
        ],
      ),
    );
  }

  Widget _buildRecordingButton(bool isDark, ColorScheme colorScheme) {
    return GestureDetector(
      onTapDown: _isRecording ? null : (_) => _startRecording(),
      onTapUp: _isRecording && !_isLocked ? (_) => _stopRecording() : null,
      onTapCancel: _isRecording && !_isLocked ? () => _cancelRecording() : null,
      onPanStart: _isRecording
          ? null
          : (details) {
              _startRecording();
              _dragOffset = details.localPosition;
            },
      onPanUpdate: _isRecording
          ? (details) {
              if (!_isLocked) {
                final currentOffset = details.localPosition;
                final deltaX = currentOffset.dx - _dragOffset.dx;
                final deltaY = _dragOffset.dy - currentOffset.dy;
                setState(() {
                  _dragDistance = deltaX.abs() > deltaY.abs() ? deltaX : deltaY;
                });
              }
            }
          : null,
      onPanEnd: _isRecording
          ? (details) {
              if (!_isLocked) {
                if (_dragDistance < -100) {
                  _cancelRecording();
                } else if (_dragDistance > 100 && widget.enableLock) {
                  _lockRecording();
                } else {
                  _stopRecording();
                }
              }
              setState(() {
                _dragDistance = 0.0;
                _dragOffset = Offset.zero;
              });
            }
          : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _isRecording
                    ? (_isLocked ? Colors.orange : Colors.red)
                    : colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? (_isLocked ? Colors.orange : Colors.red)
                            : colorScheme.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isRecording
                    ? (_isPaused ? Icons.play_arrow : Icons.stop)
                    : Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveformAndControls(bool isDark, ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status text
        Text(
          _statusText,
          style: TextStyle(
            color: _statusColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        // Waveform
        if (_isRecording) _buildWaveform(isDark, colorScheme),

        // Duration
        if (_isRecording)
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }

  Widget _buildWaveform(bool isDark, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _waveformAnimation.value,
          child: Container(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(20, (index) {
                final height = _waveformData.isNotEmpty
                    ? (_waveformData.length > index
                        ? _waveformData[index] / 100 * 20
                        : 4.0)
                    : 4.0;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 2,
                  height: height.clamp(4.0, 20.0),
                  decoration: BoxDecoration(
                    color: _isLocked ? Colors.orange : Colors.red,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(bool isDark, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause/Resume button
        if (widget.enablePause && _isRecording && !_isLocked)
          IconButton(
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: _isPaused ? Colors.green : Colors.orange,
            ),
          ),

        // Lock/Unlock button
        if (widget.enableLock && _isRecording)
          AnimatedBuilder(
            animation: _lockAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isLocked ? _lockAnimation.value : 1.0,
                child: IconButton(
                  onPressed: _isLocked ? _unlockRecording : _lockRecording,
                  icon: Icon(
                    _isLocked ? Icons.lock_open : Icons.lock,
                    color: _isLocked ? Colors.orange : Colors.grey,
                  ),
                ),
              );
            },
          ),

        // Cancel button
        if (_isRecording)
          AnimatedBuilder(
            animation: _cancelAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isCanceling ? _cancelAnimation.value : 1.0,
                child: IconButton(
                  onPressed: _cancelRecording,
                  icon: Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Recording methods
  Future<void> _startRecording() async {
    if (widget.recordingConfig != null) {
      _voiceService.setRecordingConfig(widget.recordingConfig!);
    }

    final success = await _voiceService.startRecording();
    if (!success) {
      _showError('خطا در شروع ضبط صدا');
    }
  }

  Future<void> _stopRecording() async {
    final recordingData = await _voiceService.stopRecording();
    if (recordingData != null) {
      widget.onRecordingComplete?.call(recordingData);

      // آپلود خودکار
      if (widget.enableUpload && widget.conversationId != null) {
        await _uploadRecording(recordingData);
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _voiceService.cancelRecording();
    widget.onRecordingCancel?.call('ضبط لغو شد');
  }

  void _lockRecording() {
    _voiceService.lockRecording();
  }

  void _unlockRecording() {
    _voiceService.unlockRecording();
  }

  Future<void> _pauseRecording() async {
    await _voiceService.pauseResumeRecording();
  }

  Future<void> _resumeRecording() async {
    await _voiceService.pauseResumeRecording();
  }

  // Upload method
  Future<void> _uploadRecording(VoiceRecordingData recordingData) async {
    try {
      widget.onUploadStatus?.call('در حال آپلود...');

      final result = await _uploadService.uploadVoiceFile(
        recordingData,
        widget.conversationId!,
        onProgress: (progress) {
          widget.onUploadProgress?.call(progress);
        },
        onStatusChanged: (status) {
          widget.onUploadStatus?.call(status);
        },
      );

      if (result.isSuccess) {
        widget.onUploadStatus?.call('آپلود موفق');
      } else {
        _showError(result.error ?? 'خطا در آپلود');
      }
    } catch (e) {
      _showError('خطا در آپلود: $e');
    }
  }

  // Utility methods
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
