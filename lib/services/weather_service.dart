import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current temperature and weather code.
  /// returns Map with 'temperature' (int) and 'weathercode' (int) or null.
  Future<Map<String, dynamic>?> getCurrentTemperature(
      double lat, double lng) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl?latitude=$lat&longitude=$lng&current_weather=true&current=temperature_2m,weather_code&timezone=auto&forecast_days=1');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final currentWeather = data['current_weather'] as Map<String, dynamic>?;
      final current = data['current'] as Map<String, dynamic>?;

      final tempRaw =
          currentWeather?['temperature'] ?? current?['temperature_2m'];
      final codeRaw =
          currentWeather?['weathercode'] ?? current?['weather_code'];

      if (tempRaw is num && codeRaw is num) {
        return {
          'temperature': tempRaw.round(),
          'weathercode': codeRaw.toInt(),
        };
      }

      return null;
    } catch (e) {
      debugPrint('WeatherService error: $e');
      return null;
    }
  }
}
