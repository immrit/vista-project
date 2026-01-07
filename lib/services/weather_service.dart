import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current temperature and weather code.
  /// returns Map with 'temperature' (int) and 'weathercode' (int) or null.
  Future<Map<String, dynamic>?> getCurrentTemperature(
      double lat, double lng) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl?latitude=$lat&longitude=$lng&current_weather=true');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        if (current != null) {
          return {
            'temperature': (current['temperature'] as num).round(),
            'weathercode': (current['weathercode'] as num).toInt(),
          };
          // Weather Codes:
          // 0: Clear sky
          // 1, 2, 3: Mainly clear, partly cloudy, and overcast
          // 45, 48: Fog
          // 51, 53, 55: Drizzle
          // 61, 63, 65: Rain
          // 71, 73, 75: Snow fall
          // 95, 96, 99: Thunderstorm
        }
      }
      return null;
    } catch (e) {
      // In a real app, log error to reporting service
      print('Error fetching weather: $e');
      return null;
    }
  }
}
