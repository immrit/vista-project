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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A3040) : Colors.grey[300]!;
    final highlightColor = isDark ? const Color(0xFF3D4D66) : Colors.grey[100]!;

    Widget sh(double w, double h, {double r = 8, bool circle = false}) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: baseColor,
            // BoxShape.circle و borderRadius نمی‌توانند همزمان تنظیم شوند
            borderRadius: circle ? null : BorderRadius.circular(r),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
      );
    }

    // دقیقاً مشابه _ThreadPostItem:
    // Row بیرونی RTL: [avatar RIGHT | content column LEFT]
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── آواتار (radius 22) ───
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              // ─── ستون محتوا ───
              Expanded(
                child: Column(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // هدر: نام + • + زمان (بدون دکمه follow)
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        sh(90, 14, r: 6),       // نام
                        const SizedBox(width: 8),
                        sh(8, 8, circle: true), // نقطه جدا‌کننده •
                        const SizedBox(width: 8),
                        sh(28, 12, r: 4),       // زمان (مثل "2h")
                      ],
                    ),
                    const SizedBox(height: 10),
                    // متن پست - خط ۱
                    sh(double.infinity, 14),
                    const SizedBox(height: 5),
                    // متن پست - خط ۲
                    sh(double.infinity, 14),
                    const SizedBox(height: 5),
                    // متن پست - خط ۳ (کوتاه‌تر)
                    sh(180, 14),
                    const SizedBox(height: 12),
                    // تصویر (اختیاری - بعضی پست‌ها دارن)
                    sh(double.infinity, 200, r: 14),
                    const SizedBox(height: 12),
                    // ردیف اکشن (مطابق اسکرین‌شات):
                    // RTL → [like❤️ RIGHT] [0 comment💬] [bookmark] [share] ... [•••circle LEFT]
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // like + عدد
                        sh(20, 20, r: 4),
                        const SizedBox(width: 4),
                        sh(16, 12, r: 4),
                        const SizedBox(width: 14),
                        // comment + عدد
                        sh(20, 20, r: 4),
                        const SizedBox(width: 4),
                        sh(16, 12, r: 4),
                        const SizedBox(width: 14),
                        // bookmark
                        sh(20, 20, r: 4),
                        const SizedBox(width: 14),
                        // share
                        sh(20, 20, r: 4),
                        const Spacer(),
                        // ••• داخل دایره خاکستری
                        Shimmer.fromColors(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: baseColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
