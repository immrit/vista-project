import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/VideoPlayerConfig.dart';
import '../../../../provider/provider.dart';

class VideoPlaybackSettingsPage extends ConsumerWidget {
  const VideoPlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoPlay = ref.watch(autoPlayProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات پخش ویدیو'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSwitchItem(
                  icon: Icons.save_alt,
                  iconColor: Colors.orange,
                  title: 'حالت ذخیره داده',
                  subtitle: 'پخش ویدیو با کیفیت پایین برای صرفه‌جویی در داده',
                  value: ref.watch(dataSaverProvider),
                  onChanged: (value) {
                    ref.read(dataSaverProvider.notifier).state = value;
                    VideoPlayerConfig().setDataSaverMode(value);
                  },
                ),
                _buildDivider(),
                TelegramSwitchItem(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.blue,
                  title: 'تنظیم خودکار کیفیت',
                  subtitle: 'تنظیم خودکار کیفیت بر اساس سرعت اینترنت',
                  value: ref.watch(autoQualityProvider),
                  onChanged: (value) {
                    ref.read(autoQualityProvider.notifier).state = value;
                    VideoPlayerConfig().setAutoQuality(value);
                  },
                ),
                _buildDivider(),
                TelegramSwitchItem(
                  icon: Icons.play_circle_filled,
                  iconColor: Colors.green,
                  title: 'پخش خودکار ویدیو',
                  subtitle: 'ویدیوها به محض باز شدن پخش شوند',
                  value: autoPlay,
                  onChanged: (val) {
                    ref.read(autoPlayProvider.notifier).set(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 68.0),
      height: 0.5,
      color: Colors.grey[300],
    );
  }
}

class TelegramSwitchItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const TelegramSwitchItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class TelegramSettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const TelegramSettingsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[500]
                    : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
