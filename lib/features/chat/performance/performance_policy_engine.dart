import 'chat_performance_profile.dart';

enum OptimizationSurface { chat, feed, story }

class PerformancePolicyResult {
  final ChatEffectsLevel effectsLevel;
  final ChatEntryAnimationMode chatEntryMode;
  final bool allowHeavyBlur;
  final bool enableMessageEntryAnimation;
  final bool isFastScrolling;
  final double blurSigma;
  final bool motionTokensEnabled;
  final String reason;

  const PerformancePolicyResult({
    required this.effectsLevel,
    required this.chatEntryMode,
    required this.allowHeavyBlur,
    required this.enableMessageEntryAnimation,
    required this.isFastScrolling,
    required this.blurSigma,
    required this.motionTokensEnabled,
    required this.reason,
  });
}

class PerformancePolicyEngine {
  static const double fastScrollThreshold = 1400.0;

  static PerformancePolicyResult resolve({
    OptimizationSurface surface = OptimizationSurface.chat,
    required ChatPerformanceProfile profile,
    required double velocityPxPerSec,
    required bool dynamicEffectsEnabled,
    required bool gpuAccelerationEnabled,
    required bool chatPerfEnabled,
    required bool adaptiveEffectsRolloutEnabled,
    required bool motionTokensEnabled,
    required bool userReduceMotionEnabled,
    required bool systemReduceMotionEnabled,
    required String chatEntryModePref,
    required double maxBlurSigma,
  }) {
    final reduceMotionHard =
        userReduceMotionEnabled || systemReduceMotionEnabled;
    final canRunAdaptive = chatPerfEnabled && adaptiveEffectsRolloutEnabled;
    final fastScrollLimit = _fastScrollThresholdForSurface(surface);
    final isFastScrolling =
        canRunAdaptive && velocityPxPerSec.abs() >= fastScrollLimit;

    final effectsLevel = _resolveEffectsLevel(
      surface: surface,
      profile: profile,
      canRunAdaptive: canRunAdaptive,
      dynamicEffectsEnabled: dynamicEffectsEnabled,
      gpuAccelerationEnabled: gpuAccelerationEnabled,
      reduceMotionHard: reduceMotionHard,
      isFastScrolling: isFastScrolling,
    );

    final entryMode = _resolveChatEntryMode(
      chatEntryModePref: chatEntryModePref,
      effectsLevel: effectsLevel,
      reduceMotionHard: reduceMotionHard,
      isFastScrolling: isFastScrolling,
      gpuAccelerationEnabled: gpuAccelerationEnabled,
    );

    final blurSigma = _resolveBlurSigma(
      effectsLevel: effectsLevel,
      reduceMotionHard: reduceMotionHard,
      gpuAccelerationEnabled: gpuAccelerationEnabled,
      maxBlurSigma: maxBlurSigma,
    );
    final reason = _resolveReason(
      reduceMotionHard: reduceMotionHard,
      systemReduceMotionEnabled: systemReduceMotionEnabled,
      userReduceMotionEnabled: userReduceMotionEnabled,
      canRunAdaptive: canRunAdaptive,
      dynamicEffectsEnabled: dynamicEffectsEnabled,
      isFastScrolling: isFastScrolling,
      gpuAccelerationEnabled: gpuAccelerationEnabled,
      profile: profile,
    );

    final allowHeavyBlur = !reduceMotionHard &&
        gpuAccelerationEnabled &&
        effectsLevel == ChatEffectsLevel.high &&
        !isFastScrolling;

    return PerformancePolicyResult(
      effectsLevel: effectsLevel,
      chatEntryMode: entryMode,
      allowHeavyBlur: allowHeavyBlur,
      enableMessageEntryAnimation: entryMode != ChatEntryAnimationMode.off,
      isFastScrolling: isFastScrolling,
      blurSigma: blurSigma,
      motionTokensEnabled: !reduceMotionHard && motionTokensEnabled,
      reason: reason,
    );
  }

  static String _resolveReason({
    required bool reduceMotionHard,
    required bool systemReduceMotionEnabled,
    required bool userReduceMotionEnabled,
    required bool canRunAdaptive,
    required bool dynamicEffectsEnabled,
    required bool isFastScrolling,
    required bool gpuAccelerationEnabled,
    required ChatPerformanceProfile profile,
  }) {
    if (reduceMotionHard) {
      if (systemReduceMotionEnabled) return 'system_reduce_motion';
      if (userReduceMotionEnabled) return 'user_reduce_motion';
      return 'reduce_motion';
    }
    if (!canRunAdaptive) return 'adaptive_disabled';
    if (!dynamicEffectsEnabled) return 'dynamic_effects_disabled';
    if (isFastScrolling) return 'fast_scroll';
    if (!gpuAccelerationEnabled) return 'gpu_disabled';
    return switch (profile) {
      ChatPerformanceProfile.high => 'profile_high',
      ChatPerformanceProfile.medium => 'profile_medium',
      ChatPerformanceProfile.low => 'profile_low',
    };
  }

  static ChatEffectsLevel _resolveEffectsLevel({
    required OptimizationSurface surface,
    required ChatPerformanceProfile profile,
    required bool canRunAdaptive,
    required bool dynamicEffectsEnabled,
    required bool gpuAccelerationEnabled,
    required bool reduceMotionHard,
    required bool isFastScrolling,
  }) {
    if (reduceMotionHard) return ChatEffectsLevel.low;
    if (!canRunAdaptive || !dynamicEffectsEnabled) {
      return gpuAccelerationEnabled
          ? ChatEffectsLevel.medium
          : ChatEffectsLevel.low;
    }

    var level = switch (profile) {
      ChatPerformanceProfile.high => ChatEffectsLevel.high,
      ChatPerformanceProfile.medium => ChatEffectsLevel.medium,
      ChatPerformanceProfile.low => ChatEffectsLevel.low,
    };

    // effectsLevel is NOT reduced on fast scroll: velocity changes would trigger
    // mass row rebuilds via the selector in ChatMessageRow. Fast-scroll behaviour
    // is handled via chatEntryMode (new messages only) and allowHeavyBlur (background).
    if (!gpuAccelerationEnabled && level == ChatEffectsLevel.high) {
      level = ChatEffectsLevel.medium;
    }

    // Feed/Story surfaces stay more conservative than direct chat.
    if (surface != OptimizationSurface.chat && level == ChatEffectsLevel.high) {
      level = ChatEffectsLevel.medium;
    }
    return level;
  }

  static double _fastScrollThresholdForSurface(OptimizationSurface surface) {
    return switch (surface) {
      OptimizationSurface.chat => fastScrollThreshold,
      OptimizationSurface.feed => 1600.0,
      OptimizationSurface.story => 1400.0,
    };
  }

  static ChatEntryAnimationMode _resolveChatEntryMode({
    required String chatEntryModePref,
    required ChatEffectsLevel effectsLevel,
    required bool reduceMotionHard,
    required bool isFastScrolling,
    required bool gpuAccelerationEnabled,
  }) {
    if (reduceMotionHard) return ChatEntryAnimationMode.off;

    ChatEntryAnimationMode mode;
    switch (chatEntryModePref) {
      case 'off':
        mode = ChatEntryAnimationMode.off;
        break;
      case 'minimal':
        mode = ChatEntryAnimationMode.minimal;
        break;
      case 'full':
        mode = isFastScrolling
            ? ChatEntryAnimationMode.minimal
            : ChatEntryAnimationMode.full;
        break;
      case 'adaptive':
      default:
        if (isFastScrolling) {
          mode = ChatEntryAnimationMode.off;
        } else {
          mode = switch (effectsLevel) {
            ChatEffectsLevel.low => ChatEntryAnimationMode.off,
            ChatEffectsLevel.medium => ChatEntryAnimationMode.minimal,
            ChatEffectsLevel.high => ChatEntryAnimationMode.full,
          };
        }
        break;
    }

    if (!gpuAccelerationEnabled && mode == ChatEntryAnimationMode.full) {
      return ChatEntryAnimationMode.minimal;
    }
    return mode;
  }

  static double _resolveBlurSigma({
    required ChatEffectsLevel effectsLevel,
    required bool reduceMotionHard,
    required bool gpuAccelerationEnabled,
    required double maxBlurSigma,
  }) {
    if (reduceMotionHard) return 0;
    final baseSigma = switch (effectsLevel) {
      ChatEffectsLevel.low => 0.0,
      ChatEffectsLevel.medium => 4.0,
      ChatEffectsLevel.high => 8.0,
    };
    return baseSigma.clamp(0.0, gpuAccelerationEnabled ? maxBlurSigma : 4.0);
  }
}
