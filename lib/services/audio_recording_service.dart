import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioRecordingService {
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static bool _isRecording = false;
  static String? _currentRecordingPath;

  /// بررسی و درخواست مجوز میکروفون
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// شروع ضبط صدا
  static Future<bool> startRecording() async {
    try {
      if (_isRecording) return false;

      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('دسترسی به میکروفون رد شد');
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(tempDir.path, 'voice_$timestamp.aac');

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      print('ضبط صدا شروع شد: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('خطا در شروع ضبط: $e');
      return false;
    }
  }

  /// توقف ضبط صدا
  static Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final recordedPath = await _audioRecorder.stop();
      _isRecording = false;

      if (recordedPath != null && await File(recordedPath).exists()) {
        print('ضبط صدا متوقف شد: $recordedPath');
        return File(recordedPath);
      }
      return null;
    } catch (e) {
      print('خطا در توقف ضبط: $e');
      _isRecording = false;
      return null;
    }
  }

  /// لغو ضبط فعلی
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;

        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('خطا در لغو ضبط: $e');
    }
  }

  /// بررسی وضعیت ضبط
  static bool get isRecording => _isRecording;

  /// مدت زمان ضبط (در صورت نیاز)
  static Future<Duration?> getRecordingDuration() async {
    if (_currentRecordingPath != null &&
        await File(_currentRecordingPath!).exists()) {
      // می‌توانید از پکیج audio metadata برای گرفتن مدت زمان استفاده کنید
      return null; // فعلاً null برمی‌گردانیم
    }
    return null;
  }
}
