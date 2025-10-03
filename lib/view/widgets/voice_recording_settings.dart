import 'package:flutter/material.dart';
import '../../services/audio_enhancement_service.dart';

/// ویجت تنظیمات ضبط وویس
class VoiceRecordingSettings extends StatefulWidget {
  final AudioEnhancementConfig? initialConfig;
  final Function(AudioEnhancementConfig)? onConfigChanged;
  final bool showAdvancedSettings;

  const VoiceRecordingSettings({
    super.key,
    this.initialConfig,
    this.onConfigChanged,
    this.showAdvancedSettings = false,
  });

  @override
  State<VoiceRecordingSettings> createState() => _VoiceRecordingSettingsState();
}

class _VoiceRecordingSettingsState extends State<VoiceRecordingSettings> {
  late AudioEnhancementConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? AudioEnhancementService.defaultConfig;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // عنوان
          Row(
            children: [
              Icon(
                Icons.settings_voice,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تنظیمات ضبط صدا',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // تنظیمات اصلی
          _buildBasicSettings(theme),

          if (widget.showAdvancedSettings) ...[
            const SizedBox(height: 16),
            _buildAdvancedSettings(theme),
          ],

          const SizedBox(height: 16),

          // دکمه‌های عملیات
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildBasicSettings(ThemeData theme) {
    return Column(
      children: [
        // کاهش نویز
        _buildSwitchTile(
          title: 'کاهش نویز',
          subtitle: 'حذف نویزهای پس‌زمینه',
          value: _config.enableNoiseReduction,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: value,
                enableEchoCancellation: _config.enableEchoCancellation,
                enableAutoGain: _config.enableAutoGain,
                enableHighPassFilter: _config.enableHighPassFilter,
                targetLoudness: _config.targetLoudness,
                compressionRatio: _config.compressionRatio,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),

        // حذف اکو
        _buildSwitchTile(
          title: 'حذف اکو',
          subtitle: 'حذف صدای اکو و بازتاب',
          value: _config.enableEchoCancellation,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: _config.enableNoiseReduction,
                enableEchoCancellation: value,
                enableAutoGain: _config.enableAutoGain,
                enableHighPassFilter: _config.enableHighPassFilter,
                targetLoudness: _config.targetLoudness,
                compressionRatio: _config.compressionRatio,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),

        // تنظیم خودکار صدا
        _buildSwitchTile(
          title: 'تنظیم خودکار صدا',
          subtitle: 'تنظیم خودکار حجم صدا',
          value: _config.enableAutoGain,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: _config.enableNoiseReduction,
                enableEchoCancellation: _config.enableEchoCancellation,
                enableAutoGain: value,
                enableHighPassFilter: _config.enableHighPassFilter,
                targetLoudness: _config.targetLoudness,
                compressionRatio: _config.compressionRatio,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تنظیمات پیشرفته',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(height: 12),

        // فیلتر high-pass
        _buildSwitchTile(
          title: 'فیلتر فرکانس پایین',
          subtitle: 'حذف صداهای فرکانس پایین',
          value: _config.enableHighPassFilter,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: _config.enableNoiseReduction,
                enableEchoCancellation: _config.enableEchoCancellation,
                enableAutoGain: _config.enableAutoGain,
                enableHighPassFilter: value,
                targetLoudness: _config.targetLoudness,
                compressionRatio: _config.compressionRatio,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),

        // سطح صدای هدف
        _buildSliderTile(
          title: 'سطح صدای هدف',
          subtitle: '${_config.targetLoudness.toStringAsFixed(1)} LUFS',
          value: _config.targetLoudness,
          min: -30.0,
          max: -10.0,
          divisions: 20,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: _config.enableNoiseReduction,
                enableEchoCancellation: _config.enableEchoCancellation,
                enableAutoGain: _config.enableAutoGain,
                enableHighPassFilter: _config.enableHighPassFilter,
                targetLoudness: value,
                compressionRatio: _config.compressionRatio,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),

        // نسبت فشرده‌سازی
        _buildSliderTile(
          title: 'نسبت فشرده‌سازی',
          subtitle: '${_config.compressionRatio.toStringAsFixed(1)}:1',
          value: _config.compressionRatio,
          min: 1.0,
          max: 10.0,
          divisions: 18,
          onChanged: (value) {
            setState(() {
              _config = AudioEnhancementConfig(
                enableNoiseReduction: _config.enableNoiseReduction,
                enableEchoCancellation: _config.enableEchoCancellation,
                enableAutoGain: _config.enableAutoGain,
                enableHighPassFilter: _config.enableHighPassFilter,
                targetLoudness: _config.targetLoudness,
                compressionRatio: value,
                attackTime: _config.attackTime,
                releaseTime: _config.releaseTime,
              );
            });
            widget.onConfigChanged?.call(_config);
          },
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return SwitchListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
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
    );
  }

  void _resetToDefaults() {
    setState(() {
      _config = AudioEnhancementService.defaultConfig;
    });
    widget.onConfigChanged?.call(_config);
  }

  void _saveSettings() {
    widget.onConfigChanged?.call(_config);
    Navigator.of(context).pop();
  }
}

/// دیالوگ تنظیمات ضبط
class VoiceRecordingSettingsDialog extends StatelessWidget {
  final AudioEnhancementConfig? initialConfig;
  final Function(AudioEnhancementConfig)? onConfigChanged;

  const VoiceRecordingSettingsDialog({
    super.key,
    this.initialConfig,
    this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: VoiceRecordingSettings(
          initialConfig: initialConfig,
          onConfigChanged: onConfigChanged,
          showAdvancedSettings: true,
        ),
      ),
    );
  }
}


