import 'package:flutter/material.dart';

/// نوار پیشرفت استوری
class StoryProgressBar extends StatelessWidget {
  final int storiesCount;
  final int currentIndex;
  final AnimationController controller;

  const StoryProgressBar({
    super.key,
    required this.storiesCount,
    required this.currentIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(storiesCount, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 2,
              right: index == storiesCount - 1 ? 0 : 2,
            ),
            child: _buildProgressSegment(index),
          ),
        );
      }),
    );
  }

  Widget _buildProgressSegment(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            // پس‌زمینه
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // پیشرفت
            if (index < currentIndex)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else if (index == currentIndex)
              AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: controller.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
