import '../security/logging_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس مدیریت پخش خودکار ویدیوهای پست‌ها
class VideoAutoplayService {
  static final VideoAutoplayService _instance =
      VideoAutoplayService._internal();
  factory VideoAutoplayService() => _instance;
  VideoAutoplayService._internal();

  bool _autoPlayEnabled = false;
  bool _batterySaverMode = false;
  bool _dataSaverEnabled = false;

  /// بررسی آیا پخش خودکار فعال است
  bool get autoPlayEnabled => _autoPlayEnabled && !_batterySaverMode;

  /// بررسی آیا حالت کم‌مصرف فعال است
  bool get batterySaverMode => _batterySaverMode;

  /// بررسی آیا صرفه‌جویی در داده فعال است
  bool get dataSaverEnabled => _dataSaverEnabled;

  /// تنظیم پخش خودکار
  Future<void> setAutoPlay(bool enabled) async {
    if (_batterySaverMode) {
      logInfo('⚠️ Cannot enable auto-play while battery saver mode is active');
      return;
    }

    _autoPlayEnabled = enabled;
    await _saveSettings();

    logInfo('🎥 Video auto-play ${enabled ? 'enabled' : 'disabled'}');
  }

  /// تنظیم حالت کم‌مصرف
  Future<void> setBatterySaverMode(bool enabled) async {
    _batterySaverMode = enabled;

    // اگر حالت کم‌مصرف فعال شد، پخش خودکار را غیرفعال کن
    if (enabled && _autoPlayEnabled) {
      _autoPlayEnabled = false;
      await _saveSettings();
      logInfo('🔋 Battery saver mode enabled - Auto-play disabled');
    } else if (!enabled) {
      // بازگردانی تنظیمات پخش خودکار از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _autoPlayEnabled = prefs.getBool('video_auto_play') ?? false;
      await _saveSettings();
      logInfo('⚡ Battery saver mode disabled - Auto-play settings restored');
    }
  }

  /// تنظیم صرفه‌جویی در داده
  Future<void> setDataSaver(bool enabled) async {
    _dataSaverEnabled = enabled;
    await _saveSettings();

    logInfo('📱 Data saver ${enabled ? 'enabled' : 'disabled'}');
  }

  /// بارگذاری تنظیمات از SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPlayEnabled = prefs.getBool('video_auto_play') ?? false;
      _batterySaverMode = prefs.getBool('battery_saver_mode') ?? false;
      _dataSaverEnabled = prefs.getBool('video_data_saver') ?? false;

      print(
          '📱 Video autoplay settings loaded: auto_play=$_autoPlayEnabled, battery_saver=$_batterySaverMode, data_saver=$_dataSaverEnabled');
    } catch (e) {
      logInfo('❌ Error loading video autoplay settings: $e');
    }
  }

  /// ذخیره تنظیمات در SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('video_auto_play', _autoPlayEnabled);
      await prefs.setBool('battery_saver_mode', _batterySaverMode);
      await prefs.setBool('video_data_saver', _dataSaverEnabled);
    } catch (e) {
      logInfo('❌ Error saving video autoplay settings: $e');
    }
  }

  /// بررسی آیا ویدیو باید خودکار پخش شود
  bool shouldAutoPlay() {
    return _autoPlayEnabled && !_batterySaverMode;
  }

  /// دریافت کیفیت ویدیو بر اساس تنظیمات
  String getVideoQuality() {
    if (_batterySaverMode || _dataSaverEnabled) {
      return 'low';
    }
    return 'high';
  }

  /// دریافت تنظیمات پخش ویدیو
  Map<String, dynamic> getPlaybackSettings() {
    return {
      'autoPlay': shouldAutoPlay(),
      'quality': getVideoQuality(),
      'batterySaver': _batterySaverMode,
      'dataSaver': _dataSaverEnabled,
    };
  }
}
