import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

/// مدل داده‌های ضبط صدا
class VoiceRecordingData {
  final String filePath;
  final int duration;
  final List<double> waveformData;
  final double fileSize;
  final DateTime timestamp;

  const VoiceRecordingData({
    required this.filePath,
    required this.duration,
    required this.waveformData,
    required this.fileSize,
    required this.timestamp,
  });
}

/// مدل تنظیمات ضبط
class RecordingConfig {
  final int bitRate;
  final int sampleRate;

  const RecordingConfig({
    this.bitRate = 128000,
    this.sampleRate = 44100,
  });

  static const RecordingConfig defaultConfig = RecordingConfig();
}

/// سرویس ضبط صدا با استفاده از audio_waveforms برای دریافت موج واقعی
class TelegramVoiceService {
  static final TelegramVoiceService _instance =
      TelegramVoiceService._internal();
  factory TelegramVoiceService() => _instance;
  TelegramVoiceService._internal();

  late RecorderController _recorderController;

  bool _isRecording = false;
  String? _currentRecordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // Callbacks
  Function(bool)? _onRecordingStateChanged;
  Function(int)? _onDurationChanged;

  static const int MIN_SEND_DURATION = 1;

  Future<void> initialize() async {
    _recorderController = RecorderController();
    // Listen to recorder state
    _recorderController.onRecorderStateChanged.listen((state) {
      _isRecording = state == RecorderState.recording;
      _onRecordingStateChanged?.call(_isRecording);
    });
    // Note: onAmplitudeChanged is not available in this version of audio_waveforms
    // _recorderController.onAmplitudeChanged.listen((amp) {
    //     _onAmplitudeChanged?.call(amp.current);
    // });
    print('🎙️ Telegram Voice Service initialized with audio_waveforms');
  }

  void setCallbacks({
    Function(bool)? onRecordingStateChanged,
    Function(int)? onDurationChanged,
  }) {
    _onRecordingStateChanged = onRecordingStateChanged;
    _onDurationChanged = onDurationChanged;
  }

  /// بررسی و درخواست مجوز میکروفون
  static Future<bool> requestMicrophonePermission() async {
    try {
      // ابتدا وضعیت فعلی را چک کن
      final status = await Permission.microphone.status;

      if (status == PermissionStatus.granted) {
        return true;
      }

      if (status == PermissionStatus.permanentlyDenied) {
        print(
            'مجوز میکروفون برای همیشه رد شده. لطفاً از تنظیمات برنامه مجوز را فعال کنید.');
        // نمی‌توانیم مستقیم تنظیمات را باز کنیم، فقط پیام مناسب نشان می‌دهیم
        return false;
      }

      // درخواست مجوز
      final result = await Permission.microphone.request();

      if (result == PermissionStatus.granted) {
        print('مجوز میکروفون اعطا شد');
        return true;
      } else {
        print('مجوز میکروفون رد شد: $result');
        return false;
      }
    } catch (e) {
      print('خطا در درخواست مجوز میکروفون: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (_isRecording) return false;
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(tempDir.path, 'voice_$timestamp.m4a');

      await _recorderController.record(
        path: _currentRecordingPath,
        sampleRate: 44100,
      );

      _startTimer();
      _isRecording = true;
      _onRecordingStateChanged?.call(true);

      // Note: onCurrentWaveform is not available in this version of audio_waveforms
      // _recorderController.onCurrentWaveform.listen((waveform) {
      //   _onWaveformDataChanged?.call(waveform);
      // });

      HapticFeedback.lightImpact();
      print(
          '🎙️ Recording started with audio_waveforms: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('❌ Error starting recording: $e');
      _cleanup();
      return false;
    }
  }

  Future<VoiceRecordingData?> stopRecording() async {
    if (!_isRecording) return null;
    try {
      final recordedPath = await _recorderController.stop();
      _stopTimer();

      if (recordedPath == null || _recordingDuration < MIN_SEND_DURATION) {
        if (recordedPath != null) {
          final file = File(recordedPath);
          if (await file.exists()) await file.delete();
        }
        _cleanup();
        return null;
      }

      final file = File(recordedPath);
      final fileSize = await file.length();
      // Note: getDecodedWaveform is not available in this version of audio_waveforms
      // Using empty waveform data for now
      final waveformData = <double>[];

      final recordingData = VoiceRecordingData(
        filePath: recordedPath,
        duration: _recordingDuration,
        waveformData: waveformData,
        fileSize: fileSize / 1024, // KB
        timestamp: DateTime.now(),
      );

      HapticFeedback.lightImpact();
      print('✅ Recording stopped: $recordedPath (${_recordingDuration}s)');
      _cleanup();
      return recordingData;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      _cleanup();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorderController.stop();
      _stopTimer();

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Recording cancelled and file deleted');
        }
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('❌ Error cancelling recording: $e');
    } finally {
      _cleanup();
    }
  }

  void _startTimer() {
    _recordingDuration = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      _onDurationChanged?.call(_recordingDuration);
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void _cleanup() {
    _isRecording = false;
    _recordingDuration = 0;
    _currentRecordingPath = null;
    _stopTimer();
    _onRecordingStateChanged?.call(false);
  }

  // Getters
  bool get isRecording => _recorderController.isRecording;
  RecorderController get recorderController => _recorderController;

  Future<void> dispose() async {
    _cleanup();
    _recorderController.dispose();
    print('🧹 Telegram Voice Service disposed');
  }
}
