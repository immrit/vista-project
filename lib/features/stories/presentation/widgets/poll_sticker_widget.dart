import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class PollStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const PollStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? {};
    final String question = data['question'] ?? 'سوال شما چیست؟';
    final String option1 = data['option1'] ?? 'گزینه ۱';
    final String option2 = data['option2'] ?? 'گزینه ۲';

    final int style = element.resolvedStyleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _buildStyle(style, question, option1, option2),
    );
  }

  Widget _buildStyle(
      int style, String question, String option1, String option2) {
    // Key ensures AnimatedSwitcher detects the change
    final Key key = ValueKey<int>(style);

    switch (style) {
      case 1: // Dark/Neon
        return _buildDarkStyle(key, question, option1, option2);
      case 2: // Minimal Text Only
        return _buildMinimalStyle(key, question, option1, option2);
      case 0: // Standard White
      default:
        return _buildStandardStyle(key, question, option1, option2);
    }
  }

  Widget _buildStandardStyle(
      Key key, String question, String option1, String option2) {
    return Container(
      key: key,
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildOption(option1, Colors.grey.shade100, Colors.black),
          const SizedBox(height: 8),
          _buildOption(option2, Colors.grey.shade100, Colors.black),
        ],
      ),
    );
  }

  Widget _buildDarkStyle(
      Key key, String question, String option1, String option2) {
    return Container(
      key: key,
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withValues(alpha: 0.2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildOption(option1, Colors.white.withValues(alpha: 0.1), Colors.white),
          const SizedBox(height: 8),
          _buildOption(option2, Colors.white.withValues(alpha: 0.1), Colors.white),
        ],
      ),
    );
  }

  Widget _buildMinimalStyle(
      Key key, String question, String option1, String option2) {
    return Container(
      key: key,
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                  child: Center(
                      child: Text(option1,
                          style: const TextStyle(fontFamily: 'Vazir')))),
              Container(width: 1, height: 20, color: Colors.grey),
              Expanded(
                  child: Center(
                      child: Text(option2,
                          style: const TextStyle(fontFamily: 'Vazir')))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOption(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Vazir',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
