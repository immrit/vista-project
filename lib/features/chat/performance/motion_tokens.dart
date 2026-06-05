import 'package:flutter/animation.dart';

import 'chat_performance_profile.dart';
import '../../../utils/vista_motion.dart';

enum MotionProfile { performance, balanced, expressive }

class MotionTokens {
  const MotionTokens._();

  static Curve get standardCurve => VistaMotion.smooth;
  static Curve get emphasizedCurve => VistaMotion.springy;
  static Curve get quickCurve => VistaMotion.snappy;

  static Duration messageEntry({
    required ChatEffectsLevel effectsLevel,
    MotionProfile profile = MotionProfile.balanced,
  }) {
    switch (effectsLevel) {
      case ChatEffectsLevel.low:
        // Reduce motion (کاهش حرکت) -> No entry animation
        return Duration.zero;
      case ChatEffectsLevel.medium:
        return profile == MotionProfile.performance
            ? VistaMotion.durationFast
            : VistaMotion.durationMedium;
      case ChatEffectsLevel.high:
        if (profile == MotionProfile.expressive) {
          return VistaMotion.durationSlow;
        }
        return VistaMotion.durationMedium;
    }
  }

  static Duration microInteraction({
    required ChatEffectsLevel effectsLevel,
    MotionProfile profile = MotionProfile.balanced,
  }) {
    switch (effectsLevel) {
      case ChatEffectsLevel.low:
        // Reduce motion -> Very fast or zero
        return Duration.zero;
      case ChatEffectsLevel.medium:
        return const Duration(milliseconds: 100);
      case ChatEffectsLevel.high:
        return VistaMotion.durationFast;
    }
  }
}
