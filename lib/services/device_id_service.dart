import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _key = 'vista_device_id';
  static String? _cachedId;

  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;
    
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    
    _cachedId = id;
    return id;
  }
  
  // Synchronous getter after initialization
  static String get id => _cachedId ?? 'unknown_device';
}
