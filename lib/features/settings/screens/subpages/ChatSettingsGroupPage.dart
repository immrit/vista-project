import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import 'package:Vista/features/chat/screens/ArchivedConversationsScreen.dart';
import 'package:Vista/provider/provider.dart';
import 'package:Vista/provider/settings_providers.dart'
    show chatBlurBackgroundProvider, advancedAppSettingsProvider;
import 'package:Vista/DB/advanced_settings_service.dart';
import 'package:Vista/services/advanced_haptic_feedback_service.dart';
import '../widgets/SettingsListItem.dart';

class ChatSettingsGroupPage extends ConsumerStatefulWidget {
  const ChatSettingsGroupPage({super.key});

  @override
  ConsumerState<ChatSettingsGroupPage> createState() =>
      _ChatSettingsGroupPageState();
}

class _ChatSettingsGroupPageState extends ConsumerState<ChatSettingsGroupPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('چت و مکالمات'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            // بخش عمومی
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SettingsListItem(
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
                color: isDark ? colorScheme.surface : Colors.white,
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

                      return SettingsListItem(
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
                      final voiceLabel = ref
                          .read(autoDownloadProvider.notifier)
                          .getSettingLabel(settings.voices);

                      return SettingsListItem(
                        icon: Icons.download,
                        iconColor: Colors.indigo,
                        title: 'دانلود خودکار رسانه',
                        subtitle: 'عکس: $photoLabel • وویس: $voiceLabel',
                        onTap: () {
                          _showAutoDownloadDialog(context, ref);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // عنوان بخش ظاهری چت
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ظاهر صفحه چت',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ),

            // تنظیمات ظاهری چت
            _buildChatAppearanceCard(context, isDark, colorScheme),

            const SizedBox(height: 20),

            // تنظیمات اپلیکیشن
            _buildAppSettingsCard(context, isDark, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAppearanceCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final blurEnabled = ref.watch(chatBlurBackgroundProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SettingsListItem(
            icon: Icons.blur_on_rounded,
            iconColor: blurEnabled ? Colors.purple : Colors.grey,
            title: 'پس‌زمینه بلوری چت',
            subtitle: blurEnabled
                ? 'فعال - افکت شیشه‌ای روی والپیپر'
                : 'غیرفعال - نمایش والپیپر شفاف و عادی',
            trailing: Switch(
              value: blurEnabled,
              onChanged: (value) async {
                await ref
                    .read(chatBlurBackgroundProvider.notifier)
                    .setBlurEnabled(value);
                // نمایش پیام تأیید
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? 'افکت بلور پس‌زمینه فعال شد'
                            : 'افکت بلور پس‌زمینه غیرفعال شد',
                        textDirection: TextDirection.rtl,
                      ),
                      duration: const Duration(
                          seconds: 1), // کاهش زمان نمایش برای حس سریع‌تر
                      backgroundColor: value ? Colors.purple : Colors.grey[700],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final appSettingsAsync = ref.watch(advancedAppSettingsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          appSettingsAsync.when(
            data: (settings) {
              final feedback =
                  settings['feedback'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  SettingsListItem(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.blue,
                    title: 'صداهای سیستم',
                    subtitle: 'فعال/غیرفعال کردن صداها',
                    trailing: Switch(
                      value: feedback['enable_sound_effects'] as bool? ?? true,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'feedback': {
                            ...feedback,
                            'enable_sound_effects': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        // به‌روزرسانی تنظیمات haptic feedback service
                        await AdvancedHapticFeedbackService().loadSettings();
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.vibration_rounded,
                    iconColor: Colors.orange,
                    title: 'بازخورد لمسی',
                    subtitle: 'لرزش هنگام لمس',
                    trailing: Switch(
                      value:
                          feedback['enable_haptic_feedback'] as bool? ?? true,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'feedback': {
                            ...feedback,
                            'enable_haptic_feedback': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        // به‌روزرسانی تنظیمات haptic feedback service
                        await AdvancedHapticFeedbackService().loadSettings();
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('خطا: $error'),
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
          color: isDark ? Colors.grey[700] : Colors.grey[200],
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.grey[600]! : Colors.grey[200]!),
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
                    vertical: math.max(6, fontSize * 0.4)),
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
                    vertical: math.max(6, fontSize * 0.4)),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF383838) : Colors.grey[200],
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
                const Text('وویس‌ها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildAutoDownloadOption(
                    context, ref, 'همیشه', 'always', false, settings.voices),
                _buildAutoDownloadOption(
                    context, ref, 'فقط Wi-Fi', 'wifi', false, settings.voices),
                _buildAutoDownloadOption(
                    context, ref, 'هرگز', 'never', false, settings.voices),
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
              .updateVoiceSetting(value);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'تنظیم دانلود خودکار ${isPhoto ? 'عکس‌ها' : 'وویس‌ها'}: $title')),
          );
        }
      },
    );
  }
}
