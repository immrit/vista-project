import 'package:Vista/services/http_client_factory.dart';

class SystemStatus {
  final bool maintenance;
  final Map<String, bool> features;

  SystemStatus({required this.maintenance, required this.features});

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      maintenance: json['maintenance'] ?? false,
      features: Map<String, bool>.from(json['features'] ?? {}),
    );
  }
}

class SystemStatusService {
  static final SystemStatusService instance = SystemStatusService._internal();
  SystemStatusService._internal();

  SystemStatus? _cachedStatus;

  Future<SystemStatus?> fetchStatus() async {
    try {
      final dio = createPinnedDioClient();
      final response = await dio.get('/api/v1/system/status');
      if (response.statusCode == 200) {
        _cachedStatus = SystemStatus.fromJson(response.data);
        return _cachedStatus;
      }
    } catch (e) {
      // Ignored
    }
    return _cachedStatus;
  }

  bool isFeatureEnabled(String featureKey) {
    if (_cachedStatus == null) return true; // Default to true if not fetched
    return _cachedStatus!.features[featureKey] ?? true;
  }
}
