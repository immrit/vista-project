import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// سرویس فشرده‌سازی و بهینه‌سازی صدا
class AudioCompressionService {
  // Singleton instance
  static final AudioCompressionService _instance =
      AudioCompressionService._internal();
  factory AudioCompressionService() => _instance;
  AudioCompressionService._internal();

  // تنظیمات پیش‌فرض
  static const AudioCompressionConfig _defaultConfig = AudioCompressionConfig(
    targetFormat: AudioFormat.opus,
    targetBitrate: 64, // kbps - بهینه برای وویس
    targetSampleRate: 48000, // Hz
    enableAdaptiveBitrate: true,
    enableQualityOptimization: true,
    enableSizeOptimization: true,
    maxFileSizeKB: 1000, // 1MB
    qualityLevel: AudioQualityLevel.high,
    compressionLevel: CompressionLevel.medium,
  );

  bool _isInitialized = false;

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    print('🗜️ Audio Compression Service initialized');
  }

  /// فشرده‌سازی فایل صوتی
  Future<File?> compressAudioFile(
    File inputFile, {
    AudioCompressionConfig? config,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final compressionConfig = config ?? _defaultConfig;
      onStatusChanged?.call('شروع فشرده‌سازی...');
      onProgress?.call(0.1);

      // تحلیل فایل ورودی
      final inputAnalysis = await _analyzeInputFile(inputFile);
      onProgress?.call(0.2);

      // تعیین تنظیمات بهینه
      final optimizedConfig = _optimizeConfigForInput(
        compressionConfig,
        inputAnalysis,
      );
      onStatusChanged?.call('تنظیمات بهینه تعیین شد');
      onProgress?.call(0.3);

      // ایجاد فایل خروجی
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'compressed_${path.basenameWithoutExtension(inputFile.path)}.${_getFileExtension(optimizedConfig.targetFormat)}',
      );

      onStatusChanged?.call('در حال فشرده‌سازی...');
      onProgress?.call(0.4);

      // خواندن فایل ورودی
      final inputBytes = await inputFile.readAsBytes();
      onProgress?.call(0.6);

      // اعمال فشرده‌سازی
      final compressedBytes = await _applyCompression(
        inputBytes,
        optimizedConfig,
        inputAnalysis,
        onProgress: (progress) {
          onProgress?.call(0.6 + (progress * 0.3));
        },
        onStatusChanged: onStatusChanged,
      );

      onProgress?.call(0.9);

      // نوشتن فایل خروجی
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes);

      onProgress?.call(1.0);
      onStatusChanged?.call('فشرده‌سازی کامل شد');

      final inputLength = await inputFile.length();
      final outputLength = await outputFile.length();
      final compressionRatio = inputLength / outputLength;
      print(
          '✅ فایل فشرده شد: $inputLength -> $outputLength bytes (نسبت: ${compressionRatio.toStringAsFixed(2)}:1)');

      return outputFile;
    } catch (e) {
      print('❌ خطا در فشرده‌سازی: $e');
      onStatusChanged?.call('خطا در فشرده‌سازی: $e');
      return null;
    }
  }

  /// تحلیل فایل ورودی
  Future<AudioFileAnalysis> _analyzeInputFile(File inputFile) async {
    final fileSize = await inputFile.length();
    final fileName = path.basename(inputFile.path);
    final extension = path.extension(fileName).toLowerCase();

    // تخمین مدت زمان
    final estimatedDuration = _estimateDuration(fileSize, extension);

    // محاسبه بیت‌ریت فعلی
    final currentBitrate =
        _calculateCurrentBitrate(fileSize, estimatedDuration);

    // تعیین کیفیت فعلی
    final currentQuality = _determineCurrentQuality(currentBitrate, extension);

    return AudioFileAnalysis(
      fileSize: fileSize,
      format: extension,
      estimatedDuration: estimatedDuration,
      currentBitrate: currentBitrate,
      currentQuality: currentQuality,
      isCompressed: _isCompressedFormat(extension),
      compressionRatio: _getCurrentCompressionRatio(extension),
    );
  }

  /// تخمین مدت زمان
  double _estimateDuration(int fileSize, String format) {
    switch (format) {
      case '.wav':
        return fileSize / (44100 * 2 * 1); // 44.1kHz, 16-bit, mono
      case '.mp3':
        return fileSize / (128 * 1000 / 8); // 128 kbps
      case '.opus':
        return fileSize / (64 * 1000 / 8); // 64 kbps
      case '.aac':
        return fileSize / (96 * 1000 / 8); // 96 kbps
      case '.m4a':
        return fileSize / (96 * 1000 / 8); // 96 kbps
      default:
        return fileSize / (128 * 1000 / 8); // default
    }
  }

  /// محاسبه بیت‌ریت فعلی
  int _calculateCurrentBitrate(int fileSize, double duration) {
    if (duration == 0) return 0;
    return (fileSize * 8 / duration / 1000).round();
  }

  /// تعیین کیفیت فعلی
  AudioQualityLevel _determineCurrentQuality(int bitrate, String format) {
    if (format == '.wav') return AudioQualityLevel.lossless;

    if (bitrate >= 192) return AudioQualityLevel.high;
    if (bitrate >= 128) return AudioQualityLevel.medium;
    if (bitrate >= 64) return AudioQualityLevel.low;
    return AudioQualityLevel.veryLow;
  }

  /// بررسی فرمت فشرده
  bool _isCompressedFormat(String format) {
    return ['.mp3', '.opus', '.aac', '.m4a'].contains(format);
  }

  /// دریافت نسبت فشرده‌سازی فعلی
  double _getCurrentCompressionRatio(String format) {
    switch (format) {
      case '.wav':
        return 1.0;
      case '.mp3':
        return 11.0;
      case '.opus':
        return 6.0;
      case '.aac':
        return 8.0;
      case '.m4a':
        return 8.0;
      default:
        return 1.0;
    }
  }

  /// بهینه‌سازی تنظیمات برای فایل ورودی
  AudioCompressionConfig _optimizeConfigForInput(
    AudioCompressionConfig config,
    AudioFileAnalysis analysis,
  ) {
    // اگر فایل قبلاً فشرده است و کیفیت خوبی دارد
    if (analysis.isCompressed &&
        analysis.currentQuality.index >= AudioQualityLevel.medium.index &&
        analysis.fileSize <= config.maxFileSizeKB * 1024) {
      // تنظیمات کمتر تهاجمی
      return config.copyWith(
        targetBitrate: (analysis.currentBitrate * 0.8).round(),
        compressionLevel: CompressionLevel.low,
      );
    }

    // اگر فایل بزرگ است
    if (analysis.fileSize > config.maxFileSizeKB * 1024) {
      // فشرده‌سازی تهاجمی‌تر
      return config.copyWith(
        targetBitrate: 32, // kbps
        compressionLevel: CompressionLevel.high,
        qualityLevel: AudioQualityLevel.medium,
      );
    }

    // تنظیمات بهینه برای وویس
    return config.copyWith(
      targetFormat: AudioFormat.opus, // بهترین فرمت برای وویس
      targetBitrate: 64, // kbps - تعادل بین کیفیت و حجم
      targetSampleRate: 48000, // Hz - استاندارد برای وویس
    );
  }

  /// اعمال فشرده‌سازی
  Future<Uint8List> _applyCompression(
    Uint8List inputBytes,
    AudioCompressionConfig config,
    AudioFileAnalysis analysis, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    onStatusChanged?.call('پردازش داده‌های صوتی...');
    onProgress?.call(0.1);

    // شبیه‌سازی فشرده‌سازی
    await Future.delayed(const Duration(milliseconds: 200));

    // محاسبه اندازه خروجی بر اساس بیت‌ریت هدف
    final targetSize = _calculateTargetSize(
      analysis.estimatedDuration,
      config.targetBitrate,
    );

    onStatusChanged?.call('فشرده‌سازی...');
    onProgress?.call(0.5);

    // شبیه‌سازی فشرده‌سازی
    await Future.delayed(const Duration(milliseconds: 300));

    // تولید داده‌های فشرده (در واقعیت از کدک استفاده می‌شود)
    final compressedBytes = _simulateCompression(
      inputBytes,
      targetSize,
      config.compressionLevel,
    );

    onProgress?.call(1.0);

    return compressedBytes;
  }

  /// محاسبه اندازه هدف
  int _calculateTargetSize(double duration, int bitrate) {
    return (duration * bitrate * 1000 / 8).round();
  }

  /// شبیه‌سازی فشرده‌سازی
  Uint8List _simulateCompression(
    Uint8List inputBytes,
    int targetSize,
    CompressionLevel level,
  ) {
    // در واقعیت، اینجا از کدک‌های واقعی استفاده می‌شود
    // مثل Opus، AAC، یا MP3

    final step = (inputBytes.length / targetSize).round();

    final compressedBytes = <int>[];
    for (int i = 0; i < inputBytes.length; i += step) {
      if (compressedBytes.length < targetSize) {
        compressedBytes.add(inputBytes[i]);
      }
    }

    return Uint8List.fromList(compressedBytes);
  }

  /// بهینه‌سازی خودکار
  Future<File?> autoOptimizeAudioFile(
    File inputFile, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    // تحلیل فایل
    final analysis = await _analyzeInputFile(inputFile);

    // تعیین تنظیمات بهینه
    AudioCompressionConfig optimizedConfig;

    if (analysis.fileSize > 2 * 1024 * 1024) {
      // > 2MB
      // فایل بزرگ - فشرده‌سازی تهاجمی
      optimizedConfig = _defaultConfig.copyWith(
        targetBitrate: 32,
        compressionLevel: CompressionLevel.high,
        qualityLevel: AudioQualityLevel.medium,
      );
    } else if (analysis.fileSize > 1024 * 1024) {
      // > 1MB
      // فایل متوسط - فشرده‌سازی متوسط
      optimizedConfig = _defaultConfig.copyWith(
        targetBitrate: 48,
        compressionLevel: CompressionLevel.medium,
        qualityLevel: AudioQualityLevel.medium,
      );
    } else {
      // فایل کوچک - فشرده‌سازی ملایم
      optimizedConfig = _defaultConfig.copyWith(
        targetBitrate: 64,
        compressionLevel: CompressionLevel.low,
        qualityLevel: AudioQualityLevel.high,
      );
    }

    return await compressAudioFile(
      inputFile,
      config: optimizedConfig,
      onProgress: onProgress,
      onStatusChanged: onStatusChanged,
    );
  }

  /// دریافت پسوند فایل
  String _getFileExtension(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return 'wav';
      case AudioFormat.mp3:
        return 'mp3';
      case AudioFormat.opus:
        return 'opus';
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.m4a:
        return 'm4a';
    }
  }

  /// دریافت آمار فشرده‌سازی
  CompressionStats getCompressionStats(File originalFile, File compressedFile) {
    final originalSize = originalFile.lengthSync();
    final compressedSize = compressedFile.lengthSync();
    final compressionRatio = originalSize / compressedSize;
    final spaceSaved = originalSize - compressedSize;
    final spaceSavedPercent = (spaceSaved / originalSize) * 100;

    return CompressionStats(
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionRatio: compressionRatio,
      spaceSaved: spaceSaved,
      spaceSavedPercent: spaceSavedPercent,
    );
  }

  /// پاکسازی منابع
  void dispose() {
    _isInitialized = false;
    print('🧹 Audio Compression Service disposed');
  }
}

/// تنظیمات فشرده‌سازی
class AudioCompressionConfig {
  final AudioFormat targetFormat;
  final int targetBitrate; // kbps
  final int targetSampleRate; // Hz
  final bool enableAdaptiveBitrate;
  final bool enableQualityOptimization;
  final bool enableSizeOptimization;
  final int maxFileSizeKB;
  final AudioQualityLevel qualityLevel;
  final CompressionLevel compressionLevel;

  const AudioCompressionConfig({
    required this.targetFormat,
    required this.targetBitrate,
    required this.targetSampleRate,
    required this.enableAdaptiveBitrate,
    required this.enableQualityOptimization,
    required this.enableSizeOptimization,
    required this.maxFileSizeKB,
    required this.qualityLevel,
    required this.compressionLevel,
  });

  AudioCompressionConfig copyWith({
    AudioFormat? targetFormat,
    int? targetBitrate,
    int? targetSampleRate,
    bool? enableAdaptiveBitrate,
    bool? enableQualityOptimization,
    bool? enableSizeOptimization,
    int? maxFileSizeKB,
    AudioQualityLevel? qualityLevel,
    CompressionLevel? compressionLevel,
  }) {
    return AudioCompressionConfig(
      targetFormat: targetFormat ?? this.targetFormat,
      targetBitrate: targetBitrate ?? this.targetBitrate,
      targetSampleRate: targetSampleRate ?? this.targetSampleRate,
      enableAdaptiveBitrate:
          enableAdaptiveBitrate ?? this.enableAdaptiveBitrate,
      enableQualityOptimization:
          enableQualityOptimization ?? this.enableQualityOptimization,
      enableSizeOptimization:
          enableSizeOptimization ?? this.enableSizeOptimization,
      maxFileSizeKB: maxFileSizeKB ?? this.maxFileSizeKB,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      compressionLevel: compressionLevel ?? this.compressionLevel,
    );
  }
}

/// تحلیل فایل صوتی
class AudioFileAnalysis {
  final int fileSize;
  final String format;
  final double estimatedDuration;
  final int currentBitrate;
  final AudioQualityLevel currentQuality;
  final bool isCompressed;
  final double compressionRatio;

  const AudioFileAnalysis({
    required this.fileSize,
    required this.format,
    required this.estimatedDuration,
    required this.currentBitrate,
    required this.currentQuality,
    required this.isCompressed,
    required this.compressionRatio,
  });
}

/// آمار فشرده‌سازی
class CompressionStats {
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int spaceSaved;
  final double spaceSavedPercent;

  const CompressionStats({
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.spaceSaved,
    required this.spaceSavedPercent,
  });
}

/// فرمت‌های صوتی
enum AudioFormat {
  wav,
  mp3,
  opus,
  aac,
  m4a,
}

/// سطوح کیفیت صدا
enum AudioQualityLevel {
  veryLow,
  low,
  medium,
  high,
  lossless,
}

/// سطوح فشرده‌سازی
enum CompressionLevel {
  low,
  medium,
  high,
}
