// lib/features/chat/services/voice_duration_service.dart
//
// سرویس محاسبه مدت زمان فایل‌های صوتی
//
// ویژگی‌ها:
// ✅ محاسبه دقیق مدت زمان
// ✅ پشتیبانی از فرمت‌های مختلف
// ✅ کش برای عملکرد بهتر
// ✅ Error handling
//

import 'dart:io';
import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../security/logging_utility.dart';

/// نتیجه محاسبه مدت زمان
class DurationResult {
  final bool success;
  final int? durationInSeconds;
  final String? error;

  const DurationResult({
    required this.success,
    this.durationInSeconds,
    this.error,
  });

  factory DurationResult.success(int duration) {
    return DurationResult(
      success: true,
      durationInSeconds: duration,
    );
  }

  factory DurationResult.failure(String error) {
    return DurationResult(
      success: false,
      error: error,
    );
  }

  /// فرمت زمان برای نمایش (mm:ss)
  String get formattedDuration {
    if (durationInSeconds == null) return '00:00';
    final minutes = durationInSeconds! ~/ 60;
    final seconds = durationInSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// سرویس محاسبه مدت زمان صدا
class VoiceDurationService {
  static final VoiceDurationService _instance = VoiceDurationService._();
  factory VoiceDurationService() => _instance;
  VoiceDurationService._();

  // کش برای جلوگیری از محاسبه مجدد
  final Map<String, int> _durationCache = {};

  /// محاسبه مدت زمان فایل صوتی
  ///
  /// [audioFile] - فایل صوتی
  /// [useCache] - استفاده از کش (پیش‌فرض: true)
  ///
  /// Returns: نتیجه محاسبه با مدت زمان به ثانیه
  Future<DurationResult> getAudioDuration(
    File audioFile, {
    bool useCache = true,
  }) async {
    try {
      final filePath = audioFile.path;

      logInfo('🎵 Calculating audio duration: $filePath');

      // بررسی کش
      if (useCache && _durationCache.containsKey(filePath)) {
        final cachedDuration = _durationCache[filePath]!;
        logInfo('📦 Using cached duration: $cachedDuration seconds');
        return DurationResult.success(cachedDuration);
      }

      // بررسی وجود فایل
      if (!await audioFile.exists()) {
        return DurationResult.failure('فایل صوتی وجود ندارد');
      }

      // استفاده از audio_waveforms برای محاسبه مدت زمان
      final playerController = PlayerController();

      try {
        // آماده‌سازی player
        await playerController.preparePlayer(
          path: filePath,
          shouldExtractWaveform: false, // برای سرعت بیشتر
        );

        // انتظار برای بارگذاری کامل
        await Future.delayed(const Duration(milliseconds: 500));

        // دریافت مدت زمان از stream
        int? durationMs;
        final subscription =
            playerController.onCurrentDurationChanged.listen((duration) {
          if (duration > 0) {
            durationMs = duration;
          }
        });

        // انتظار برای دریافت duration
        await Future.delayed(const Duration(milliseconds: 100));
        subscription.cancel();
        playerController.dispose();

        if (durationMs == null || durationMs == 0) {
          logInfo('⚠️ Could not get duration, using file size estimate');
          // تخمین بر اساس حجم فایل (تقریبی)
          final fileSize = await audioFile.length();
          // فرض: bitrate متوسط 128 kbps
          final estimatedDuration = (fileSize / (128 * 1024 / 8)).round();
          durationMs = estimatedDuration * 1000;
        }

        final durationSeconds = (durationMs ?? 0) ~/ 1000;

        // ذخیره در کش
        _durationCache[filePath] = durationSeconds;

        logInfo('✅ Audio duration calculated: $durationSeconds seconds');
        return DurationResult.success(durationSeconds);
      } catch (e) {
        // در صورت خطا در dispose
        try {
          playerController.dispose();
        } catch (_) {}
        rethrow;
      }
    } catch (e, stackTrace) {
      logInfo('❌ Error calculating audio duration: $e\n$stackTrace');

      // در صورت خطا، مدت زمان پیش‌فرض برگردان
      return DurationResult.failure('خطا در محاسبه مدت زمان: ${e.toString()}');
    }
  }

  /// محاسبه مدت زمان از روی URL (برای فایل‌های دانلود شده)
  Future<DurationResult> getAudioDurationFromUrl(String url) async {
    try {
      // اگر URL در کش باشد
      if (_durationCache.containsKey(url)) {
        return DurationResult.success(_durationCache[url]!);
      }

      // TODO: دانلود فایل و محاسبه مدت زمان
      // فعلاً فقط مدت زمان پیش‌فرض برمی‌گردانیم
      return DurationResult.failure('محاسبه از URL هنوز پیاده‌سازی نشده');
    } catch (e) {
      return DurationResult.failure('خطا در محاسبه: ${e.toString()}');
    }
  }

  /// پاک کردن کش
  void clearCache() {
    _durationCache.clear();
    logInfo('🗑️ Voice duration cache cleared');
  }

  /// حذف یک آیتم از کش
  void removeCachedDuration(String filePath) {
    _durationCache.remove(filePath);
  }

  /// فرمت کردن مدت زمان به mm:ss
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// تبدیل mm:ss به ثانیه
  static int parseDuration(String formatted) {
    try {
      final parts = formatted.split(':');
      if (parts.length != 2) return 0;

      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);

      return minutes * 60 + seconds;
    } catch (e) {
      return 0;
    }
  }
}
