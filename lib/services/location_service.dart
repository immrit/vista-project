import 'package:geolocator/geolocator.dart';
import '../security/logging_utility.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// دریافت موقعیت مکانی دستگاه
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // بررسی دسترسی به موقعیت
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logInfo('⚠️ Location service is disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logInfo('⚠️ Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        logInfo('⚠️ Location permissions are permanently denied');
        return null;
      }

      // دریافت موقعیت با دقت پایین (برای حفظ حریم خصوصی)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      // برای حال حاضر فقط مختصات را برمی‌گردانیم
      // می‌توانید از سرویس‌های خارجی مثل ipgeolocation یا reverse geocoding استفاده کنید
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'country': null, // می‌توانید از reverse geocoding استفاده کنید
        'city': null, // می‌توانید از reverse geocoding استفاده کنید
      };
    } catch (e) {
      logInfo('❌ Error getting location: $e');
      return null;
    }
  }
}

