import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../DB/telegram_style_cache_system.dart';

/// ✅ Performance Monitor Widget
/// نمایش آمار عملکرد سیستم cache
class PerformanceMonitor extends ConsumerWidget {
  final bool showDetails;

  const PerformanceMonitor({
    super.key,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheSystem = TelegramStyleCacheSystem();
    final stats = cacheSystem.getPerformanceStats();

    if (!showDetails) {
      // نمایش ساده
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed,
              color: Colors.greenAccent,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${stats['hit_rate']}%',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // نمایش کامل
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Cache Performance',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildStat('L1 Hits (Hot)', stats['l1_hits']),
          _buildStat('L2 Hits (Memory)', stats['l2_hits']),
          _buildStat('L3 Hits (Disk)', stats['l3_hits']),
          _buildStat('Misses', stats['misses']),
          const Divider(color: Colors.white24),
          _buildStat('Hit Rate', '${stats['hit_rate']}%'),
          _buildStat('Hot Cache Size', stats['hot_cache_size']),
          _buildStat('Memory Cache Size', stats['memory_cache_size']),
        ],
      ),
    );
  }

  Widget _buildStat(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}






