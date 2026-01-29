import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

class WeatherStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const WeatherStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (element.interactionType != StoryInteractionType.weather) {
      return const SizedBox.shrink();
    }

    final data = element.interactionData ?? {};
    final String city = data['city'] ?? 'Tehran';
    final int temp = data['temperature'] is int
        ? data['temperature']
        : int.tryParse(data['temperature'].toString()) ?? 24;
    final int weatherCode = data['weathercode'] as int? ?? 0;

    // 0: Classic (Big Temp + Icon)
    // 1: Minimal Row
    // 2: Card with Detail
    final int style = element.styleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(style),
        child: _buildStyle(context, style, city, temp, weatherCode),
      ),
    );
  }

  Widget _buildStyle(
      BuildContext context, int style, String city, int temp, int code) {
    final iconData = _getWeatherIcon(code);
    final weatherDesc = _getWeatherDescription(code);

    switch (style) {
      case 1:
        return _buildMinimalRowStyle(city, temp, iconData);
      case 2:
        return _buildCardStyle(city, temp, iconData, weatherDesc);
      case 0:
      default:
        return _buildClassicStyle(city, temp, iconData);
    }
  }

  Widget _buildClassicStyle(String city, int temp, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.orange, size: 32),
              const SizedBox(width: 8),
              Text(
                '$temp°',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            city.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalRowStyle(String city, int temp, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.yellow, size: 18),
          const SizedBox(width: 6),
          Text(
            '$temp°C',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 1,
            height: 14,
            color: Colors.white54,
          ),
          Text(
            city,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStyle(String city, int temp, IconData icon, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$temp°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                '$city • $desc',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(int code) {
    // Simply map codes to material icons
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.wb_cloudy;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.umbrella;
    if (code <= 77) return Icons.ac_unit;
    if (code <= 99) return Icons.flash_on;
    return Icons.cloud;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Sunny';
    if (code <= 3) return 'Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rainy';
    if (code <= 77) return 'Snowy';
    if (code <= 99) return 'Stormy';
    return 'Normal';
  }
}
