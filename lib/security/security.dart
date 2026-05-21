import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Returns the public IP of the device by querying the Go backend.
/// Falls back to 'unavailable' on any error.
Future<String> getIpAddress() async {
  final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080';
  final url = Uri.parse('$backendUrl/v1/utils/client-ip');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        final ip = data['ip']?.toString();
        if (ip != null && ip.isNotEmpty) return ip;
      }
    }
  } catch (_) {}
  return 'unavailable';
}

Future<void> updateIpAddress() async {
  // 🔒 FIX: Deprecated. IP tracking is handled by the server.
  return;
}
