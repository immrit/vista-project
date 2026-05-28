import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

enum DevicePerformanceTier { low, medium, high }

class DeviceCapabilitySnapshot {
  final DevicePerformanceTier tier;
  final String reason;

  const DeviceCapabilitySnapshot({
    required this.tier,
    required this.reason,
  });
}

class DeviceCapabilityService {
  DeviceCapabilityService._();
  static final DeviceCapabilityService instance = DeviceCapabilityService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceCapabilitySnapshot> detectTier({
    required double shortestLogicalSide,
    required double totalPhysicalPixels,
    required double devicePixelRatio,
  }) async {
    var score = 0;
    final reasons = <String>[];

    // Screen class heuristics.
    if (shortestLogicalSide < 380 || totalPhysicalPixels < 1.2e6) {
      score -= 2;
      reasons.add('small_or_lowres_screen');
    } else if (shortestLogicalSide >= 430 &&
        totalPhysicalPixels >= 2.6e6 &&
        devicePixelRatio >= 2.5) {
      score += 2;
      reasons.add('large_highres_screen');
    } else {
      reasons.add('mid_screen');
    }

    // CPU core count gives a practical baseline.
    final cores = Platform.numberOfProcessors;
    if (cores <= 4) {
      score -= 2;
      reasons.add('low_cpu_cores');
    } else if (cores <= 6) {
      score -= 1;
      reasons.add('mid_cpu_cores');
    } else if (cores >= 8) {
      score += 1;
      reasons.add('high_cpu_cores');
    }

    // Platform + model generation hints.
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final sdk = info.version.sdkInt;
        if (sdk <= 27) {
          score -= 2;
          reasons.add('old_android_sdk');
        } else if (sdk >= 33) {
          score += 1;
          reasons.add('new_android_sdk');
        }
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        final model = info.utsname.machine.toLowerCase();
        if (model.contains('iphone8') ||
            model.contains('iphone9') ||
            model.contains('iphone10')) {
          score -= 2;
          reasons.add('older_iphone_model');
        } else if (model.contains('iphone14') ||
            model.contains('iphone15') ||
            model.contains('iphone16')) {
          score += 1;
          reasons.add('newer_iphone_model');
        } else {
          reasons.add('unknown_iphone_model');
        }
      } else {
        reasons.add('non_mobile_platform');
      }
    } catch (_) {
      reasons.add('device_info_fallback');
    }

    final tier = score <= -2
        ? DevicePerformanceTier.low
        : (score >= 2
            ? DevicePerformanceTier.high
            : DevicePerformanceTier.medium);

    return DeviceCapabilitySnapshot(
      tier: tier,
      reason: reasons.join('+'),
    );
  }
}
