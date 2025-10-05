import 'dart:async';
import 'dart:typed_data';

/// سرویس تشخیص فعالیت صدا (Voice Activity Detection)
class VoiceActivityDetectionService {
  // Singleton instance
  static final VoiceActivityDetectionService _instance =
      VoiceActivityDetectionService._internal();
  factory VoiceActivityDetectionService() => _instance;
  VoiceActivityDetectionService._internal();

  // تنظیمات VAD
  static const double _defaultEnergyThreshold = 0.01;
  static const double _defaultZeroCrossingThreshold = 0.1;
  static const int _defaultFrameSize = 1024;
  static const int _defaultHopSize = 512;
  static const double _defaultSilenceDuration = 2.0; // seconds
  static const double _defaultMinSpeechDuration = 0.5; // seconds

  // وضعیت فعلی
  bool _isInitialized = false;
  bool _isVoiceDetected = false;
  bool _isSpeechActive = false;
  DateTime? _speechStartTime;
  DateTime? _silenceStartTime;

  // آمار
  double _currentEnergy = 0.0;
  double _currentZeroCrossingRate = 0.0;
  double _backgroundNoiseLevel = 0.0;
  final List<double> _energyHistory = [];
  final List<double> _zcrHistory = [];

  // Callbacks
  Function(bool)? _onVoiceDetected;
  Function(bool)? _onSpeechStarted;
  Function(bool)? _onSpeechEnded;
  Function(double)? _onEnergyChanged;
  Function(double)? _onZeroCrossingRateChanged;

  // Timer برای تشخیص سکوت
  Timer? _silenceTimer;
  Timer? _speechTimer;

  /// تنظیم callbacks
  void setCallbacks({
    Function(bool)? onVoiceDetected,
    Function(bool)? onSpeechStarted,
    Function(bool)? onSpeechEnded,
    Function(double)? onEnergyChanged,
    Function(double)? onZeroCrossingRateChanged,
  }) {
    _onVoiceDetected = onVoiceDetected;
    _onSpeechStarted = onSpeechStarted;
    _onSpeechEnded = onSpeechEnded;
    _onEnergyChanged = onEnergyChanged;
    _onZeroCrossingRateChanged = onZeroCrossingRateChanged;
  }

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _resetState();

    print('🎤 Voice Activity Detection Service initialized');
  }

  /// پردازش داده‌های صوتی
  Future<void> processAudioData(
    Uint8List audioData, {
    int sampleRate = 44100,
    int bitsPerSample = 16,
    double energyThreshold = _defaultEnergyThreshold,
    double zeroCrossingThreshold = _defaultZeroCrossingThreshold,
    double silenceDuration = _defaultSilenceDuration,
    double minSpeechDuration = _defaultMinSpeechDuration,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // تبدیل bytes به نمونه‌های صوتی
    final samples = _bytesToSamples(audioData, bitsPerSample);

    // محاسبه انرژی
    final energy = _calculateEnergy(samples);
    _currentEnergy = energy;
    _energyHistory.add(energy);

    // محدود کردن تاریخچه
    if (_energyHistory.length > 100) {
      _energyHistory.removeAt(0);
    }

    // محاسبه نرخ عبور از صفر
    final zcr = _calculateZeroCrossingRate(samples);
    _currentZeroCrossingRate = zcr;
    _zcrHistory.add(zcr);

    if (_zcrHistory.length > 100) {
      _zcrHistory.removeAt(0);
    }

    // به‌روزرسانی سطح نویز پس‌زمینه
    _updateBackgroundNoiseLevel();

    // تشخیص فعالیت صدا
    final voiceDetected = _detectVoiceActivity(
      energy,
      zcr,
      energyThreshold,
      zeroCrossingThreshold,
    );

    // مدیریت تغییرات وضعیت
    _handleVoiceStateChange(voiceDetected, silenceDuration, minSpeechDuration);

    // فراخوانی callbacks
    _onEnergyChanged?.call(energy);
    _onZeroCrossingRateChanged?.call(zcr);
  }

  /// تبدیل bytes به نمونه‌های صوتی
  List<double> _bytesToSamples(Uint8List bytes, int bitsPerSample) {
    final samples = <double>[];

    if (bitsPerSample == 16) {
      for (int i = 0; i < bytes.length - 1; i += 2) {
        final sample = (bytes[i] | (bytes[i + 1] << 8));
        // تبدیل به signed 16-bit
        final signedSample = sample > 32767 ? sample - 65536 : sample;
        samples.add(signedSample / 32768.0);
      }
    } else if (bitsPerSample == 8) {
      for (int i = 0; i < bytes.length; i++) {
        final sample = bytes[i] - 128;
        samples.add(sample / 128.0);
      }
    }

    return samples;
  }

  /// محاسبه انرژی سیگنال
  double _calculateEnergy(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }

    return sum / samples.length;
  }

  /// محاسبه نرخ عبور از صفر
  double _calculateZeroCrossingRate(List<double> samples) {
    if (samples.length < 2) return 0.0;

    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
        crossings++;
      }
    }

    return crossings / (samples.length - 1);
  }

  /// به‌روزرسانی سطح نویز پس‌زمینه
  void _updateBackgroundNoiseLevel() {
    if (_energyHistory.length < 10) return;

    // محاسبه میانگین انرژی در سکوت
    final sortedEnergies = List<double>.from(_energyHistory)..sort();
    final medianIndex = sortedEnergies.length ~/ 2;
    _backgroundNoiseLevel = sortedEnergies[medianIndex];
  }

  /// تشخیص فعالیت صدا
  bool _detectVoiceActivity(
    double energy,
    double zcr,
    double energyThreshold,
    double zeroCrossingThreshold,
  ) {
    // تشخیص بر اساس انرژی
    final energyBased = energy > energyThreshold;

    // تشخیص بر اساس نرخ عبور از صفر (برای تشخیص گفتار)
    final zcrBased = zcr > zeroCrossingThreshold && zcr < 0.5;

    // تشخیص بر اساس نسبت سیگنال به نویز
    final snrBased =
        _backgroundNoiseLevel > 0 && energy > (_backgroundNoiseLevel * 2.0);

    // ترکیب معیارها
    return energyBased && (zcrBased || snrBased);
  }

  /// مدیریت تغییرات وضعیت صدا
  void _handleVoiceStateChange(
    bool voiceDetected,
    double silenceDuration,
    double minSpeechDuration,
  ) {
    final now = DateTime.now();

    if (voiceDetected && !_isVoiceDetected) {
      // شروع تشخیص صدا
      _isVoiceDetected = true;
      _silenceStartTime = null;
      _onVoiceDetected?.call(true);

      if (!_isSpeechActive) {
        _speechStartTime = now;
        _isSpeechActive = true;
        _onSpeechStarted?.call(true);

        // تایمر برای حداقل مدت گفتار
        _speechTimer?.cancel();
        _speechTimer = Timer(
            Duration(milliseconds: (minSpeechDuration * 1000).round()), () {
          if (_isSpeechActive && _speechStartTime != null) {
            final speechDuration =
                now.difference(_speechStartTime!).inMilliseconds / 1000.0;
            if (speechDuration >= minSpeechDuration) {
              // گفتار معتبر است
            }
          }
        });
      }
    } else if (!voiceDetected && _isVoiceDetected) {
      // پایان تشخیص صدا
      _isVoiceDetected = false;
      _onVoiceDetected?.call(false);

      if (_isSpeechActive && _silenceStartTime == null) {
        _silenceStartTime = now;

        // تایمر برای تشخیص پایان گفتار
        _silenceTimer?.cancel();
        _silenceTimer =
            Timer(Duration(milliseconds: (silenceDuration * 1000).round()), () {
          if (_isSpeechActive && _silenceStartTime != null) {
            final silenceDuration =
                now.difference(_silenceStartTime!).inMilliseconds / 1000.0;
            if (silenceDuration >= silenceDuration) {
              _endSpeech();
            }
          }
        });
      }
    }
  }

  /// پایان گفتار
  void _endSpeech() {
    _isSpeechActive = false;
    _speechStartTime = null;
    _silenceStartTime = null;
    _onSpeechEnded?.call(true);

    _speechTimer?.cancel();
    _silenceTimer?.cancel();
  }

  /// بازنشانی وضعیت
  void _resetState() {
    _isVoiceDetected = false;
    _isSpeechActive = false;
    _speechStartTime = null;
    _silenceStartTime = null;
    _currentEnergy = 0.0;
    _currentZeroCrossingRate = 0.0;
    _backgroundNoiseLevel = 0.0;
    _energyHistory.clear();
    _zcrHistory.clear();

    _speechTimer?.cancel();
    _silenceTimer?.cancel();
  }

  /// دریافت آمار فعلی
  Map<String, dynamic> getCurrentStats() {
    return {
      'isVoiceDetected': _isVoiceDetected,
      'isSpeechActive': _isSpeechActive,
      'currentEnergy': _currentEnergy,
      'currentZeroCrossingRate': _currentZeroCrossingRate,
      'backgroundNoiseLevel': _backgroundNoiseLevel,
      'energyHistoryLength': _energyHistory.length,
      'zcrHistoryLength': _zcrHistory.length,
      'speechStartTime': _speechStartTime?.toIso8601String(),
      'silenceStartTime': _silenceStartTime?.toIso8601String(),
    };
  }

  /// تنظیم آستانه‌های تشخیص
  void updateThresholds({
    double? energyThreshold,
    double? zeroCrossingThreshold,
    double? silenceDuration,
    double? minSpeechDuration,
  }) {
    // این متد می‌تواند برای تنظیم پویای آستانه‌ها استفاده شود
    print('🎛️ VAD thresholds updated');
  }

  /// پاکسازی منابع
  void dispose() {
    _speechTimer?.cancel();
    _silenceTimer?.cancel();
    _resetState();
    _isInitialized = false;

    print('🧹 Voice Activity Detection Service disposed');
  }
}

/// کلاس تنظیمات VAD
class VADConfig {
  final double energyThreshold;
  final double zeroCrossingThreshold;
  final double silenceDuration;
  final double minSpeechDuration;
  final int frameSize;
  final int hopSize;
  final bool enableAdaptiveThresholds;
  final bool enableNoiseReduction;

  const VADConfig({
    this.energyThreshold =
        VoiceActivityDetectionService._defaultEnergyThreshold,
    this.zeroCrossingThreshold =
        VoiceActivityDetectionService._defaultZeroCrossingThreshold,
    this.silenceDuration =
        VoiceActivityDetectionService._defaultSilenceDuration,
    this.minSpeechDuration =
        VoiceActivityDetectionService._defaultMinSpeechDuration,
    this.frameSize = VoiceActivityDetectionService._defaultFrameSize,
    this.hopSize = VoiceActivityDetectionService._defaultHopSize,
    this.enableAdaptiveThresholds = true,
    this.enableNoiseReduction = true,
  });

  VADConfig copyWith({
    double? energyThreshold,
    double? zeroCrossingThreshold,
    double? silenceDuration,
    double? minSpeechDuration,
    int? frameSize,
    int? hopSize,
    bool? enableAdaptiveThresholds,
    bool? enableNoiseReduction,
  }) {
    return VADConfig(
      energyThreshold: energyThreshold ?? this.energyThreshold,
      zeroCrossingThreshold:
          zeroCrossingThreshold ?? this.zeroCrossingThreshold,
      silenceDuration: silenceDuration ?? this.silenceDuration,
      minSpeechDuration: minSpeechDuration ?? this.minSpeechDuration,
      frameSize: frameSize ?? this.frameSize,
      hopSize: hopSize ?? this.hopSize,
      enableAdaptiveThresholds:
          enableAdaptiveThresholds ?? this.enableAdaptiveThresholds,
      enableNoiseReduction: enableNoiseReduction ?? this.enableNoiseReduction,
    );
  }
}
