import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/post_upload_provider.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// اوورلی نمایش پیشرفت آپلود پست - مشابه اینستاگرام/X
///
/// این ویجت باید داخل یک Positioned در یک Stack قرار بگیرد.
class UploadProgressOverlay extends ConsumerWidget {
  const UploadProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(postUploadProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: tasks
            .map(
              (task) => _UploadCard(
                key: ValueKey(task.id),
                task: task,
                onDismiss: () =>
                    ref.read(postUploadProvider.notifier).dismissTask(task.id),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final UploadTask task;
  final VoidCallback onDismiss;

  const _UploadCard({super.key, required this.task, required this.onDismiss});

  IconData get _kindIcon {
    switch (task.kind) {
      case 'video':
        return Icons.videocam_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  String get _kindLabel {
    switch (task.kind) {
      case 'video':
        return 'ویدیو';
      case 'music':
        return 'موزیک';
      case 'image':
        return 'تصویر';
      default:
        return 'پست';
    }
  }

  Color _statusColor(bool isSuccess, bool isFailed, BuildContext context) {
    if (isSuccess) return Colors.green.shade400;
    if (isFailed) return Colors.red.shade400;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUploading = task.status == 'uploading';
    final isSuccess = task.status == 'success';
    final isFailed = task.status == 'failed';
    final percentage = (task.progress * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, isSuccess ? 12 : 10),
              child: Row(
                children: [
                  // آیکون / تامبنیل
                  _buildThumbnail(isDark),
                  const SizedBox(width: 12),

                  // وضعیت آپلود
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSuccess
                              ? '$_kindLabel با موفقیت ارسال شد'
                              : isFailed
                                  ? 'ارسال $_kindLabel ناموفق بود'
                                  : 'در حال ارسال $_kindLabel...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: _statusColor(isSuccess, isFailed, context),
                          ),
                        ),
                        if (isUploading) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$percentage٪ آپلود شد',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (isFailed && task.errorMessage != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.errorMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // اندیکاتور وضعیت
                  if (isUploading)
                    _CircularUploadIndicator(progress: task.progress)
                  else if (isSuccess)
                    const _StatusIcon(
                      icon: Icons.check_circle_rounded,
                      color: Colors.green,
                    )
                  else if (isFailed)
                    GestureDetector(
                      onTap: onDismiss,
                      child: const _StatusIcon(
                        icon: Icons.cancel_rounded,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),

            // نوار پیشرفت خطی
            if (isUploading)
              _AnimatedProgressBar(progress: task.progress),
          ],
        ),
      ),
    )
        .animate()
        .slideY(
          begin: -0.6,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 280.ms);
  }

  Widget _buildThumbnail(bool isDark) {
    final thumbnail = task.thumbnail;
    if (thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          thumbnail,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconFallback(isDark),
        ),
      );
    }
    return _iconFallback(isDark);
  }

  Widget _iconFallback(bool isDark) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_kindIcon, color: AppColors.primary, size: 22),
    );
  }
}

/// اندیکاتور دایره‌ای آپلود با درصد داخل
class _CircularUploadIndicator extends StatelessWidget {
  final double progress;

  const _CircularUploadIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = (progress * 100).round();

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor:
                isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Text(
            '$percentage',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// آیکون وضعیت (موفق/ناموفق)
class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 28, color: color)
        .animate()
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 300.ms, curve: Curves.elasticOut);
  }
}

/// نوار پیشرفت خطی متحرک
class _AnimatedProgressBar extends StatelessWidget {
  final double progress;

  const _AnimatedProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDark
                ? AppColors.primary.withValues(alpha: 0.85)
                : AppColors.primary,
          ),
        );
      },
    );
  }
}
