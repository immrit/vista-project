import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../provider/provider.dart';

import '../widgets/SettingsListItem.dart';

class VideoPlaybackSettingsPage extends ConsumerWidget {
  const VideoPlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoPlay = ref.watch(autoPlayProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات پخش ویدیو'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // بخش تنظیمات پخش خودکار
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.save_alt,
                  iconColor: Colors.orange,
                  title: 'حالت ذخیره داده',
                  subtitle: 'پخش ویدیو با کیفیت پایین برای صرفه‌جویی در داده',
                  trailing: Switch(
                    value: ref.watch(dataSaverProvider),
                    onChanged: (value) {
                      ref.read(dataSaverProvider.notifier).set(value);
                    },
                  ),
                ),
                _buildDivider(),
                SettingsListItem(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.blue,
                  title: 'تنظیم خودکار کیفیت',
                  subtitle: 'تنظیم خودکار کیفیت بر اساس سرعت اینترنت',
                  trailing: Switch(
                    value: ref.watch(autoQualityProvider),
                    onChanged: (value) {
                      ref.read(autoQualityProvider.notifier).set(value);
                    },
                  ),
                ),
                _buildDivider(),
                SettingsListItem(
                  icon: Icons.play_circle_filled,
                  iconColor: Colors.green,
                  title: 'پخش خودکار ویدیو',
                  subtitle: 'ویدیوها به محض باز شدن پخش شوند',
                  trailing: Switch(
                    value: autoPlay,
                    onChanged: (val) {
                      ref.read(autoPlayProvider.notifier).set(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(left: 68.0),
          height: 0.5,
          color: isDark ? Colors.grey[300] : Colors.grey[200],
        );
      },
    );
  }
}
