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

  /// بررسی آیا انیمیشن‌ها فعال هستند
  bool get animationsEnabled => _animationsEnabled && !_batterySaverMode;

  /// بررسی آیا حالت کم‌مصرف فعال است
  bool get batterySaverMode => _batterySaverMode;

  /// تنظیم حالت کم‌مصرف
  Future<void> setBatterySaverMode(bool enabled) async {
    _batterySaverMode = enabled;
    await _saveSettings();

    if (enabled) {
      print('🔋 Battery saver mode enabled - Animations disabled');
    } else {
      print('⚡ Battery saver mode disabled - Animations enabled');
    }
  }

  /// تنظیم وضعیت انیمیشن‌ها
  Future<void> setAnimationsEnabled(bool enabled) async {
    if (_batterySaverMode) {
      print('⚠️ Cannot enable animations while battery saver mode is active');
      return;
    }

    _animationsEnabled = enabled;
    await _saveSettings();

    print('🎬 Animations ${enabled ? 'enabled' : 'disabled'}');
  }

  /// بارگذاری تنظیمات از SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _animationsEnabled = prefs.getBool('animations_enabled') ?? true;
      _batterySaverMode = prefs.getBool('battery_saver_mode') ?? false;

      print(
          '📱 Animation settings loaded: enabled=$_animationsEnabled, battery_saver=$_batterySaverMode');
    } catch (e) {
      print('❌ Error loading animation settings: $e');
    }
  }

  /// ذخیره تنظیمات در SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('animations_enabled', _animationsEnabled);
      await prefs.setBool('battery_saver_mode', _batterySaverMode);
    } catch (e) {
      print('❌ Error saving animation settings: $e');
    }
  }

  /// دریافت مدت زمان انیمیشن (صفر در حالت کم‌مصرف)
  Duration get animationDuration {
    return animationsEnabled
        ? const Duration(milliseconds: 300)
        : Duration.zero;
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
