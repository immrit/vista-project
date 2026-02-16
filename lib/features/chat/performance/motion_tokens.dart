import 'package:flutter/animation.dart';

import 'chat_performance_profile.dart';

enum MotionProfile { performance, balanced, expressive }

class MotionTokens {
  const MotionTokens._();

  static Curve get standardCurve => Curves.easeOutCubic;
  static Curve get emphasizedCurve => Curves.easeOutBack;
  static Curve get quickCurve => Curves.easeOut;

  static Duration messageEntry({
    required ChatEffectsLevel effectsLevel,
    MotionProfile profile = MotionProfile.balanced,
  }) {
    switch (effectsLevel) {
      case ChatEffectsLevel.low:
        return const Duration(milliseconds: 120);
      case ChatEffectsLevel.medium:
        return profile == MotionProfile.performance
            ? const Duration(milliseconds: 140)
            : const Duration(milliseconds: 170);
      case ChatEffectsLevel.high:
        if (profile == MotionProfile.performance) {
          return const Duration(milliseconds: 160);
        }
        if (profile == MotionProfile.expressive) {
          return const Duration(milliseconds: 230);
        }
        return const Duration(milliseconds: 190);
    }
  }

  static Duration microInteraction({
    required ChatEffectsLevel effectsLevel,
    MotionProfile profile = MotionProfile.balanced,
  }) {
    switch (effectsLevel) {
      case ChatEffectsLevel.low:
        return const Duration(milliseconds: 90);
      case ChatEffectsLevel.medium:
        return profile == MotionProfile.expressive
            ? const Duration(milliseconds: 140)
            : const Duration(milliseconds: 110);
      case ChatEffectsLevel.high:
        return profile == MotionProfile.performance
            ? const Duration(milliseconds: 120)
            : const Duration(milliseconds: 160);
    }
  }
}
