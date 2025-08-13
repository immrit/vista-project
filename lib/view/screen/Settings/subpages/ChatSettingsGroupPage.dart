import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../chat/ChatSettingsScreen.dart';
import '../../chat/ArchivedConversationsScreen.dart';
import '../../../../provider/provider.dart';

class ChatSettingsGroupPage extends ConsumerWidget {
  const ChatSettingsGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('چت و مکالمات'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // بخش عمومی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.archive,
                  iconColor: Colors.orange,
                  title: 'مکالمات آرشیو شده',
                  subtitle: 'مشاهده و مدیریت مکالمات آرشیو شده',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ArchivedConversationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش پیام‌ها
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final fontSize = ref.watch(messageFontSizeProvider);
                    final sizeLabel = ref
                        .read(messageFontSizeProvider.notifier)
                        .getFontSizeLabel(fontSize);

                    return TelegramSettingsItem(
                      icon: Icons.text_fields,
                      iconColor: Colors.teal,
                      title: 'اندازه فونت پیام‌ها',
                      subtitle:
                          'فعلی: $sizeLabel (${fontSize.toStringAsFixed(0)}px)',
                      onTap: () {
                        _showFontSizeDialog(context, ref);
                      },
                    );
                  },
                ),
                _buildDivider(),
                Consumer(
                  builder: (context, ref, child) {
                    final settings = ref.watch(autoDownloadProvider);
                    final photoLabel = ref
                        .read(autoDownloadProvider.notifier)
                        .getSettingLabel(settings.photos);
                    final videoLabel = ref
                        .read(autoDownloadProvider.notifier)
                        .getSettingLabel(settings.videos);

                    return TelegramSettingsItem(
                      icon: Icons.download,
                      iconColor: Colors.indigo,
                      title: 'دانلود خودکار رسانه',
                      subtitle: 'عکس: $photoLabel • ویدیو: $videoLabel',
                      onTap: () {
                        _showAutoDownloadDialog(context, ref);
                      },
                    );
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.cleaning_services,
                  iconColor: Colors.pink,
                  title: 'مدیریت ذخیره‌سازی',
                  subtitle: 'پاکسازی حافظه پنهان و مدیریت فضای ذخیره‌سازی',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش تنظیمات پیشرفته
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.backup,
                  iconColor: Colors.deepPurple,
                  title: 'پشتیبان‌گیری چت‌ها',
                  subtitle: 'ایجاد پشتیبان از تمام مکالمات',
                  onTap: () {
                    _showBackupDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.speed,
                  iconColor: Colors.orange,
                  title: 'تنظیمات کارایی',
                  subtitle: 'بهینه‌سازی مصرف باتری و رم',
                  onTap: () {
                    _showPerformanceDialog(context);
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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(left: 68.0),
          height: 0.5,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
        );
      },
    );
  }

  void _showFontSizeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final currentFontSize = ref.watch(messageFontSizeProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('اندازه فونت پیام‌ها'),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // پیش‌نمایش حباب‌های چت
                _buildChatPreview(context, currentFontSize, isDark),
                const SizedBox(height: 24),

                // اسلایدر برای تنظیم اندازه فونت
                Row(
                  children: [
                    const Text('کوچک', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: currentFontSize,
                        min: 10.0,
                        max: 24.0,
                        divisions: 14,
                        onChanged: (value) {
                          ref
                              .read(messageFontSizeProvider.notifier)
                              .setFontSize(value);
                        },
                      ),
                    ),
                    const Text('بزرگ', style: TextStyle(fontSize: 16)),
                  ],
                ),

                // نمایش اندازه دقیق
                Text(
                  'اندازه: ${currentFontSize.toStringAsFixed(0)}px',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      ),
    );
  }

    Widget _buildChatPreview(BuildContext context, double fontSize, bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    
    // محاسبه ارتفاع بر اساس اندازه فونت
    final double containerHeight = math.max(140, fontSize * 8);
    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.6;
    
    return Container(
      height: containerHeight,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // پیام ارسالی (سمت راست)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                padding: EdgeInsets.symmetric(
                  horizontal: math.max(8, fontSize * 0.6), 
                  vertical: math.max(6, fontSize * 0.4)
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: const Radius.circular(4),
                  ),
                ),
                child: Text(
                  'سلام! این پیش‌نمایش فونت است',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    height: 1.3, // بهبود فاصله خطوط
                  ),
                  textDirection: TextDirection.rtl,
                  softWrap: true,
                ),
              ),
            ),
            SizedBox(height: math.max(6, fontSize * 0.3)),
            
            // پیام دریافتی (سمت چپ)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth * 0.9),
                padding: EdgeInsets.symmetric(
                  horizontal: math.max(8, fontSize * 0.6), 
                  vertical: math.max(6, fontSize * 0.4)
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF383838) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: const Radius.circular(4),
                  ),
                ),
                child: Text(
                  'عالی! اندازه مناسبی است',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: fontSize,
                    height: 1.3, // بهبود فاصله خطوط
                  ),
                  textDirection: TextDirection.rtl,
                  softWrap: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoDownloadDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final settings = ref.watch(autoDownloadProvider);

          return AlertDialog(
            title: const Text('دانلود خودکار رسانه'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('عکس‌ها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildAutoDownloadOption(
                    context, ref, 'همیشه', 'always', true, settings.photos),
                _buildAutoDownloadOption(
                    context, ref, 'فقط Wi-Fi', 'wifi', true, settings.photos),
                _buildAutoDownloadOption(
                    context, ref, 'هرگز', 'never', true, settings.photos),
                const SizedBox(height: 16),
                const Text('ویدیوها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildAutoDownloadOption(
                    context, ref, 'همیشه', 'always', false, settings.videos),
                _buildAutoDownloadOption(
                    context, ref, 'فقط Wi-Fi', 'wifi', false, settings.videos),
                _buildAutoDownloadOption(
                    context, ref, 'هرگز', 'never', false, settings.videos),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAutoDownloadOption(BuildContext context, WidgetRef ref,
      String title, String value, bool isPhoto, String currentValue) {
    final isSelected = currentValue == value;

    return ListTile(
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green, size: 20)
          : null,
      onTap: () async {
        if (isPhoto) {
          await ref
              .read(autoDownloadProvider.notifier)
              .updatePhotoSetting(value);
        } else {
          await ref
              .read(autoDownloadProvider.notifier)
              .updateVideoSetting(value);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'تنظیم دانلود خودکار ${isPhoto ? 'عکس‌ها' : 'ویدیوها'}: $title')),
          );
        }
      },
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('پشتیبان‌گیری چت‌ها'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'این قابلیت به شما امکان ایجاد پشتیبان از تمام مکالمات را می‌دهد.'),
            SizedBox(height: 12),
            Text(
              '• پشتیبان‌گیری شامل متن پیام‌ها می‌شود\n'
              '• فایل‌های رسانه‌ای جداگانه ذخیره می‌شوند\n'
              '• امکان بازیابی در آینده وجود دارد',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('قابلیت پشتیبان‌گیری به زودی اضافه خواهد شد')),
              );
            },
            icon: const Icon(Icons.backup),
            label: const Text('شروع پشتیبان‌گیری'),
          ),
        ],
      ),
    );
  }

  void _showPerformanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final settings = ref.watch(performanceProvider);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.speed, color: Colors.orange),
                SizedBox(width: 8),
                Text('تنظیمات کارایی'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('حالت کم‌مصرف'),
                  subtitle: Text(ref.read(performanceProvider.notifier).getBatterySaverDescription()),
                  value: settings.batterySaverMode,
                  onChanged: (value) {
                    ref.read(performanceProvider.notifier).updateBatterySaver(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('کش هوشمند'),
                  subtitle: Text(ref.read(performanceProvider.notifier).getSmartCacheDescription()),
                  value: settings.smartCache,
                  onChanged: (value) {
                    ref.read(performanceProvider.notifier).updateSmartCache(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('پیش‌بارگذاری پیام‌ها'),
                  subtitle: Text(ref.read(performanceProvider.notifier).getPreloadingDescription()),
                  value: settings.messagePreloading,
                  onChanged: (value) {
                    ref.read(performanceProvider.notifier).updateMessagePreloading(value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      ),
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
                    color: Colors.grey[600],
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
