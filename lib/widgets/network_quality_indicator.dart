// lib/widgets/network_quality_indicator.dart
//
// اندیکیتور کوچک برای نمایش کیفیت شبکه
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/network_state.dart';
import '../provider/network_provider.dart';

/// اندیکیتور کیفیت شبکه
/// 
/// نمایش میله‌های سیگنال + متن (اختیاری)
/// 
/// استفاده:
/// ```dart
/// AppBar(
///   actions: [
///     NetworkQualityIndicator(showLabel: true),
///   ],
/// )
/// ```
class NetworkQualityIndicator extends ConsumerWidget {
  /// نمایش متن کیفیت
  final bool showLabel;
  
  /// نمایش latency
  final bool showLatency;
  
  /// سایز (small, medium, large)
  final NetworkIndicatorSize size;

  const NetworkQualityIndicator({
    super.key,
    this.showLabel = false,
    this.showLatency = false,
    this.size = NetworkIndicatorSize.medium,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentNetworkStateProvider);

    if (!state.isConnected) {
      return _buildOfflineIndicator(context);
    }

    return _buildQualityIndicator(context, state.quality, state.latencyMs);
  }

  Widget _buildOfflineIndicator(BuildContext context) {
    final iconSize = _getIconSize();
    final fontSize = _getFontSize();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: iconSize,
          color: Colors.red.shade400,
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            'آفلاین',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.red.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQualityIndicator(
    BuildContext context,
    NetworkQuality quality,
    int? latencyMs,
  ) {
    final (color, bars, label) = _getQualityInfo(quality);
    final fontSize = _getFontSize();

    if (quality == NetworkQuality.none) {
      return _buildOfflineIndicator(context);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignalBarsWidget(
          bars: bars,
          color: color,
          size: size,
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (showLatency && latencyMs != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${latencyMs}ms',
              style: TextStyle(
                fontSize: fontSize - 1,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  (Color, int, String) _getQualityInfo(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return (Colors.green, 4, 'عالی');
      case NetworkQuality.good:
        return (Colors.lightGreen.shade600, 3, 'خوب');
      case NetworkQuality.fair:
        return (Colors.orange, 2, 'متوسط');
      case NetworkQuality.poor:
        return (Colors.red, 1, 'ضعیف');
      case NetworkQuality.none:
        return (Colors.grey, 0, 'قطع');
    }
  }

  double _getIconSize() {
    switch (size) {
      case NetworkIndicatorSize.small:
        return 14;
      case NetworkIndicatorSize.medium:
        return 16;
      case NetworkIndicatorSize.large:
        return 20;
    }
  }

  double _getFontSize() {
    switch (size) {
      case NetworkIndicatorSize.small:
        return 10;
      case NetworkIndicatorSize.medium:
        return 11;
      case NetworkIndicatorSize.large:
        return 13;
    }
  }
}

/// سایز اندیکیتور
enum NetworkIndicatorSize {
  small,
  medium,
  large,
}

/// Widget برای نمایش میله‌های سیگنال
class SignalBarsWidget extends StatelessWidget {
  final int bars;
  final Color color;
  final NetworkIndicatorSize size;

  const SignalBarsWidget({
    super.key,
    required this.bars,
    required this.color,
    this.size = NetworkIndicatorSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions();

    return SizedBox(
      width: dimensions.width,
      height: dimensions.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final isActive = index < bars;
          final barHeight = dimensions.baseHeight + (index * dimensions.increment);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: dimensions.barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: isActive ? color : color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(dimensions.borderRadius),
            ),
          );
        }),
      ),
    );
  }

  _SignalDimensions _getDimensions() {
    switch (size) {
      case NetworkIndicatorSize.small:
        return const _SignalDimensions(
          width: 12,
          height: 10,
          baseHeight: 2.5,
          increment: 2.0,
          barWidth: 2.0,
          borderRadius: 0.5,
        );
      case NetworkIndicatorSize.medium:
        return const _SignalDimensions(
          width: 16,
          height: 12,
          baseHeight: 3.0,
          increment: 2.5,
          barWidth: 2.5,
          borderRadius: 1.0,
        );
      case NetworkIndicatorSize.large:
        return const _SignalDimensions(
          width: 20,
          height: 16,
          baseHeight: 4.0,
          increment: 3.0,
          barWidth: 3.5,
          borderRadius: 1.5,
        );
    }
  }
}

class _SignalDimensions {
  final double width;
  final double height;
  final double baseHeight;
  final double increment;
  final double barWidth;
  final double borderRadius;

  const _SignalDimensions({
    required this.width,
    required this.height,
    required this.baseHeight,
    required this.increment,
    required this.barWidth,
    required this.borderRadius,
  });
}

/// نمایش وضعیت کامل شبکه با جزئیات بیشتر
class NetworkStatusChip extends ConsumerWidget {
  const NetworkStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentNetworkStateProvider);

    final (backgroundColor, textColor, icon, text) = _getChipInfo(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (state.isConnected && state.latencyMs != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 12,
              color: textColor.withOpacity(0.3),
            ),
            const SizedBox(width: 6),
            Text(
              '${state.latencyMs}ms',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, IconData, String) _getChipInfo(NetworkState state) {
    if (!state.isConnected) {
      return (
        Colors.red.shade50,
        Colors.red.shade700,
        Icons.cloud_off_rounded,
        'آفلاین',
      );
    }

    switch (state.quality) {
      case NetworkQuality.excellent:
        return (
          Colors.green.shade50,
          Colors.green.shade700,
          Icons.signal_cellular_4_bar_rounded,
          'عالی',
        );
      case NetworkQuality.good:
        return (
          Colors.lightGreen.shade50,
          Colors.lightGreen.shade700,
          Icons.signal_cellular_alt_rounded,
          'خوب',
        );
      case NetworkQuality.fair:
        return (
          Colors.orange.shade50,
          Colors.orange.shade700,
          Icons.signal_cellular_alt_2_bar_rounded,
          'متوسط',
        );
      case NetworkQuality.poor:
        return (
          Colors.red.shade50,
          Colors.red.shade700,
          Icons.signal_cellular_alt_1_bar_rounded,
          'ضعیف',
        );
      case NetworkQuality.none:
        return (
          Colors.grey.shade100,
          Colors.grey.shade700,
          Icons.signal_cellular_off_rounded,
          'قطع',
        );
    }
  }
}

