import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class CountdownStickerWidget extends StatefulWidget {
  final StoryElement element;
  final bool isEditable;

  const CountdownStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  State<CountdownStickerWidget> createState() => _CountdownStickerWidgetState();
}

class _CountdownStickerWidgetState extends State<CountdownStickerWidget> {
  late Timer _timer;
  late Duration _remaining;
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    final data = widget.element.interactionData ?? {};
    final targetRaw =
        data['targetDate']?.toString() ?? data['endDate']?.toString() ?? '';
    // Default to 24 hours from now if not set
    _targetDate =
        DateTime.tryParse(targetRaw) ?? DateTime.now().add(const Duration(hours: 24));

    _remaining = _targetDate.difference(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remaining = _targetDate.difference(DateTime.now());
          if (_remaining.isNegative) {
            _timer.cancel();
            _remaining = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.element.interactionData ?? {};
    final String title = data['title'] ?? 'شمارش معکوس';
    final int style = widget.element.resolvedStyleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _buildStyle(style, title),
    );
  }

  Widget _buildStyle(int style, String title) {
    final Key key = ValueKey<int>(style);
    switch (style) {
      case 1: // Glass
        return _buildGlassStyle(key, title);
      case 2: // Gradient
        return _buildGradientStyle(key, title);
      case 0: // Standard White
      default:
        return _buildStandardStyle(key, title);
    }
  }

  Widget _buildStandardStyle(Key key, String title) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
          const SizedBox(height: 8),
          _buildTimerRow(Colors.grey.shade100, Colors.black),
        ],
      ),
    );
  }

  Widget _buildGlassStyle(Key key, String title) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Vazir',
                ),
              ),
              const SizedBox(height: 8),
              _buildTimerRow(Colors.white.withOpacity(0.15), Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientStyle(Key key, String title) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A00E0).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir',
                fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildTimerRow(Colors.white.withOpacity(0.2), Colors.white),
        ],
      ),
    );
  }

  Widget _buildTimerRow(Color blockColor, Color textColor) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final mins = _remaining.inMinutes % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTimeBlock(
            days.toString().padLeft(2, '0'), 'روز', blockColor, textColor),
        const SizedBox(width: 4),
        _buildSeparator(textColor),
        const SizedBox(width: 4),
        _buildTimeBlock(
            hours.toString().padLeft(2, '0'), 'ساعت', blockColor, textColor),
        const SizedBox(width: 4),
        _buildSeparator(textColor),
        const SizedBox(width: 4),
        _buildTimeBlock(
            mins.toString().padLeft(2, '0'), 'دقیقه', blockColor, textColor),
      ],
    );
  }

  Widget _buildTimeBlock(
      String value, String label, Color bgColor, Color textColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Roboto', // Numbers look better in Roboto
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 9,
            fontFamily: 'Vazir',
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        ':',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
