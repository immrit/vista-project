// lib/features/chat/services/voice_recorder_service.dart
//
// سرویس ضبط صدا (Voice Recording) مدرن
//
// ویژگی‌ها:
// ✅ ضبط صدا با کیفیت AAC (مثل ویستا)
// ✅ مدیریت خودکار پرمیشن‌ها
// ✅ استریم دامنه صدا برای ویژوالایزر (Waveform)
// ✅ مدیریت فایل‌های موقت
// ✅ لغو با حذف خودکار

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// سرویس ضبط صدا - Singleton Pattern
class VoiceRecorderService {
  static final VoiceRecorderService _instance =
      VoiceRecorderService._internal();

  factory VoiceRecorderService() => _instance;

  VoiceRecorderService._internal();

  // Lazily create the AudioRecorder to avoid platform channel calls during
  // test construction (which cause MissingPluginException in unit tests).
  AudioRecorder? _audioRecorder;

  // استریم برای نمایش ویژوالایزر هنگام ضبط.
  // Lazily recreated: this service is a singleton but dispose() is called from
  // widget dispose — a closed controller would break recording forever after
  // the first chat screen closed (add on closed controller throws).
  StreamController<double>? _amplitudeController;

  StreamController<double> get _amplitude {
    final existing = _amplitudeController;
    if (existing != null && !existing.isClosed) return existing;
    final created = StreamController<double>.broadcast();
    _amplitudeController = created;
    return created;
  }

  Stream<double> get amplitudeStream => _amplitude.stream;

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  String? _currentPath;
  Timer? _amplitudeTimer;

  /// بررسی و درخواست پرمیشن میکروفن
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// شروع ضبط صدا
  Future<void> startRecording() async {
    try {
      if (await hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName =
            'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = '${appDir.path}/$fileName';

        // تنظیمات کیفیت ضبط (مثل ویستا)
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        _audioRecorder ??= AudioRecorder();
        await _audioRecorder!.start(config, path: _currentPath!);
        _isRecording = true;

        // شروع دریافت دامنه صدا برای ویژوالایزر
        _startAmplitudeTimer();
      }
    } catch (e) {
      // خاموش نگه داشتن اگر خرابی بود
      _isRecording = false;
    }
  }

  /// توقف ضبط و دریافت فایل
  Future<File?> stopRecording() async {
    _stopAmplitudeTimer();

    if (!_isRecording) return null;
    _isRecording = false;

    try {
      final path = await _audioRecorder?.stop();
      if (path != null) {
        return File(path);
      }
    } catch (e) {
      // خاموش نگه داشتن اگر خرابی بود
    }
    return null;
  }

  /// لغو ضبط (حذف فایل)
  Future<void> cancelRecording() async {
    _stopAmplitudeTimer();
    _isRecording = false;

    await _audioRecorder?.stop();
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _currentPath = null;
  }

  /// تایمر برای دریافت دامنه صدا
  void _startAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_isRecording) {
        try {
          final amplitude = await _audioRecorder?.getAmplitude();
          if (amplitude == null) return;
          // نرمال‌سازی مقدار بین 0 تا 1
          final normalized = (amplitude.current + 160) / 160;
          _amplitude.add(normalized.clamp(0.0, 1.0));
        } catch (e) {
          // خاموش نگه داشتن اگر خرابی بود
        }
      }
    });
  }

  void _stopAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  void dispose() {
    _stopAmplitudeTimer();
    _audioRecorder?.dispose();
    _audioRecorder = null; // lazily recreated on next startRecording
    _amplitudeController?.close();
    _amplitudeController = null; // lazily recreated on next use
    _isRecording = false;
  }
}
