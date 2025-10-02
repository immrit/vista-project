import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

/// سرویس ضبط صدا حرفه‌ای مثل تلگرام
class TelegramVoiceService {
  // Recorder instance
  static final AudioRecorder _audioRecorder = AudioRecorder();

  // Recording state
  static bool _isRecording = false;
  static bool _isLocked = false;
  static bool _isCanceling = false;
  static String? _currentRecordingPath;
  static int _recordingDuration = 0;
  static Timer? _recordingTimer;

  // Waveform data
  static List<double> _waveformData = [];
  static Timer? _waveformTimer;

  // Callbacks
  static Function(bool)? _onRecordingStateChanged;
  static Function(int)? _onDurationChanged;
  static Function(List<double>)? _onWaveformDataChanged;
  static Function(bool)? _onLockedStateChanged;
  static Function(bool)? _onCancelingStateChanged;

  /// حداکثر مدت زمان ضبط (ثانیه)
  static const int MAX_RECORDING_DURATION = 60;
  static const int LOCKED_MAX_DURATION = 120;

  /// حداقل مدت زمان برای ارسال (ثانیه)
  static const int MIN_SEND_DURATION = 1;

  /// تنظیم callbacks
  static void setCallbacks({
    Function(bool)? onRecordingStateChanged,
    Function(int)? onDurationChanged,
    Function(List<double>)? onWaveformDataChanged,
    Function(bool)? onLockedStateChanged,
    Function(bool)? onCancelingStateChanged,
  }) {
    _onRecordingStateChanged = onRecordingStateChanged;
    _onDurationChanged = onDurationChanged;
    _onWaveformDataChanged = onWaveformDataChanged;
    _onLockedStateChanged = onLockedStateChanged;
    _onCancelingStateChanged = onCancelingStateChanged;
  }

  /// بررسی و درخواست مجوز میکروفون
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('خطا در درخواست مجوز میکروفون: $e');
      return false;
    }
  }

  /// شروع ضبط صدا
  static Future<bool> startRecording() async {
    try {
      if (_isRecording) return false;

      // بررسی مجوز
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('دسترسی به میکروفون رد شد');
      }

      // تنظیم مسیر فایل
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(tempDir.path, 'voice_$timestamp.m4a');

      // تنظیمات ضبط ساده و سازگار
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      // شروع تایمر مدت زمان
      _recordingDuration = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        _onDurationChanged?.call(_recordingDuration);

        // بررسی محدودیت زمانی
        final maxDuration =
            _isLocked ? LOCKED_MAX_DURATION : MAX_RECORDING_DURATION;
        if (_recordingDuration >= maxDuration) {
          stopRecording();
        }
      });

      // شروع شبیه‌سازی waveform
      _waveformData = [];
      _startWaveformSimulation();

      _isRecording = true;
      _isLocked = false;
      _isCanceling = false;

      // haptic feedback
      HapticFeedback.lightImpact();

      _onRecordingStateChanged?.call(true);
      _onLockedStateChanged?.call(false);
      _onCancelingStateChanged?.call(false);

      print('🎙️ ضبط صدا شروع شد: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('❌ خطا در شروع ضبط: $e');
      _cleanup();
      return false;
    }
  }

  /// توقف ضبط صدا و بازگشت فایل
  static Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final recordedPath = await _audioRecorder.stop();
      final wasValid = _recordingDuration >= MIN_SEND_DURATION;

      _cleanup();

      if (recordedPath != null &&
          await File(recordedPath).exists() &&
          wasValid) {
        print('✅ ضبط صدا متوقف شد: $recordedPath (${_recordingDuration}s)');
        return File(recordedPath);
      }

      // حذف فایل اگر مدت زمان کافی نبود
      if (recordedPath != null) {
        final file = File(recordedPath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ فایل کوتاه حذف شد');
        }
      }

      return null;
    } catch (e) {
      print('❌ خطا در توقف ضبط: $e');
      _cleanup();
      return null;
    }
  }

  /// لغو ضبط صدا
  static Future<void> cancelRecording() async {
    try {
      if (!_isRecording) return;

      await _audioRecorder.stop();
      _isCanceling = true;
      _onCancelingStateChanged?.call(true);

      _cleanup();

      // حذف فایل
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ فایل ضبط لغو شد');
        }
      }

      // haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('❌ خطا در لغو ضبط: $e');
      _cleanup();
    }
  }

  /// قفل کردن ضبط صدا
  static void lockRecording() {
    if (!_isRecording) return;

    _isLocked = true;
    _onLockedStateChanged?.call(true);

    // haptic feedback
    HapticFeedback.heavyImpact();

    print('🔒 ضبط قفل شد');
  }

  /// باز کردن قفل ضبط صدا
  static void unlockRecording() {
    if (!_isRecording) return;

    _isLocked = false;
    _onLockedStateChanged?.call(false);

    print('🔓 قفل باز شد');
  }

  /// شروع شبیه‌سازی waveform
  static void _startWaveformSimulation() {
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      // تولید داده‌های waveform تصادفی
      final random = Random();
      final newData =
          List<double>.generate(8, (index) => random.nextDouble() * 100);

      _waveformData.addAll(newData);
      // نگه داشتن فقط آخرین 50 نمونه
      if (_waveformData.length > 400) {
        _waveformData.removeRange(0, _waveformData.length - 400);
      }

      _onWaveformDataChanged?.call(List.from(_waveformData));
    });
  }

  /// پاکسازی منابع
  static void _cleanup() {
    _isRecording = false;
    _isLocked = false;
    _isCanceling = false;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    _waveformTimer?.cancel();
    _waveformTimer = null;

    _onRecordingStateChanged?.call(false);
  }

  // Getters
  static bool get isRecording => _isRecording;
  static bool get isLocked => _isLocked;
  static bool get isCanceling => _isCanceling;
  static int get recordingDuration => _recordingDuration;
  static int get maxDuration =>
      _isLocked ? LOCKED_MAX_DURATION : MAX_RECORDING_DURATION;
  static List<double> get waveformData => _waveformData;
  static String? get currentRecordingPath => _currentRecordingPath;

  /// پاکسازی کامل سرویس
  static void dispose() {
    _cleanup();
    print('🧹 سرویس ضبط صدا پاکسازی شد');
  }
}
