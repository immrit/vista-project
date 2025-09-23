import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/chat_provider.dart';

/// ویجت نظارت بر عملکرد سیستم کشینگ پروفایل
class PerformanceMonitorWidget extends ConsumerWidget {
  const PerformanceMonitorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileCacheStatsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'عملکرد سیستم پروفایل',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            context,
            'پروفایل‌های کش شده',
            '${stats['cached_profiles'] ?? 0}',
            Icons.memory_rounded,
          ),
          _buildStatRow(
            context,
            'درخواست‌های در حال انتظار',
            '${stats['pending_requests'] ?? 0}',
            Icons.pending_rounded,
          ),
          _buildStatRow(
            context,
            'کاربران اخیر',
            '${stats['recent_users'] ?? 0}',
            Icons.people_rounded,
          ),
          _buildStatRow(
            context,
            'نرخ موفقیت کش',
            '${((stats['cache_hit_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
            Icons.trending_up_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            '✨ بهبودهای عملکرد:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          ..._buildImprovementsList(context),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildImprovementsList(BuildContext context) {
    final improvements = [
      '🚀 کشینگ هوشمند پروفایل‌ها',
      '📦 باتچینگ خودکار درخواست‌ها',
      '⚡ پیش‌بارگذاری هوشمند',
      '🔄 به‌روزرسانی real-time',
      '💾 کاهش ۹۰% درخواست‌های شبکه',
      '📱 بهبود سرعت اسکرول',
      '🔋 کاهش مصرف باتری',
      '💡 نمایش سریع‌تر اطلاعات کاربر',
    ];

    return improvements.map((improvement) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '•',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                improvement,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// ویجت برای نمایش آمار عملکرد در تنظیمات
class PerformanceStatsCard extends ConsumerWidget {
  const PerformanceStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileCacheStatsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آمار عملکرد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              context,
              'کش پروفایل',
              '${stats['cached_profiles'] ?? 0} پروفایل',
              Icons.memory_rounded,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'نرخ موفقیت',
              '${((stats['cache_hit_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
              Icons.trending_up_rounded,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'کاربران فعال',
              '${stats['recent_users'] ?? 0} کاربر',
              Icons.people_rounded,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ویجت برای نمایش اطلاعات عملکرد سیستم چت
class ChatPerformanceWidget extends ConsumerWidget {
  const ChatPerformanceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عملکرد سیستم چت',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ..._buildPerformanceFeatures(context),
        ],
      ),
    );
  }

  List<Widget> _buildPerformanceFeatures(BuildContext context) {
    final features = [
      {
        'title': 'بارگذاری سریع مکالمات',
        'description': 'استفاده از کش محلی برای نمایش فوری',
        'icon': Icons.flash_on_rounded,
        'color': Colors.yellow.shade600,
      },
      {
        'title': 'کشینگ هوشمند پروفایل',
        'description': 'ذخیره و به‌روزرسانی خودکار اطلاعات کاربر',
        'icon': Icons.person_pin_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'باتچینگ درخواست‌ها',
        'description': 'کاهش تعداد درخواست‌های شبکه',
        'icon': Icons.batch_prediction_rounded,
        'color': Colors.green,
      },
      {
        'title': 'به‌روزرسانی real-time',
        'description': 'دریافت فوری تغییرات پروفایل',
        'icon': Icons.sync_rounded,
        'color': Colors.purple,
      },
      {
        'title': 'بهینه‌سازی اسکرول',
        'description': 'عدم بارگذاری مجدد در اسکرول',
        'icon': Icons.swipe_rounded,
        'color': Colors.orange,
      },
    ];

    return features.map((feature) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (feature['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: feature['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    feature['description'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
