import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_performance_profile.dart';
import 'frame_budget_service.dart';

class AdaptiveEffectsController extends StateNotifier<AdaptiveEffectsState> {
  AdaptiveEffectsController(this._frameBudgetService)
      : super(const AdaptiveEffectsState.initial()) {
    _frameBudgetService.startMonitoring();
    _frameBudgetService.snapshotNotifier.addListener(_onBudgetUpdate);
    _onBudgetUpdate();
  }

  final FrameBudgetService _frameBudgetService;

  bool _dynamicEffectsEnabled = true;
  bool _gpuAccelerationEnabled = true;
  double _maxBlurSigma = 10.0;
  String _chatEntryModePref = 'adaptive';
  bool _chatPerfEnabled = true;
  bool _adaptiveEffectsRolloutEnabled = true;
  bool _motionTokensEnabled = true;

  static const double _fastScrollThreshold = 2200.0;
  static const double _budgetP95DeltaThresholdMs = 1.0;
  static const double _budgetJankDeltaThreshold = 0.01;

  void _onBudgetUpdate() {
    _recompute(
      budget: _frameBudgetService.snapshotNotifier.value,
      profile: _frameBudgetService.profileNotifier.value,
      velocity: state.scrollVelocityPxPerSec,
    );
  }

  void updateScrollVelocity(double velocityPxPerSec) {
    final normalized = velocityPxPerSec.isFinite ? velocityPxPerSec : 0.0;
    if ((normalized - state.scrollVelocityPxPerSec).abs() < 80) {
      return;
    }
    _recompute(
      budget: _frameBudgetService.snapshotNotifier.value,
      profile: _frameBudgetService.profileNotifier.value,
      velocity: normalized,
    );
  }

  void applySettings({
    Map<String, dynamic>? rendering,
    Map<String, dynamic>? animations,
    Map<String, dynamic>? featureFlags,
  }) {
    if (rendering != null) {
      _dynamicEffectsEnabled = rendering['dynamic_effects'] as bool? ?? true;
      _gpuAccelerationEnabled =
          rendering['enable_gpu_acceleration'] as bool? ?? true;
      _maxBlurSigma =
          ((rendering['max_blur_sigma'] as num?) ?? 10.0).toDouble();
    }
    if (animations != null) {
      _chatEntryModePref =
          (animations['chat_entry_mode'] as String? ?? 'adaptive')
              .toLowerCase();
    }
    if (featureFlags != null) {
      _chatPerfEnabled = featureFlags['chat_perf_v1'] as bool? ?? true;
      _adaptiveEffectsRolloutEnabled =
          featureFlags['adaptive_effects_v1'] as bool? ?? true;
      _motionTokensEnabled = featureFlags['motion_tokens_v1'] as bool? ?? true;
    }
    _recompute(
      budget: _frameBudgetService.snapshotNotifier.value,
      profile: _frameBudgetService.profileNotifier.value,
      velocity: state.scrollVelocityPxPerSec,
    );
  }

  void _recompute({
    required FrameBudgetSnapshot budget,
    required ChatPerformanceProfile profile,
    required double velocity,
  }) {
    final canRunAdaptive = _chatPerfEnabled && _adaptiveEffectsRolloutEnabled;
    final isFast = canRunAdaptive && velocity.abs() >= _fastScrollThreshold;

    ChatEffectsLevel level;
    if (!canRunAdaptive || !_dynamicEffectsEnabled) {
      level = ChatEffectsLevel.high;
    } else {
      switch (profile) {
        case ChatPerformanceProfile.high:
          level = ChatEffectsLevel.high;
          break;
        case ChatPerformanceProfile.medium:
          level = ChatEffectsLevel.medium;
          break;
        case ChatPerformanceProfile.low:
          level = ChatEffectsLevel.low;
          break;
      }
      if (isFast && level != ChatEffectsLevel.low) {
        level = ChatEffectsLevel.medium;
      }
      if (isFast && profile == ChatPerformanceProfile.low) {
        level = ChatEffectsLevel.low;
      }
    }
    if (!_gpuAccelerationEnabled && level == ChatEffectsLevel.high) {
      level = ChatEffectsLevel.medium;
    }

    final blurSigma = switch (level) {
      ChatEffectsLevel.low => 0.0,
      ChatEffectsLevel.medium => 4.0,
      ChatEffectsLevel.high => 8.0,
    }
        .clamp(0.0, _gpuAccelerationEnabled ? _maxBlurSigma : 4.0);

    var chatEntryMode = _resolveEntryMode(level, isFast);
    if (!_gpuAccelerationEnabled &&
        chatEntryMode == ChatEntryAnimationMode.full) {
      chatEntryMode = ChatEntryAnimationMode.minimal;
    }
    final enableMessageEntryAnimation =
        chatEntryMode != ChatEntryAnimationMode.off;
    final allowHeavyBlur =
        _gpuAccelerationEnabled && level == ChatEffectsLevel.high && !isFast;

    final shouldUpdateBudget = _shouldUpdateBudget(
      previous: state.budgetSnapshot,
      next: budget,
    );
    final nextBudgetSnapshot =
        shouldUpdateBudget ? budget : state.budgetSnapshot;

    final nextState = state.copyWith(
      profile: profile,
      effectsLevel: level,
      chatPerfEnabled: _chatPerfEnabled,
      adaptiveEffectsRolloutEnabled: _adaptiveEffectsRolloutEnabled,
      motionTokensEnabled: _motionTokensEnabled,
      dynamicEffectsEnabled: _dynamicEffectsEnabled,
      allowHeavyBlur: allowHeavyBlur,
      blurSigma: blurSigma,
      isFastScrolling: isFast,
      scrollVelocityPxPerSec: velocity,
      budgetSnapshot: nextBudgetSnapshot,
      chatEntryMode: chatEntryMode,
      enableMessageEntryAnimation: enableMessageEntryAnimation,
    );

    if (_isEquivalent(state, nextState,
        compareBudgetSnapshot: shouldUpdateBudget)) {
      return;
    }

    state = nextState;
  }

  ChatEntryAnimationMode _resolveEntryMode(
      ChatEffectsLevel level, bool isFastScrolling) {
    switch (_chatEntryModePref) {
      case 'off':
        return ChatEntryAnimationMode.off;
      case 'minimal':
        return ChatEntryAnimationMode.minimal;
      case 'full':
        return isFastScrolling
            ? ChatEntryAnimationMode.minimal
            : ChatEntryAnimationMode.full;
      case 'adaptive':
      default:
        if (isFastScrolling) {
          return ChatEntryAnimationMode.off;
        }
        switch (level) {
          case ChatEffectsLevel.low:
            return ChatEntryAnimationMode.off;
          case ChatEffectsLevel.medium:
            return ChatEntryAnimationMode.minimal;
          case ChatEffectsLevel.high:
            return ChatEntryAnimationMode.full;
        }
    }
  }

  bool _shouldUpdateBudget({
    required FrameBudgetSnapshot previous,
    required FrameBudgetSnapshot next,
  }) {
    if (next.sampleCount == 0) return false;
    if (previous.sampleCount == 0) return true;
    final p95Delta = (next.p95Ms - previous.p95Ms).abs();
    final jankDelta = (next.jankRatio - previous.jankRatio).abs();
    return p95Delta >= _budgetP95DeltaThresholdMs ||
        jankDelta >= _budgetJankDeltaThreshold ||
        next.sampleCount - previous.sampleCount >= 24;
  }

  bool _isEquivalent(
    AdaptiveEffectsState a,
    AdaptiveEffectsState b, {
    required bool compareBudgetSnapshot,
  }) {
    final sameCore = a.profile == b.profile &&
        a.effectsLevel == b.effectsLevel &&
        a.chatEntryMode == b.chatEntryMode &&
        a.chatPerfEnabled == b.chatPerfEnabled &&
        a.adaptiveEffectsRolloutEnabled == b.adaptiveEffectsRolloutEnabled &&
        a.motionTokensEnabled == b.motionTokensEnabled &&
        a.dynamicEffectsEnabled == b.dynamicEffectsEnabled &&
        a.allowHeavyBlur == b.allowHeavyBlur &&
        a.enableMessageEntryAnimation == b.enableMessageEntryAnimation &&
        a.isFastScrolling == b.isFastScrolling &&
        (a.blurSigma - b.blurSigma).abs() < 0.01;
    if (!sameCore) return false;
    if (!compareBudgetSnapshot) return true;
    return a.budgetSnapshot.sampleCount == b.budgetSnapshot.sampleCount &&
        (a.budgetSnapshot.p95Ms - b.budgetSnapshot.p95Ms).abs() < 0.01 &&
        (a.budgetSnapshot.jankRatio - b.budgetSnapshot.jankRatio).abs() <
            0.0001;
  }

  @override
  void dispose() {
    _frameBudgetService.snapshotNotifier.removeListener(_onBudgetUpdate);
    super.dispose();
  }
}

final frameBudgetServiceProvider = Provider<FrameBudgetService>((ref) {
  final service = FrameBudgetService.instance;
  service.startMonitoring();
  return service;
});

final adaptiveEffectsProvider =
    StateNotifierProvider<AdaptiveEffectsController, AdaptiveEffectsState>(
        (ref) {
  final service = ref.watch(frameBudgetServiceProvider);
  final controller = AdaptiveEffectsController(service);
  ref.onDispose(controller.dispose);
  return controller;
});
