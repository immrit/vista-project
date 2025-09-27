import 'package:shared_preferences/shared_preferences.dart';

/// سرویس مدیریت کیفیت تصاویر
class ImageQualityService {
  static final ImageQualityService _instance = ImageQualityService._internal();
  factory ImageQualityService() => _instance;
  ImageQualityService._internal();

  String _imageQuality = 'high';
  bool _batterySaverMode = false;

  /// دریافت کیفیت تصاویر
  String get imageQuality => _imageQuality;

  /// بررسی آیا حالت کم‌مصرف فعال است
  bool get batterySaverMode => _batterySaverMode;

  /// تنظیم کیفیت تصاویر
  Future<void> setImageQuality(String quality) async {
    if (_batterySaverMode && quality != 'low') {
      print('⚠️ Cannot set high quality while battery saver mode is active');
      return;
    }

    _imageQuality = quality;
    await _saveSettings();

    print('🖼️ Image quality set to: $quality');
  }

  /// تنظیم حالت کم‌مصرف
  Future<void> setBatterySaverMode(bool enabled) async {
    _batterySaverMode = enabled;

    if (enabled) {
      _imageQuality = 'low';
      await _saveSettings();
      print('🔋 Battery saver mode enabled - Image quality set to low');
    } else {
      // بازگردانی کیفیت تصاویر از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _imageQuality = prefs.getString('image_quality') ?? 'high';
      await _saveSettings();
      print('⚡ Battery saver mode disabled - Image quality restored');
    }
  }

  /// بارگذاری تنظیمات از SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _imageQuality = prefs.getString('image_quality') ?? 'high';
      _batterySaverMode = prefs.getBool('battery_saver_mode') ?? false;

      print(
          '📱 Image quality settings loaded: quality=$_imageQuality, battery_saver=$_batterySaverMode');
    } catch (e) {
      print('❌ Error loading image quality settings: $e');
    }
  }

  /// ذخیره تنظیمات در SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('image_quality', _imageQuality);
      await prefs.setBool('battery_saver_mode', _batterySaverMode);
    } catch (e) {
      print('❌ Error saving image quality settings: $e');
    }
  }

  /// دریافت تنظیمات کیفیت تصاویر
  Map<String, dynamic> getImageQualitySettings() {
    return {
      'quality': _imageQuality,
      'batterySaver': _batterySaverMode,
    };
  }

  /// بررسی آیا باید تصاویر با کیفیت بالا نمایش داده شوند
  bool shouldUseHighQuality() {
    return _imageQuality == 'high' && !_batterySaverMode;
  }

  /// دریافت تنظیمات کش برای تصاویر
  Map<String, dynamic> getImageCacheSettings() {
    if (_batterySaverMode || _imageQuality == 'low') {
      return {
        'maxWidth': 800,
        'maxHeight': 600,
        'quality': 70,
      };
    } else {
      return {
        'maxWidth': 1920,
        'maxHeight': 1080,
        'quality': 90,
      };
    }
  }
}
