// lib/view/screen/debug/network_debug_screen.dart
//
// صفحه دیباگ برای مشاهده وضعیت شبکه
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../model/network_state.dart';
import '../../../provider/network_provider.dart';
import '../../../widgets/network_quality_indicator.dart';

class NetworkDebugScreen extends ConsumerWidget {
  const NetworkDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStateAsync = ref.watch(networkStateStreamProvider);
    final stats = ref.watch(networkStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Debug'),
        actions: [
          // نمایش اندیکیتور کیفیت
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: NetworkQualityIndicator(showLabel: true, showLatency: true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(networkActionsProvider).refresh();
            },
            tooltip: 'رفرش',
          ),
        ],
      ),
      body: networkStateAsync.when(
        data: (state) => _buildDebugInfo(context, theme, state, stats, ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('خطا: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(networkStateStreamProvider),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugInfo(
    BuildContext context,
    ThemeData theme,
    NetworkState state,
    Map<String, dynamic> stats,
    WidgetRef ref,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Overview
        _buildStatusCard(theme, state),
        const SizedBox(height: 16),

        // Connection Details
        _buildCard(
          theme,
          'Connection Details',
          Icons.wifi_rounded,
          [
            _buildRow('Connected', state.isConnected ? '✅ Yes' : '❌ No'),
            _buildRow('Type', state.connectionTypeText),
            _buildRow('Quality', state.qualityText),
            _buildRow('Is WiFi', state.isWifi ? 'Yes' : 'No'),
            _buildRow('Is Cellular', state.isCellular ? 'Yes' : 'No'),
          ],
        ),
        const SizedBox(height: 16),

        // Performance Metrics
        _buildCard(
          theme,
          'Performance',
          Icons.speed_rounded,
          [
            _buildRow('Latency', '${state.latencyMs ?? "N/A"} ms'),
            _buildRow(
              'Download Speed',
              state.downloadSpeedMbps?.toStringAsFixed(2) ?? 'N/A',
            ),
            _buildRow('Last Checked', _formatDateTime(state.lastChecked)),
          ],
        ),
        const SizedBox(height: 16),

        // Statistics
        _buildCard(
          theme,
          'Statistics',
          Icons.analytics_rounded,
          [
            _buildRow(
              'Consecutive Failures',
              stats['consecutiveFailures'].toString(),
            ),
            _buildRow(
              'Last Disconnect',
              stats['lastDisconnect']?.toString() ?? 'Never',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Capabilities
        _buildCard(
          theme,
          'Capabilities',
          Icons.check_circle_outline_rounded,
          [
            _buildRow(
              'Can Send Message',
              state.canSendMessage ? '✅ Yes' : '❌ No',
            ),
            _buildRow(
              'Can Download Media',
              state.canDownloadMedia ? '✅ Yes' : '❌ No',
            ),
            _buildRow(
              'Should Compress Media',
              state.shouldCompressMedia ? '⚠️ Yes' : '✅ No',
            ),
            _buildRow(
              'Has Good Quality',
              state.hasGoodQuality ? '✅ Yes' : '❌ No',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Actions
        _buildActionsCard(theme, ref),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme, NetworkState state) {
    final color = _getStatusColor(state);
    final icon = _getStatusIcon(state);
    final status = _getStatusText(state);

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
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

  Widget _buildCard(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_rounded, size: 20, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh State'),
                  onPressed: () {
                    ref.read(networkActionsProvider).refresh();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Print Stats'),
                  onPressed: () {
                    final stats = ref.read(networkActionsProvider).getStats();
                    debugPrint('Network Stats: $stats');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(NetworkState state) {
    if (!state.isConnected) return Colors.red;

    switch (state.quality) {
      case NetworkQuality.excellent:
        return Colors.green;
      case NetworkQuality.good:
        return Colors.lightGreen;
      case NetworkQuality.fair:
        return Colors.orange;
      case NetworkQuality.poor:
        return Colors.red;
      case NetworkQuality.none:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(NetworkState state) {
    if (!state.isConnected) return Icons.cloud_off_rounded;

    switch (state.quality) {
      case NetworkQuality.excellent:
        return Icons.signal_cellular_4_bar_rounded;
      case NetworkQuality.good:
        return Icons.signal_cellular_alt_rounded;
      case NetworkQuality.fair:
        return Icons.signal_cellular_alt_2_bar_rounded;
      case NetworkQuality.poor:
        return Icons.signal_cellular_alt_1_bar_rounded;
      case NetworkQuality.none:
        return Icons.signal_cellular_off_rounded;
    }
  }

  String _getStatusText(NetworkState state) {
    if (!state.isConnected) return 'Offline';

    switch (state.quality) {
      case NetworkQuality.excellent:
        return 'Excellent Connection';
      case NetworkQuality.good:
        return 'Good Connection';
      case NetworkQuality.fair:
        return 'Fair Connection';
      case NetworkQuality.poor:
        return 'Poor Connection';
      case NetworkQuality.none:
        return 'No Connection';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}

