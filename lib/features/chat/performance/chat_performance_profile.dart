import 'package:flutter/foundation.dart';

enum ChatPerformanceProfile { low, medium, high }

enum ChatEffectsLevel { low, medium, high }

enum ChatEntryAnimationMode { off, minimal, full }

@immutable
class FrameBudgetSnapshot {
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;
  final double jankRatio;
  final int sampleCount;

  const FrameBudgetSnapshot({
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.jankRatio,
    required this.sampleCount,
  });

  const FrameBudgetSnapshot.empty()
      : p50Ms = 0,
        p95Ms = 0,
        p99Ms = 0,
        jankRatio = 0,
        sampleCount = 0;
}

@immutable
class AdaptiveEffectsState {
  final ChatPerformanceProfile profile;
  final ChatEffectsLevel effectsLevel;
  final ChatEntryAnimationMode chatEntryMode;
  final bool chatPerfEnabled;
  final bool adaptiveEffectsRolloutEnabled;
  final bool motionTokensEnabled;
  final bool dynamicEffectsEnabled;
  final bool allowHeavyBlur;
  final bool enableMessageEntryAnimation;
  final bool isFastScrolling;
  final double blurSigma;
  final double scrollVelocityPxPerSec;
  final FrameBudgetSnapshot budgetSnapshot;
  final String optimizationReason;

  const AdaptiveEffectsState({
    required this.profile,
    required this.effectsLevel,
    required this.chatEntryMode,
    required this.chatPerfEnabled,
    required this.adaptiveEffectsRolloutEnabled,
    required this.motionTokensEnabled,
    required this.dynamicEffectsEnabled,
    required this.allowHeavyBlur,
    required this.enableMessageEntryAnimation,
    required this.isFastScrolling,
    required this.blurSigma,
    required this.scrollVelocityPxPerSec,
    required this.budgetSnapshot,
    required this.optimizationReason,
  });

  const AdaptiveEffectsState.initial()
      : profile = ChatPerformanceProfile.high,
        effectsLevel = ChatEffectsLevel.high,
        chatEntryMode = ChatEntryAnimationMode.full,
        chatPerfEnabled = true,
        adaptiveEffectsRolloutEnabled = true,
        motionTokensEnabled = true,
        dynamicEffectsEnabled = true,
        allowHeavyBlur = true,
        enableMessageEntryAnimation = true,
        isFastScrolling = false,
        blurSigma = 8,
        scrollVelocityPxPerSec = 0,
        budgetSnapshot = const FrameBudgetSnapshot.empty(),
        optimizationReason = 'initial';

  AdaptiveEffectsState copyWith({
    ChatPerformanceProfile? profile,
    ChatEffectsLevel? effectsLevel,
    ChatEntryAnimationMode? chatEntryMode,
    bool? chatPerfEnabled,
    bool? adaptiveEffectsRolloutEnabled,
    bool? motionTokensEnabled,
    bool? dynamicEffectsEnabled,
    bool? allowHeavyBlur,
    bool? enableMessageEntryAnimation,
    bool? isFastScrolling,
    double? blurSigma,
    double? scrollVelocityPxPerSec,
    FrameBudgetSnapshot? budgetSnapshot,
    String? optimizationReason,
  }) {
    return AdaptiveEffectsState(
      profile: profile ?? this.profile,
      effectsLevel: effectsLevel ?? this.effectsLevel,
      chatEntryMode: chatEntryMode ?? this.chatEntryMode,
      chatPerfEnabled: chatPerfEnabled ?? this.chatPerfEnabled,
      adaptiveEffectsRolloutEnabled:
          adaptiveEffectsRolloutEnabled ?? this.adaptiveEffectsRolloutEnabled,
      motionTokensEnabled: motionTokensEnabled ?? this.motionTokensEnabled,
      dynamicEffectsEnabled:
          dynamicEffectsEnabled ?? this.dynamicEffectsEnabled,
      allowHeavyBlur: allowHeavyBlur ?? this.allowHeavyBlur,
      enableMessageEntryAnimation:
          enableMessageEntryAnimation ?? this.enableMessageEntryAnimation,
      isFastScrolling: isFastScrolling ?? this.isFastScrolling,
      blurSigma: blurSigma ?? this.blurSigma,
      scrollVelocityPxPerSec:
          scrollVelocityPxPerSec ?? this.scrollVelocityPxPerSec,
      budgetSnapshot: budgetSnapshot ?? this.budgetSnapshot,
      optimizationReason: optimizationReason ?? this.optimizationReason,
    );
  }
}
