import 'package:flutter/services.dart';
import 'dart:async';

/// سرویس پیشرفته بازخورد لمسی
class AdvancedHapticFeedbackService {
  // Singleton instance
  static final AdvancedHapticFeedbackService _instance =
      AdvancedHapticFeedbackService._internal();
  factory AdvancedHapticFeedbackService() => _instance;
  AdvancedHapticFeedbackService._internal();

  // تنظیمات پیش‌فرض
  static const HapticFeedbackConfig _defaultConfig = HapticFeedbackConfig(
    enableHapticFeedback: true,
    enableSoundFeedback: true,
    enableVisualFeedback: true,
    hapticIntensity: HapticIntensity.medium,
    soundVolume: 0.7,
    visualIntensity: VisualIntensity.medium,
  );

  bool _isInitialized = false;
  HapticFeedbackConfig _config = _defaultConfig;

  // Timer برای جلوگیری از spam
  Timer? _lastHapticTimer;
  DateTime? _lastHapticTime;
  static const Duration _minHapticInterval = Duration(milliseconds: 100);

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    print('📳 Advanced Haptic Feedback Service initialized');
  }

  /// تنظیم کانفیگ
  void setConfig(HapticFeedbackConfig config) {
    _config = config;
  }

  /// دریافت کانفیگ فعلی
  HapticFeedbackConfig get config => _config;

  /// بازخورد لمسی برای شروع ضبط
  Future<void> onRecordingStart() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingStart);
    await _playSound(SoundType.recordingStart);
  }

  /// بازخورد لمسی برای توقف ضبط
  Future<void> onRecordingStop() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingStop);
    await _playSound(SoundType.recordingStop);
  }

  /// بازخورد لمسی برای لغو ضبط
  Future<void> onRecordingCancel() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingCancel);
    await _playSound(SoundType.recordingCancel);
  }

  /// بازخورد لمسی برای قفل کردن ضبط
  Future<void> onRecordingLock() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingLock);
    await _playSound(SoundType.recordingLock);
  }

  /// بازخورد لمسی برای باز کردن قفل ضبط
  Future<void> onRecordingUnlock() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingUnlock);
    await _playSound(SoundType.recordingUnlock);
  }

  /// بازخورد لمسی برای مکث ضبط
  Future<void> onRecordingPause() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingPause);
    await _playSound(SoundType.recordingPause);
  }

  /// بازخورد لمسی برای ادامه ضبط
  Future<void> onRecordingResume() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.recordingResume);
    await _playSound(SoundType.recordingResume);
  }

  /// بازخورد لمسی برای کشیدن به سمت لغو
  Future<void> onDragToCancel() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.dragToCancel);
  }

  /// بازخورد لمسی برای کشیدن به سمت قفل
  Future<void> onDragToLock() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.dragToLock);
  }

  /// بازخورد لمسی برای آستانه‌های مختلف
  Future<void> onDragThreshold(double threshold) async {
    if (!_config.enableHapticFeedback) return;

    if (threshold >= 0.8) {
      await _performHaptic(HapticType.thresholdHigh);
    } else if (threshold >= 0.6) {
      await _performHaptic(HapticType.thresholdMedium);
    } else if (threshold >= 0.4) {
      await _performHaptic(HapticType.thresholdLow);
    }
  }

  /// بازخورد لمسی برای ارسال موفق
  Future<void> onSendSuccess() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.sendSuccess);
    await _playSound(SoundType.sendSuccess);
  }

  /// بازخورد لمسی برای خطا
  Future<void> onError() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.error);
    await _playSound(SoundType.error);
  }

  /// بازخورد لمسی برای هشدار
  Future<void> onWarning() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.warning);
    await _playSound(SoundType.warning);
  }

  /// بازخورد لمسی برای موفقیت
  Future<void> onSuccess() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.success);
    await _playSound(SoundType.success);
  }

  /// بازخورد لمسی برای کلیک
  Future<void> onTap() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.tap);
  }

  /// بازخورد لمسی برای لمس طولانی
  Future<void> onLongPress() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.longPress);
  }

  /// بازخورد لمسی برای اسکرول
  Future<void> onScroll() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.scroll);
  }

  /// بازخورد لمسی برای انتخاب
  Future<void> onSelection() async {
    if (!_config.enableHapticFeedback) return;

    await _performHaptic(HapticType.selection);
  }

  /// اجرای بازخورد لمسی
  Future<void> _performHaptic(HapticType type) async {
    if (!_config.enableHapticFeedback) return;

    // جلوگیری از spam
    if (_lastHapticTime != null) {
      final timeSinceLastHaptic = DateTime.now().difference(_lastHapticTime!);
      if (timeSinceLastHaptic < _minHapticInterval) {
        return;
      }
    }

    _lastHapticTime = DateTime.now();

    try {
      switch (type) {
        case HapticType.recordingStart:
          await _performRecordingStartHaptic();
          break;
        case HapticType.recordingStop:
          await _performRecordingStopHaptic();
          break;
        case HapticType.recordingCancel:
          await _performRecordingCancelHaptic();
          break;
        case HapticType.recordingLock:
          await _performRecordingLockHaptic();
          break;
        case HapticType.recordingUnlock:
          await _performRecordingUnlockHaptic();
          break;
        case HapticType.recordingPause:
          await _performRecordingPauseHaptic();
          break;
        case HapticType.recordingResume:
          await _performRecordingResumeHaptic();
          break;
        case HapticType.dragToCancel:
          await _performDragToCancelHaptic();
          break;
        case HapticType.dragToLock:
          await _performDragToLockHaptic();
          break;
        case HapticType.thresholdHigh:
          await _performThresholdHighHaptic();
          break;
        case HapticType.thresholdMedium:
          await _performThresholdMediumHaptic();
          break;
        case HapticType.thresholdLow:
          await _performThresholdLowHaptic();
          break;
        case HapticType.sendSuccess:
          await _performSendSuccessHaptic();
          break;
        case HapticType.error:
          await _performErrorHaptic();
          break;
        case HapticType.warning:
          await _performWarningHaptic();
          break;
        case HapticType.success:
          await _performSuccessHaptic();
          break;
        case HapticType.tap:
          await _performTapHaptic();
          break;
        case HapticType.longPress:
          await _performLongPressHaptic();
          break;
        case HapticType.scroll:
          await _performScrollHaptic();
          break;
        case HapticType.selection:
          await _performSelectionHaptic();
          break;
      }
    } catch (e) {
      print('❌ خطا در بازخورد لمسی: $e');
    }
  }

  /// بازخورد لمسی شروع ضبط
  Future<void> _performRecordingStartHaptic() async {
    switch (_config.hapticIntensity) {
      case HapticIntensity.low:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.high:
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  /// بازخورد لمسی توقف ضبط
  Future<void> _performRecordingStopHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// بازخورد لمسی لغو ضبط
  Future<void> _performRecordingCancelHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// بازخورد لمسی قفل ضبط
  Future<void> _performRecordingLockHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 30));
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی باز کردن قفل ضبط
  Future<void> _performRecordingUnlockHaptic() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 30));
    await HapticFeedback.lightImpact();
  }

  /// بازخورد لمسی مکث ضبط
  Future<void> _performRecordingPauseHaptic() async {
    await HapticFeedback.lightImpact();
  }

  /// بازخورد لمسی ادامه ضبط
  Future<void> _performRecordingResumeHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی کشیدن به سمت لغو
  Future<void> _performDragToCancelHaptic() async {
    await HapticFeedback.selectionClick();
  }

  /// بازخورد لمسی کشیدن به سمت قفل
  Future<void> _performDragToLockHaptic() async {
    await HapticFeedback.selectionClick();
  }

  /// بازخورد لمسی آستانه بالا
  Future<void> _performThresholdHighHaptic() async {
    await HapticFeedback.heavyImpact();
  }

  /// بازخورد لمسی آستانه متوسط
  Future<void> _performThresholdMediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی آستانه پایین
  Future<void> _performThresholdLowHaptic() async {
    await HapticFeedback.lightImpact();
  }

  /// بازخورد لمسی ارسال موفق
  Future<void> _performSendSuccessHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// بازخورد لمسی خطا
  Future<void> _performErrorHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// بازخورد لمسی هشدار
  Future<void> _performWarningHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی موفقیت
  Future<void> _performSuccessHaptic() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی کلیک
  Future<void> _performTapHaptic() async {
    await HapticFeedback.selectionClick();
  }

  /// بازخورد لمسی لمس طولانی
  Future<void> _performLongPressHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  /// بازخورد لمسی اسکرول
  Future<void> _performScrollHaptic() async {
    await HapticFeedback.selectionClick();
  }

  /// بازخورد لمسی انتخاب
  Future<void> _performSelectionHaptic() async {
    await HapticFeedback.selectionClick();
  }

  /// پخش صدا
  Future<void> _playSound(SoundType type) async {
    if (!_config.enableSoundFeedback) return;

    // TODO: پیاده‌سازی پخش صدا
    // می‌توان از just_audio یا audioplayers استفاده کرد
  }

  /// بازخورد لمسی سفارشی
  Future<void> customHaptic({
    required HapticIntensity intensity,
    int? duration,
    int? pattern,
  }) async {
    if (!_config.enableHapticFeedback) return;

    switch (intensity) {
      case HapticIntensity.low:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.high:
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  /// تست بازخورد لمسی
  Future<void> testHaptic() async {
    await _performHaptic(HapticType.tap);
    await Future.delayed(const Duration(milliseconds: 200));
    await _performHaptic(HapticType.thresholdMedium);
    await Future.delayed(const Duration(milliseconds: 200));
    await _performHaptic(HapticType.thresholdHigh);
  }

  /// پاکسازی منابع
  void dispose() {
    _lastHapticTimer?.cancel();
    _isInitialized = false;
    print('🧹 Advanced Haptic Feedback Service disposed');
  }
}

/// تنظیمات بازخورد لمسی
class HapticFeedbackConfig {
  final bool enableHapticFeedback;
  final bool enableSoundFeedback;
  final bool enableVisualFeedback;
  final HapticIntensity hapticIntensity;
  final double soundVolume;
  final VisualIntensity visualIntensity;

  const HapticFeedbackConfig({
    required this.enableHapticFeedback,
    required this.enableSoundFeedback,
    required this.enableVisualFeedback,
    required this.hapticIntensity,
    required this.soundVolume,
    required this.visualIntensity,
  });

  HapticFeedbackConfig copyWith({
    bool? enableHapticFeedback,
    bool? enableSoundFeedback,
    bool? enableVisualFeedback,
    HapticIntensity? hapticIntensity,
    double? soundVolume,
    VisualIntensity? visualIntensity,
  }) {
    return HapticFeedbackConfig(
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableSoundFeedback: enableSoundFeedback ?? this.enableSoundFeedback,
      enableVisualFeedback: enableVisualFeedback ?? this.enableVisualFeedback,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      soundVolume: soundVolume ?? this.soundVolume,
      visualIntensity: visualIntensity ?? this.visualIntensity,
    );
  }
}

/// انواع بازخورد لمسی
enum HapticType {
  recordingStart,
  recordingStop,
  recordingCancel,
  recordingLock,
  recordingUnlock,
  recordingPause,
  recordingResume,
  dragToCancel,
  dragToLock,
  thresholdHigh,
  thresholdMedium,
  thresholdLow,
  sendSuccess,
  error,
  warning,
  success,
  tap,
  longPress,
  scroll,
  selection,
}

/// انواع صدا
enum SoundType {
  recordingStart,
  recordingStop,
  recordingCancel,
  recordingLock,
  recordingUnlock,
  recordingPause,
  recordingResume,
  sendSuccess,
  error,
  warning,
  success,
}

/// شدت بازخورد لمسی
enum HapticIntensity {
  low,
  medium,
  high,
}

/// شدت بازخورد بصری
enum VisualIntensity {
  low,
  medium,
  high,
}
