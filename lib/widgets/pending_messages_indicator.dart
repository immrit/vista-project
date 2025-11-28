// lib/widgets/pending_messages_indicator.dart
//
// اندیکیتور نمایش پیام‌های در انتظار ارسال
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/retry_queue_item.dart';
import '../provider/retry_queue_provider.dart';

/// اندیکیتور کوچک برای نمایش تعداد پیام‌های pending
/// 
/// استفاده در AppBar یا header:
/// ```dart
/// AppBar(
///   title: Text('چت'),
///   actions: [
///     PendingMessagesIndicator(conversationId: conversationId),
///   ],
/// )
/// ```
class PendingMessagesIndicator extends ConsumerWidget {
  /// شناسه مکالمه (اگه null باشه، کل صف رو نشون میده)
  final String? conversationId;
  
  /// سایز اندیکیتور
  final double size;
  
  /// آیا متن نشون بده؟
  final bool showLabel;

  const PendingMessagesIndicator({
    super.key,
    this.conversationId,
    this.size = 20,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count;
    
    if (conversationId != null) {
      count = ref.watch(conversationPendingCountProvider(conversationId!));
    } else {
      count = ref.watch(pendingCountProvider);
    }

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: count > 9
                ? const Icon(Icons.more_horiz, size: 12, color: Colors.white)
                : Text(
                    count.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            'در انتظار ارسال',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// بنر نمایش پیام‌های در انتظار
/// 
/// نمایش در بالای لیست پیام‌ها
class PendingMessagesBanner extends ConsumerWidget {
  final String conversationId;

  const PendingMessagesBanner({
    super.key,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(conversationRetryItemsProvider(conversationId));
    
    // فیلتر کردن pending و failed
    final pendingItems = items
        .where((item) => 
          item.status == RetryItemStatus.pending ||
          item.status == RetryItemStatus.sending)
        .toList();
    
    final failedItems = items
        .where((item) => item.status == RetryItemStatus.failed)
        .toList();

    if (pendingItems.isEmpty && failedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending items
        if (pendingItems.isNotEmpty)
          _buildBanner(
            context,
            ref,
            icon: Icons.schedule_rounded,
            color: Colors.orange,
            message: '${pendingItems.length} پیام در انتظار ارسال',
            items: pendingItems,
          ),
        
        // Failed items
        if (failedItems.isNotEmpty)
          _buildBanner(
            context,
            ref,
            icon: Icons.error_outline_rounded,
            color: Colors.red,
            message: '${failedItems.length} پیام ارسال نشد',
            items: failedItems,
            showRetryButton: true,
          ),
      ],
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color color,
    required String message,
    required List<RetryQueueItem> items,
    bool showRetryButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showRetryButton)
            TextButton.icon(
              onPressed: () {
                for (final item in items) {
                  ref.read(retryQueueActionsProvider).retryNow(item.id);
                }
              },
              icon: Icon(Icons.refresh_rounded, size: 16, color: color),
              label: Text(
                'تلاش مجدد',
                style: TextStyle(color: color, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

/// لیست کامل پیام‌های pending
/// 
/// برای نمایش در bottom sheet یا صفحه جداگانه
class PendingMessagesList extends ConsumerWidget {
  final String? conversationId;
  final ScrollController? scrollController;

  const PendingMessagesList({
    super.key,
    this.conversationId,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = conversationId != null
        ? ref.watch(conversationRetryItemsProvider(conversationId!))
        : ref.watch(currentRetryQueueProvider);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'همه پیام‌ها ارسال شده',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _PendingMessageCard(item: item);
      },
    );
  }
}

/// کارت نمایش یک آیتم pending
class _PendingMessageCard extends ConsumerWidget {
  final RetryQueueItem item;

  const _PendingMessageCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (statusColor, statusIcon) = _getStatusInfo();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.typeText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                Text(
                  item.statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Content preview
            if (item.type == RetryOperationType.sendMessage)
              Text(
                item.payload['content'] as String? ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 13,
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Footer
            Row(
              children: [
                // Attempt count
                Text(
                  'تلاش ${item.attemptCount}/${item.maxAttempts}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.hintColor,
                  ),
                ),
                
                const Spacer(),
                
                // Actions
                if (item.status == RetryItemStatus.failed) ...[
                  TextButton.icon(
                    onPressed: () {
                      ref.read(retryQueueActionsProvider).retryNow(item.id);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('تلاش مجدد'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    ref.read(retryQueueActionsProvider).cancel(item.id);
                  },
                  tooltip: 'لغو',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            
            // Error message
            if (item.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                item.errorMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, IconData) _getStatusInfo() {
    switch (item.status) {
      case RetryItemStatus.pending:
        return (Colors.orange, Icons.schedule_rounded);
      case RetryItemStatus.sending:
        return (Colors.blue, Icons.upload_rounded);
      case RetryItemStatus.failed:
        return (Colors.red, Icons.error_outline_rounded);
      case RetryItemStatus.completed:
        return (Colors.green, Icons.check_circle_outline_rounded);
      case RetryItemStatus.cancelled:
        return (Colors.grey, Icons.cancel_outlined);
    }
  }
}

/// دکمه floating برای نمایش pending messages
class PendingMessagesFloatingButton extends ConsumerWidget {
  final String? conversationId;
  final VoidCallback onTap;

  const PendingMessagesFloatingButton({
    super.key,
    this.conversationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count;
    final bool hasFailed;
    
    if (conversationId != null) {
      final items = ref.watch(conversationRetryItemsProvider(conversationId!));
      count = items.where((i) => 
        i.status == RetryItemStatus.pending || 
        i.status == RetryItemStatus.sending).length;
      hasFailed = items.any((i) => i.status == RetryItemStatus.failed);
    } else {
      count = ref.watch(pendingCountProvider);
      hasFailed = ref.watch(hasFailedItemsProvider);
    }

    if (count == 0 && !hasFailed) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.small(
      onPressed: onTap,
      backgroundColor: hasFailed ? Colors.red : Colors.orange,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            hasFailed ? Icons.error_outline : Icons.schedule,
            color: Colors.white,
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : count.toString(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: hasFailed ? Colors.red : Colors.orange,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

