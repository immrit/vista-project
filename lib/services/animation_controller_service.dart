import '../security/logging_utility.dart';
import '../DB/advanced_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس مدیریت انیمیشن‌ها برای حالت کم‌مصرف
class AnimationControllerService {
  static final AnimationControllerService _instance =
      AnimationControllerService._internal();
  factory AnimationControllerService() => _instance;
  AnimationControllerService._internal();

  bool _animationsEnabled = true;
  bool _batterySaverMode = false;
  String _animationSpeed = 'normal'; // slow, normal, fast
  bool _reduceMotion = false;

  /// بررسی آیا انیمیشن‌ها فعال هستند
  bool get animationsEnabled {
    // اول از AdvancedSettingsService چک کن
    try {
      final advancedService = AdvancedSettingsService();
      final perfSettings = advancedService.getPerformanceSettings();
      final animations = perfSettings['animations'] as Map<String, dynamic>? ?? {};
      final enabled = animations['enabled'] as bool? ?? true;
      final reduceMotion = animations['reduce_motion'] as bool? ?? false;
      
      if (!enabled || reduceMotion) {
        return false;
      }
      
      // اگر battery saver فعال باشد، انیمیشن‌ها غیرفعال می‌شوند
      return _animationsEnabled && !_batterySaverMode;
    } catch (e) {
      logInfo('⚠️ Error reading animation settings: $e');
      return _animationsEnabled && !_batterySaverMode;
    }
  }

  /// بررسی آیا حالت کم‌مصرف فعال است
  bool get batterySaverMode => _batterySaverMode;

  /// تنظیم حالت کم‌مصرف
  Future<void> setBatterySaverMode(bool enabled) async {
    _batterySaverMode = enabled;
    await _saveSettings();

    if (enabled) {
      logInfo('🔋 Battery saver mode enabled - Animations disabled');
    } else {
      logInfo('⚡ Battery saver mode disabled - Animations enabled');
    }
  }

  /// تنظیم وضعیت انیمیشن‌ها
  Future<void> setAnimationsEnabled(bool enabled) async {
    if (_batterySaverMode) {
      logInfo('⚠️ Cannot enable animations while battery saver mode is active');
      return;
    }

    _animationsEnabled = enabled;
    await _saveSettings();

    logInfo('🎬 Animations ${enabled ? 'enabled' : 'disabled'}');
  }

  /// بارگذاری تنظیمات از SharedPreferences و AdvancedSettingsService
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _animationsEnabled = prefs.getBool('animations_enabled') ?? true;
      _batterySaverMode = prefs.getBool('battery_saver_mode') ?? false;

      // بارگذاری از AdvancedSettingsService
      try {
        final advancedService = AdvancedSettingsService();
        final perfSettings = advancedService.getPerformanceSettings();
        final animations = perfSettings['animations'] as Map<String, dynamic>? ?? {};
        
        _animationsEnabled = animations['enabled'] as bool? ?? true;
        _animationSpeed = animations['speed'] as String? ?? 'normal';
        _reduceMotion = animations['reduce_motion'] as bool? ?? false;
        
        logInfo('📱 Animation settings loaded from AdvancedSettings: enabled=$_animationsEnabled, speed=$_animationSpeed, reduceMotion=$_reduceMotion');
      } catch (e) {
        logInfo('⚠️ Error loading from AdvancedSettings, using defaults: $e');
      }

      print(
          '📱 Animation settings loaded: enabled=$_animationsEnabled, battery_saver=$_batterySaverMode, speed=$_animationSpeed');
    } catch (e) {
      logInfo('❌ Error loading animation settings: $e');
    }
  }

  /// ذخیره تنظیمات در SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('animations_enabled', _animationsEnabled);
      await prefs.setBool('battery_saver_mode', _batterySaverMode);
    } catch (e) {
      logInfo('❌ Error saving animation settings: $e');
    }
  }

  /// دریافت مدت زمان انیمیشن (بر اساس تنظیمات)
  Duration get animationDuration {
    if (!animationsEnabled) return Duration.zero;
    
    // بر اساس سرعت انیمیشن
    switch (_animationSpeed) {
      case 'slow':
        return const Duration(milliseconds: 500);
      case 'fast':
        return const Duration(milliseconds: 150);
      case 'normal':
      default:
        return const Duration(milliseconds: 300);
    }
  }

  /// دریافت منحنی انیمیشن
  Curve get animationCurve {
    return animationsEnabled ? Curves.easeInOut : Curves.linear;
  }

  /// بررسی آیا باید انیمیشن نمایش داده شود
  bool shouldAnimate() {
    return animationsEnabled;
  }

  /// بررسی آیا انیمیشن‌های صفحه‌بندی مجاز هستند
  bool shouldAnimatePageTransitions() {
    return animationsEnabled;
  }

  /// بررسی آیا انیمیشن‌های دکمه‌ها مجاز هستند
  bool shouldAnimateButtons() {
    return animationsEnabled;
  }

  /// بررسی آیا انیمیشن‌های لیست‌ها مجاز هستند
  bool shouldAnimateLists() {
    return animationsEnabled;
  }

  /// دریافت مدت زمان انیمیشن برای نوع خاص
  Duration getAnimationDuration(String animationType) {
    if (!animationsEnabled) return Duration.zero;

    switch (animationType) {
      case 'page_transition':
        return const Duration(milliseconds: 300);
      case 'button_press':
        return const Duration(milliseconds: 150);
      case 'list_item':
        return const Duration(milliseconds: 200);
      case 'fade':
        return const Duration(milliseconds: 250);
      default:
        return animationDuration;
    }
  }
}

/// Extension برای MaterialPageRoute برای مدیریت انیمیشن‌ها
extension AnimatedPageRoute on MaterialPageRoute {
  static MaterialPageRoute<T> create<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
    );
  }
}

/// Extension برای AnimatedContainer
extension AnimatedContainerExtension on AnimatedContainer {
  static AnimatedContainer create({
    Key? key,
    Widget? child,
    AlignmentGeometry? alignment,
    EdgeInsetsGeometry? padding,
    Color? color,
    Decoration? decoration,
    Decoration? foregroundDecoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? margin,
    Matrix4? transform,
    Duration? duration,
    Curve? curve,
    VoidCallback? onEnd,
  }) {
    final animationService = AnimationControllerService();

    return AnimatedContainer(
      key: key,
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      duration: duration ?? animationService.animationDuration,
      curve: curve ?? animationService.animationCurve,
      onEnd: onEnd,
      child: child,
    );
  }
}
