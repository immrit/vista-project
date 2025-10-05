import 'package:flutter/material.dart';
import '../../services/advanced_audio_enhancement_service.dart' as enhancement;
import '../../services/voice_activity_detection_service.dart';
import '../../services/audio_compression_service.dart' as compression;
import '../../services/advanced_haptic_feedback_service.dart';

/// دیالوگ تنظیمات پیشرفته ضبط وویس
class AdvancedVoiceRecordingSettingsDialog extends StatefulWidget {
  final enhancement.AdvancedAudioEnhancementConfig? initialEnhancementConfig;
  final VADConfig? initialVADConfig;
  final compression.AudioCompressionConfig? initialCompressionConfig;
  final HapticFeedbackConfig? initialHapticConfig;
  final Function(enhancement.AdvancedAudioEnhancementConfig)?
      onEnhancementConfigChanged;
  final Function(VADConfig)? onVADConfigChanged;
  final Function(compression.AudioCompressionConfig)?
      onCompressionConfigChanged;
  final Function(HapticFeedbackConfig)? onHapticConfigChanged;

  const AdvancedVoiceRecordingSettingsDialog({
    super.key,
    this.initialEnhancementConfig,
    this.initialVADConfig,
    this.initialCompressionConfig,
    this.initialHapticConfig,
    this.onEnhancementConfigChanged,
    this.onVADConfigChanged,
    this.onCompressionConfigChanged,
    this.onHapticConfigChanged,
  });

  @override
  State<AdvancedVoiceRecordingSettingsDialog> createState() =>
      _AdvancedVoiceRecordingSettingsDialogState();
}

class _AdvancedVoiceRecordingSettingsDialogState
    extends State<AdvancedVoiceRecordingSettingsDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Configs
  late enhancement.AdvancedAudioEnhancementConfig _enhancementConfig;
  late VADConfig _vadConfig;
  late compression.AudioCompressionConfig _compressionConfig;
  late HapticFeedbackConfig _hapticConfig;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize configs
    _enhancementConfig = widget.initialEnhancementConfig ??
        const enhancement.AdvancedAudioEnhancementConfig(
          enableNoiseReduction: true,
          enableEchoCancellation: true,
          enableAutoGain: true,
          enableHighPassFilter: true,
          enableLowPassFilter: true,
          enableCompression: true,
          enableNormalization: true,
          targetLoudness: -16.0,
          compressionRatio: 3.0,
          attackTime: 0.003,
          releaseTime: 0.1,
          highPassFrequency: 80.0,
          lowPassFrequency: 8000.0,
          noiseReductionLevel: 0.3,
          echoCancellationLevel: 0.5,
          outputFormat: enhancement.AudioFormat.opus,
          outputBitrate: 128,
          outputSampleRate: 48000,
        );

    _vadConfig = widget.initialVADConfig ?? const VADConfig();
    _compressionConfig = widget.initialCompressionConfig ??
        const compression.AudioCompressionConfig(
          targetFormat: compression.AudioFormat.opus,
          targetBitrate: 64,
          targetSampleRate: 48000,
          enableAdaptiveBitrate: true,
          enableQualityOptimization: true,
          enableSizeOptimization: true,
          maxFileSizeKB: 1000,
          qualityLevel: compression.AudioQualityLevel.high,
          compressionLevel: compression.CompressionLevel.medium,
        );

    _hapticConfig = widget.initialHapticConfig ??
        const HapticFeedbackConfig(
          enableHapticFeedback: true,
          enableSoundFeedback: true,
          enableVisualFeedback: true,
          hapticIntensity: HapticIntensity.medium,
          soundVolume: 0.7,
          visualIntensity: VisualIntensity.medium,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_voice,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تنظیمات پیشرفته ضبط وویس',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.audio_file),
                    text: 'بهبود صدا',
                  ),
                  Tab(
                    icon: Icon(Icons.mic),
                    text: 'تشخیص صدا',
                  ),
                  Tab(
                    icon: Icon(Icons.compress),
                    text: 'فشرده‌سازی',
                  ),
                  Tab(
                    icon: Icon(Icons.vibration),
                    text: 'بازخورد',
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEnhancementSettings(),
                  _buildVADSettings(),
                  _buildCompressionSettings(),
                  _buildHapticSettings(),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetToDefaults,
                      child: const Text('بازنشانی'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('ذخیره'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancementSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('تنظیمات بهبود کیفیت صدا'),
          const SizedBox(height: 16),

          // Noise reduction
          _buildSwitchTile(
            title: 'کاهش نویز',
            subtitle: 'حذف نویز پس‌زمینه',
            value: _enhancementConfig.enableNoiseReduction,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableNoiseReduction: value,
                );
              });
            },
          ),

          // Echo cancellation
          _buildSwitchTile(
            title: 'حذف اکو',
            subtitle: 'حذف صدای اکو',
            value: _enhancementConfig.enableEchoCancellation,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableEchoCancellation: value,
                );
              });
            },
          ),

          // Auto gain
          _buildSwitchTile(
            title: 'تنظیم خودکار حجم',
            subtitle: 'نرمال‌سازی حجم صدا',
            value: _enhancementConfig.enableAutoGain,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableAutoGain: value,
                );
              });
            },
          ),

          // High pass filter
          _buildSwitchTile(
            title: 'فیلتر فرکانس پایین',
            subtitle: 'حذف فرکانس‌های پایین',
            value: _enhancementConfig.enableHighPassFilter,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableHighPassFilter: value,
                );
              });
            },
          ),

          // Low pass filter
          _buildSwitchTile(
            title: 'فیلتر فرکانس بالا',
            subtitle: 'حذف فرکانس‌های بالا',
            value: _enhancementConfig.enableLowPassFilter,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableLowPassFilter: value,
                );
              });
            },
          ),

          // Compression
          _buildSwitchTile(
            title: 'فشرده‌سازی دینامیک',
            subtitle: 'کنترل دامنه صدا',
            value: _enhancementConfig.enableCompression,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableCompression: value,
                );
              });
            },
          ),

          // Normalization
          _buildSwitchTile(
            title: 'نرمال‌سازی',
            subtitle: 'یکسان‌سازی حجم صدا',
            value: _enhancementConfig.enableNormalization,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  enableNormalization: value,
                );
              });
            },
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('تنظیمات پیشرفته'),

          // Target loudness
          _buildSliderTile(
            title: 'حجم هدف (LUFS)',
            subtitle: 'حجم مطلوب صدا',
            value: _enhancementConfig.targetLoudness,
            min: -30.0,
            max: -10.0,
            divisions: 20,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  targetLoudness: value,
                );
              });
            },
          ),

          // Compression ratio
          _buildSliderTile(
            title: 'نسبت فشرده‌سازی',
            subtitle: 'شدت فشرده‌سازی',
            value: _enhancementConfig.compressionRatio,
            min: 1.0,
            max: 10.0,
            divisions: 18,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  compressionRatio: value,
                );
              });
            },
          ),

          // Noise reduction level
          _buildSliderTile(
            title: 'سطح کاهش نویز',
            subtitle: 'شدت کاهش نویز',
            value: _enhancementConfig.noiseReductionLevel,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  noiseReductionLevel: value,
                );
              });
            },
          ),

          // Echo cancellation level
          _buildSliderTile(
            title: 'سطح حذف اکو',
            subtitle: 'شدت حذف اکو',
            value: _enhancementConfig.echoCancellationLevel,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                _enhancementConfig = _enhancementConfig.copyWith(
                  echoCancellationLevel: value,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVADSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('تنظیمات تشخیص فعالیت صدا'),
          const SizedBox(height: 16),

          // Energy threshold
          _buildSliderTile(
            title: 'آستانه انرژی',
            subtitle: 'حداقل انرژی برای تشخیص صدا',
            value: _vadConfig.energyThreshold,
            min: 0.001,
            max: 0.1,
            divisions: 99,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  energyThreshold: value,
                );
              });
            },
          ),

          // Zero crossing threshold
          _buildSliderTile(
            title: 'آستانه عبور از صفر',
            subtitle: 'حداقل نرخ عبور از صفر',
            value: _vadConfig.zeroCrossingThreshold,
            min: 0.01,
            max: 0.5,
            divisions: 49,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  zeroCrossingThreshold: value,
                );
              });
            },
          ),

          // Silence duration
          _buildSliderTile(
            title: 'مدت سکوت (ثانیه)',
            subtitle: 'مدت سکوت برای پایان گفتار',
            value: _vadConfig.silenceDuration,
            min: 0.5,
            max: 5.0,
            divisions: 45,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  silenceDuration: value,
                );
              });
            },
          ),

          // Min speech duration
          _buildSliderTile(
            title: 'حداقل مدت گفتار (ثانیه)',
            subtitle: 'حداقل مدت برای تشخیص گفتار',
            value: _vadConfig.minSpeechDuration,
            min: 0.1,
            max: 2.0,
            divisions: 19,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  minSpeechDuration: value,
                );
              });
            },
          ),

          // Adaptive thresholds
          _buildSwitchTile(
            title: 'آستانه‌های تطبیقی',
            subtitle: 'تنظیم خودکار آستانه‌ها',
            value: _vadConfig.enableAdaptiveThresholds,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  enableAdaptiveThresholds: value,
                );
              });
            },
          ),

          // Noise reduction
          _buildSwitchTile(
            title: 'کاهش نویز VAD',
            subtitle: 'کاهش نویز در تشخیص صدا',
            value: _vadConfig.enableNoiseReduction,
            onChanged: (value) {
              setState(() {
                _vadConfig = _vadConfig.copyWith(
                  enableNoiseReduction: value,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompressionSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('تنظیمات فشرده‌سازی'),
          const SizedBox(height: 16),

          // Target format
          _buildDropdownTile(
            title: 'فرمت خروجی',
            subtitle: 'فرمت فایل نهایی',
            value: _compressionConfig.targetFormat,
            items: compression.AudioFormat.values,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  targetFormat: value,
                );
              });
            },
          ),

          // Target bitrate
          _buildSliderTile(
            title: 'بیت‌ریت هدف (kbps)',
            subtitle: 'کیفیت فایل خروجی',
            value: _compressionConfig.targetBitrate.toDouble(),
            min: 32.0,
            max: 256.0,
            divisions: 14,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  targetBitrate: value.round(),
                );
              });
            },
          ),

          // Target sample rate
          _buildDropdownTile(
            title: 'نرخ نمونه‌برداری (Hz)',
            subtitle: 'فرکانس نمونه‌برداری',
            value: _compressionConfig.targetSampleRate,
            items: [44100, 48000, 96000],
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  targetSampleRate: value,
                );
              });
            },
          ),

          // Quality level
          _buildDropdownTile(
            title: 'سطح کیفیت',
            subtitle: 'کیفیت فشرده‌سازی',
            value: _compressionConfig.qualityLevel,
            items: compression.AudioQualityLevel.values,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  qualityLevel: value,
                );
              });
            },
          ),

          // Compression level
          _buildDropdownTile(
            title: 'سطح فشرده‌سازی',
            subtitle: 'شدت فشرده‌سازی',
            value: _compressionConfig.compressionLevel,
            items: compression.CompressionLevel.values,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  compressionLevel: value,
                );
              });
            },
          ),

          // Max file size
          _buildSliderTile(
            title: 'حداکثر حجم فایل (KB)',
            subtitle: 'حداکثر حجم مجاز',
            value: _compressionConfig.maxFileSizeKB.toDouble(),
            min: 100.0,
            max: 5000.0,
            divisions: 49,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  maxFileSizeKB: value.round(),
                );
              });
            },
          ),

          // Adaptive bitrate
          _buildSwitchTile(
            title: 'بیت‌ریت تطبیقی',
            subtitle: 'تنظیم خودکار بیت‌ریت',
            value: _compressionConfig.enableAdaptiveBitrate,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  enableAdaptiveBitrate: value,
                );
              });
            },
          ),

          // Quality optimization
          _buildSwitchTile(
            title: 'بهینه‌سازی کیفیت',
            subtitle: 'بهینه‌سازی کیفیت صدا',
            value: _compressionConfig.enableQualityOptimization,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  enableQualityOptimization: value,
                );
              });
            },
          ),

          // Size optimization
          _buildSwitchTile(
            title: 'بهینه‌سازی حجم',
            subtitle: 'بهینه‌سازی حجم فایل',
            value: _compressionConfig.enableSizeOptimization,
            onChanged: (value) {
              setState(() {
                _compressionConfig = _compressionConfig.copyWith(
                  enableSizeOptimization: value,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHapticSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('تنظیمات بازخورد لمسی'),
          const SizedBox(height: 16),

          // Enable haptic feedback
          _buildSwitchTile(
            title: 'بازخورد لمسی',
            subtitle: 'فعال‌سازی لرزش',
            value: _hapticConfig.enableHapticFeedback,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  enableHapticFeedback: value,
                );
              });
            },
          ),

          // Enable sound feedback
          _buildSwitchTile(
            title: 'بازخورد صوتی',
            subtitle: 'فعال‌سازی صدا',
            value: _hapticConfig.enableSoundFeedback,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  enableSoundFeedback: value,
                );
              });
            },
          ),

          // Enable visual feedback
          _buildSwitchTile(
            title: 'بازخورد بصری',
            subtitle: 'فعال‌سازی انیمیشن',
            value: _hapticConfig.enableVisualFeedback,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  enableVisualFeedback: value,
                );
              });
            },
          ),

          // Haptic intensity
          _buildDropdownTile(
            title: 'شدت لرزش',
            subtitle: 'قدرت بازخورد لمسی',
            value: _hapticConfig.hapticIntensity,
            items: HapticIntensity.values,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  hapticIntensity: value,
                );
              });
            },
          ),

          // Sound volume
          _buildSliderTile(
            title: 'حجم صدا',
            subtitle: 'بلندی صدای بازخورد',
            value: _hapticConfig.soundVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  soundVolume: value,
                );
              });
            },
          ),

          // Visual intensity
          _buildDropdownTile(
            title: 'شدت بصری',
            subtitle: 'قدرت انیمیشن‌ها',
            value: _hapticConfig.visualIntensity,
            items: VisualIntensity.values,
            onChanged: (value) {
              setState(() {
                _hapticConfig = _hapticConfig.copyWith(
                  visualIntensity: value,
                );
              });
            },
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('تست بازخورد'),

          // Test haptic button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testHaptic,
              icon: const Icon(Icons.vibration),
              label: const Text('تست لرزش'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required List<T> items,
    required Function(T) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (T? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(_getDisplayName(item)),
          );
        }).toList(),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getDisplayName(dynamic item) {
    if (item is enhancement.AudioFormat) {
      switch (item) {
        case enhancement.AudioFormat.wav:
          return 'WAV';
        case enhancement.AudioFormat.mp3:
          return 'MP3';
        case enhancement.AudioFormat.opus:
          return 'Opus';
        case enhancement.AudioFormat.aac:
          return 'AAC';
        case enhancement.AudioFormat.m4a:
          return 'M4A';
      }
    } else if (item is compression.AudioFormat) {
      switch (item) {
        case compression.AudioFormat.wav:
          return 'WAV';
        case compression.AudioFormat.mp3:
          return 'MP3';
        case compression.AudioFormat.opus:
          return 'Opus';
        case compression.AudioFormat.aac:
          return 'AAC';
        case compression.AudioFormat.m4a:
          return 'M4A';
      }
    } else if (item is compression.AudioQualityLevel) {
      switch (item) {
        case compression.AudioQualityLevel.veryLow:
          return 'خیلی پایین';
        case compression.AudioQualityLevel.low:
          return 'پایین';
        case compression.AudioQualityLevel.medium:
          return 'متوسط';
        case compression.AudioQualityLevel.high:
          return 'بالا';
        case compression.AudioQualityLevel.lossless:
          return 'بدون فشرده‌سازی';
      }
    } else if (item is compression.CompressionLevel) {
      switch (item) {
        case compression.CompressionLevel.low:
          return 'پایین';
        case compression.CompressionLevel.medium:
          return 'متوسط';
        case compression.CompressionLevel.high:
          return 'بالا';
      }
    } else if (item is HapticIntensity) {
      switch (item) {
        case HapticIntensity.low:
          return 'پایین';
        case HapticIntensity.medium:
          return 'متوسط';
        case HapticIntensity.high:
          return 'بالا';
      }
    } else if (item is VisualIntensity) {
      switch (item) {
        case VisualIntensity.low:
          return 'پایین';
        case VisualIntensity.medium:
          return 'متوسط';
        case VisualIntensity.high:
          return 'بالا';
      }
    } else if (item is int) {
      return item.toString();
    }
    return item.toString();
  }

  void _testHaptic() {
    // تست لرزش بدون اسنک بار
    // TODO: Implement haptic test
  }

  void _resetToDefaults() {
    setState(() {
      _enhancementConfig = const enhancement.AdvancedAudioEnhancementConfig(
        enableNoiseReduction: true,
        enableEchoCancellation: true,
        enableAutoGain: true,
        enableHighPassFilter: true,
        enableLowPassFilter: true,
        enableCompression: true,
        enableNormalization: true,
        targetLoudness: -16.0,
        compressionRatio: 3.0,
        attackTime: 0.003,
        releaseTime: 0.1,
        highPassFrequency: 80.0,
        lowPassFrequency: 8000.0,
        noiseReductionLevel: 0.3,
        echoCancellationLevel: 0.5,
        outputFormat: enhancement.AudioFormat.opus,
        outputBitrate: 128,
        outputSampleRate: 48000,
      );
      _vadConfig = const VADConfig();
      _compressionConfig = const compression.AudioCompressionConfig(
        targetFormat: compression.AudioFormat.opus,
        targetBitrate: 64,
        targetSampleRate: 48000,
        enableAdaptiveBitrate: true,
        enableQualityOptimization: true,
        enableSizeOptimization: true,
        maxFileSizeKB: 1000,
        qualityLevel: compression.AudioQualityLevel.high,
        compressionLevel: compression.CompressionLevel.medium,
      );
      _hapticConfig = const HapticFeedbackConfig(
        enableHapticFeedback: true,
        enableSoundFeedback: true,
        enableVisualFeedback: true,
        hapticIntensity: HapticIntensity.medium,
        soundVolume: 0.7,
        visualIntensity: VisualIntensity.medium,
      );
    });
  }

  void _saveSettings() {
    widget.onEnhancementConfigChanged?.call(_enhancementConfig);
    widget.onVADConfigChanged?.call(_vadConfig);
    widget.onCompressionConfigChanged?.call(_compressionConfig);
    widget.onHapticConfigChanged?.call(_hapticConfig);

    Navigator.of(context).pop();

    // تنظیمات ذخیره شد
  }
}
