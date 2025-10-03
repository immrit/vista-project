import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../../services/audio_recording_service.dart';
import '../../services/telegram_voice_integration_service.dart';
import '../../services/telegram_voice_upload_service.dart';
import '../../services/audio_enhancement_service.dart';
import 'enhanced_voice_visualizer.dart';
import 'voice_recording_settings.dart';

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
  late AnimationController _startRecordingController;
  late AnimationController _sendSuccessController;
  late AnimationController _recordingStartEffectController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _lockAnimation;
  late Animation<double> _cancelAnimation;
  late Animation<double> _startRecordingAnimation;
  late Animation<double> _sendSuccessAnimation;
  late Animation<double> _recordingStartEffectAnimation;

  // Voice service
  final TelegramVoiceUploadService _uploadService =
      TelegramVoiceUploadService();

  // Recording state
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isCanceling = false;
  bool _isPaused = false;
  int _recordingDuration = 0;
  final List<double> _waveformData = [];

  // Gesture tracking
  Offset _dragOffset = Offset.zero;
  double _dragDistance = 0.0;

  // UI state
  String _statusText = 'برای ضبط نگه دارید';
  Color _statusColor = Colors.grey;

  // Enhancement settings
  AudioEnhancementConfig _enhancementConfig =
      AudioEnhancementService.defaultConfig;

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

    // Start recording animation (مثل تلگرام)
    _startRecordingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _startRecordingAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_startRecordingController);

    // Send success animation
    _sendSuccessController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sendSuccessAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_sendSuccessController);

    // Recording start effect animation (مثل موج انفجاری)
    _recordingStartEffectController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _recordingStartEffectAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_recordingStartEffectController);
  }

  void _initializeVoiceService() {
    TelegramVoiceService.setCallbacks(
      onRecordingStateChanged: (isRecording) {
        if (mounted) {
          setState(() {
            _isRecording = isRecording;
            if (isRecording) {
              _statusText = 'در حال ضبط...';
              _statusColor = Colors.red;
            } else {
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
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveformController.dispose();
    _lockController.dispose();
    _cancelController.dispose();
    _startRecordingController.dispose();
    _sendSuccessController.dispose();
    _recordingStartEffectController.dispose();
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
      child: Stack(
        children: [
          Row(
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

          // Recording start effect overlay
          if (_recordingStartEffectAnimation.value > 0)
            AnimatedBuilder(
              animation: _recordingStartEffectAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.centerLeft,
                        radius:
                            2.0 + (3.0 * _recordingStartEffectAnimation.value),
                        colors: [
                          Colors.red.withValues(
                              alpha: 0.3 *
                                  (1.0 - _recordingStartEffectAnimation.value)),
                          Colors.red.withValues(
                              alpha: 0.1 *
                                  (1.0 - _recordingStartEffectAnimation.value)),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
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
          ? (details) {
              _dragOffset = details.localPosition;
            }
          : null,
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
        animation:
            Listenable.merge([_pulseAnimation, _startRecordingAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording
                ? (_startRecordingAnimation.value * _pulseAnimation.value)
                : _startRecordingAnimation.value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _isRecording
                    ? (_isLocked ? Colors.orange : Colors.red)
                    : (isDark
                        ? const Color(0xFFE0E0E0) // خاکستری روشن در تم تاریک
                        : const Color(0xFF2196F3)), // آبی ثابت برای تم روشن
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? (_isLocked ? Colors.orange : Colors.red)
                            : (isDark
                                ? const Color(0xFFE0E0E0)
                                : const Color(0xFF2196F3)))
                        .withValues(alpha: isDark ? 0.6 : 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isRecording
                    ? (_isPaused ? Icons.play_arrow : Icons.stop)
                    : Icons.mic,
                color: _isRecording
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF424242)
                        : Colors.white), // خاکستری تیره برای تم تاریک
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
        // Status text with animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _statusText,
            key: ValueKey(_statusText),
            style: TextStyle(
              color: _statusColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Waveform with better animation
        if (_isRecording) _buildWaveform(isDark, colorScheme),

        // Duration and info with professional styling
        if (_isRecording)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isLocked
                    ? Colors.orange.withValues(alpha: 0.3)
                    : colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: VoiceInfoDisplay(
              duration: _recordingDuration,
              fileSize: 0, // محاسبه خواهد شد
              isRecording: _isRecording,
              isPlaying: false,
              status: _isPaused ? 'مکث' : (_isLocked ? 'قفل شده' : null),
            ),
          ),

        // Recording hint
        if (!_isRecording && !_isLocked)
          AnimatedOpacity(
            opacity: 0.7,
            duration: const Duration(milliseconds: 500),
            child: Text(
              'برای شروع ضبط، دکمه را نگه دارید',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
          child: SizedBox(
            height: 30,
            child: EnhancedVoiceVisualizer(
              waveformData: _waveformData,
              isRecording: _isRecording,
              isPlaying: false,
              progress: _recordingDuration / 60.0, // پیشرفت بر اساس مدت زمان
              primaryColor: _isLocked ? Colors.orange : Colors.red,
              secondaryColor: colorScheme.secondary,
              height: 30,
              showProgress: true,
              animated: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(bool isDark, ColorScheme colorScheme) {
    // اگر انیمیشن موفقیت در حال اجرا است، فقط آیکون موفقیت نشان بده
    if (_sendSuccessAnimation.value > 0) {
      return AnimatedBuilder(
        animation: _sendSuccessAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (0.4 * _sendSuccessAnimation.value),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(
                    alpha: 0.2 + (0.8 * _sendSuccessAnimation.value)),
                border: Border.all(
                  color: Colors.green
                      .withValues(alpha: _sendSuccessAnimation.value),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check,
                color: Colors.green,
                size: 28 * _sendSuccessAnimation.value,
              ),
            ),
          );
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause/Resume button
        if (widget.enablePause && _isRecording && !_isLocked)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPaused ? Colors.green : Colors.orange,
              boxShadow: [
                BoxShadow(
                  color: (_isPaused ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isPaused ? _resumeRecording : _pauseRecording,
              icon: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
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

        // Stop button
        if (_isRecording && !_isLocked)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _stopRecording,
              icon: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),

        // Cancel button
        if (_isRecording)
          AnimatedBuilder(
            animation:
                Listenable.merge([_cancelAnimation, _startRecordingAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _isCanceling
                    ? (1.0 + 0.3 * _cancelAnimation.value)
                    : (_startRecordingAnimation.value > 0.5
                        ? 1.0
                        : _startRecordingAnimation.value),
                child: Transform.translate(
                  offset: _isCanceling
                      ? Offset(
                          math.sin(_cancelAnimation.value * math.pi * 4) * 5,
                          math.cos(_cancelAnimation.value * math.pi * 3) * 3,
                        )
                      : Offset.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(
                          alpha: _isCanceling
                              ? 0.3 + (0.7 * _cancelAnimation.value)
                              : 0.1),
                    ),
                    child: IconButton(
                      onPressed: _cancelRecording,
                      icon: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: _isCanceling
                            ? 24 + (4 * _cancelAnimation.value)
                            : 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // Settings button
        IconButton(
          onPressed: _showSettings,
          icon: Icon(
            Icons.settings,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // Recording methods
  Future<void> _startRecording() async {
    final success = await TelegramVoiceService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _isLocked = false;
        _isCanceling = false;
        _isPaused = false;
        _recordingDuration = 0;
        _dragDistance = 0.0;
        _dragOffset = Offset.zero;
      });
      _playStartRecordingSound();
      _startRecordingController.forward(from: 0.0);
      _recordingStartEffectController.forward(from: 0.0);
      _pulseController.repeat(reverse: true);
      _waveformController.forward();
    } else {
      _showError('خطا در شروع ضبط صدا');
    }
  }

  Future<void> _stopRecording() async {
    final file = await TelegramVoiceService.stopRecording();
    if (file != null) {
      // Convert File to VoiceRecordingData
      final recordingData = VoiceRecordingData(
        filePath: file.path,
        duration: _recordingDuration,
        waveformData: TelegramVoiceService.waveformData,
        fileSize: await file.length() / 1024,
        timestamp: DateTime.now(),
      );

      setState(() {
        _isRecording = false;
        _isLocked = false;
        _isCanceling = false;
        _isPaused = false;
        _recordingDuration = 0;
        _dragDistance = 0.0;
        _dragOffset = Offset.zero;
      });

      _pulseController.stop();
      _waveformController.reverse();

      // بهبود کیفیت صدا اگر فعال باشد
      VoiceRecordingData enhancedRecordingData = recordingData;
      if (_enhancementConfig.enableNoiseReduction ||
          _enhancementConfig.enableEchoCancellation ||
          _enhancementConfig.enableAutoGain) {
        try {
          widget.onUploadStatus?.call('در حال بهبود کیفیت...');
          final enhancedFile = await AudioEnhancementService().enhanceAudioFile(
            File(recordingData.filePath),
            config: _enhancementConfig,
            onProgress: (progress) {
              // گزارش پیشرفت بهبود
            },
          );

          if (enhancedFile != null) {
            enhancedRecordingData = VoiceRecordingData(
              filePath: enhancedFile.path,
              duration: recordingData.duration,
              waveformData: recordingData.waveformData,
              fileSize: await enhancedFile.length() / 1024,
              timestamp: recordingData.timestamp,
            );
            print('✅ کیفیت صدا بهبود یافت');
          }
        } catch (e) {
          print('❌ خطا در بهبود کیفیت صدا: $e');
          // ادامه بدون بهبود
        }
      }

      // انیمیشن موفقیت ارسال
      _sendSuccessController.forward(from: 0.0);

      widget.onRecordingComplete?.call(enhancedRecordingData);

      // آپلود خودکار
      if (widget.enableUpload && widget.conversationId != null) {
        await _uploadRecording(recordingData);
      }
    }
  }

  Future<void> _cancelRecording() async {
    // شروع انیمیشن لغو
    setState(() {
      _isCanceling = true;
    });

    // افکت صوتی لغو
    await _playCancelSound();

    await TelegramVoiceService.cancelRecording();

    // انیمیشن‌های لغو
    _pulseController.stop();
    _waveformController.reverse();
    _cancelController.forward();
    _startRecordingController.reverse();

    // منتظر تمام شدن انیمیشن‌ها
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isCanceling = false;
      _isPaused = false;
      _recordingDuration = 0;
      _dragDistance = 0.0;
      _dragOffset = Offset.zero;
      _statusText = 'ضبط لغو شد';
      _statusColor = Colors.red;
    });

    // نمایش پیام لغو برای کاربر
    widget.onRecordingCancel?.call('ضبط لغو شد');

    // بازنشانی وضعیت پس از چند ثانیه
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _statusText = 'برای ضبط نگه دارید';
        _statusColor = Colors.grey;
      });
    }
  }

  void _lockRecording() {
    setState(() {
      _isLocked = true;
    });
    _lockController.forward();
    print('Recording locked');
  }

  void _unlockRecording() {
    setState(() {
      _isLocked = false;
    });
    _lockController.reverse();
    print('Recording unlocked');
  }

  Future<void> _pauseRecording() async {
    await TelegramVoiceService.pauseRecording();
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await TelegramVoiceService.resumeRecording();
    setState(() {
      _isPaused = false;
    });
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

  // افکت صوتی شروع ضبط
  Future<void> _playStartRecordingSound() async {
    try {
      // استفاده از HapticFeedback برای بازخورد لمسی
      await HapticFeedback.mediumImpact();
    } catch (e) {
      print('خطا در پخش افکت صوتی: $e');
    }
  }

  // افکت صوتی لغو ضبط
  Future<void> _playCancelSound() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('خطا در پخش افکت لغو: $e');
    }
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

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => VoiceRecordingSettingsDialog(
        initialConfig: _enhancementConfig,
        onConfigChanged: (config) {
          setState(() {
            _enhancementConfig = config;
          });
        },
      ),
    );
  }
}
