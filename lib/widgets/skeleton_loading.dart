import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

class BaseSkeletonWidget extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const BaseSkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.blueGrey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.blueGrey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BaseSkeletonWidget(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BaseSkeletonWidget(width: 120, height: 14),
                    const SizedBox(height: AppSpacing.xs),
                    BaseSkeletonWidget(
                        width: 80,
                        height: 10,
                        borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const BaseSkeletonWidget(width: double.infinity, height: 14),
            const SizedBox(height: AppSpacing.xs),
            const BaseSkeletonWidget(width: 200, height: 14),
            const SizedBox(height: AppSpacing.md),
            const BaseSkeletonWidget(
              width: double.infinity,
              height: 250,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    BaseSkeletonWidget(
                        width: 50,
                        height: 24,
                        borderRadius: BorderRadius.circular(12)),
                    const SizedBox(width: AppSpacing.sm),
                    BaseSkeletonWidget(
                        width: 50,
                        height: 24,
                        borderRadius: BorderRadius.circular(12)),
                  ],
                ),
                BaseSkeletonWidget(
                    width: 30,
                    height: 24,
                    borderRadius: BorderRadius.circular(12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class StoryCircleSkeleton extends StatelessWidget {
  const StoryCircleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          const BaseSkeletonWidget(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.all(Radius.circular(32)),
          ),
          const SizedBox(height: AppSpacing.xs),
          BaseSkeletonWidget(
              width: 50, height: 10, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}

class MessageBubbleSkeleton extends StatelessWidget {
  final bool isMe;

  const MessageBubbleSkeleton({super.key, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs, horizontal: AppSpacing.md),
        child: BaseSkeletonWidget(
          width: 150 + (isMe ? 30.0 : 0.0),
          height: 45,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
      ),
    );
  }
}

class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const BaseSkeletonWidget(
            width: 90,
            height: 90,
            borderRadius: BorderRadius.all(Radius.circular(45)),
          ),
          const SizedBox(height: AppSpacing.md),
          const BaseSkeletonWidget(width: 160, height: 18),
          const SizedBox(height: AppSpacing.sm),
          BaseSkeletonWidget(
              width: 220, height: 14, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
                3,
                (index) => Column(
                      children: [
                        const BaseSkeletonWidget(width: 40, height: 16),
                        const SizedBox(height: AppSpacing.xs),
                        BaseSkeletonWidget(
                            width: 50,
                            height: 12,
                            borderRadius: BorderRadius.circular(4)),
                      ],
                    )),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                  child: BaseSkeletonWidget(
                      width: double.infinity,
                      height: 40,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: BaseSkeletonWidget(
                      width: double.infinity,
                      height: 40,
                      borderRadius: BorderRadius.circular(8))),
            ],
          )
        ],
      ),
    );
  }
}
