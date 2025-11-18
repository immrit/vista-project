import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// دریافت موقعیت مکانی دستگاه
  /// این متد به صورت کاملاً silent و بدون مزاحمت برای کاربر اجرا می‌شود
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // بررسی دسترسی به موقعیت (با timeout)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      
      if (!serviceEnabled) {
        return null; // بدون لاگ - silent
      }

      // بررسی مجوز (با timeout)
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 2), onTimeout: () => LocationPermission.denied);
      
      // اگر مجوز denied است، درخواست می‌کنیم (اما با timeout کوتاه)
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(seconds: 3), onTimeout: () => LocationPermission.denied);
        } catch (e) {
          // در صورت timeout یا خطا، ادامه نمی‌دهیم
          return null;
        }
        
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          return null; // بدون لاگ - silent
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null; // بدون لاگ - silent
      }

      // دریافت موقعیت با دقت پایین و timeout کوتاه
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      ).timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('Location timeout'));

      // استفاده از reverse geocoding برای دریافت نام شهر و کشور (با timeout)
      String? country;
      String? city;
      
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 3), onTimeout: () => <Placemark>[]);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          country = place.country;
          city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;
        }
      } catch (e) {
        // در صورت خطا، فقط مختصات را برمی‌گردانیم - بدون لاگ
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'country': country,
        'city': city,
      };
    } on TimeoutException {
      return null; // بدون لاگ - silent
    } catch (e) {
      return null; // بدون لاگ - silent
    }
  }
}

