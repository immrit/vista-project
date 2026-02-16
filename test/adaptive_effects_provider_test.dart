import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/features/chat/performance/adaptive_effects_provider.dart';
import 'package:Vista/features/chat/performance/chat_performance_profile.dart';
import 'package:Vista/features/chat/performance/frame_budget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdaptiveEffectsController', () {
    test('defaults to high effects when performance is healthy', () {
      final service = FrameBudgetService.instance;
      service.stopMonitoring();
      service.profileNotifier.value = ChatPerformanceProfile.high;
      service.snapshotNotifier.value = const FrameBudgetSnapshot(
        p50Ms: 8.0,
        p95Ms: 14.0,
        p99Ms: 18.0,
        jankRatio: 0.01,
        sampleCount: 120,
      );

      final controller = AdaptiveEffectsController(service);
      addTearDown(controller.dispose);

      expect(controller.state.effectsLevel, ChatEffectsLevel.high);
      expect(controller.state.allowHeavyBlur, isTrue);
      expect(controller.state.enableMessageEntryAnimation, isTrue);
    });

    test('disables heavy visuals when dynamic effects setting is off', () {
      final service = FrameBudgetService.instance;
      service.stopMonitoring();
      service.profileNotifier.value = ChatPerformanceProfile.high;
      service.snapshotNotifier.value = const FrameBudgetSnapshot(
        p50Ms: 9.0,
        p95Ms: 15.0,
        p99Ms: 20.0,
        jankRatio: 0.01,
        sampleCount: 120,
      );

      final controller = AdaptiveEffectsController(service);
      addTearDown(controller.dispose);
      controller.applySettings(
        rendering: {
          'dynamic_effects': false,
          'max_blur_sigma': 1.5,
        },
        animations: {
          'chat_entry_mode': 'off',
        },
      );

      expect(controller.state.dynamicEffectsEnabled, isFalse);
      expect(controller.state.chatEntryMode, ChatEntryAnimationMode.off);
      expect(controller.state.enableMessageEntryAnimation, isFalse);
      expect(controller.state.blurSigma, lessThanOrEqualTo(1.5));
    });

    test('switches to low profile under poor frame budget and fast scroll', () {
      final service = FrameBudgetService.instance;
      service.stopMonitoring();
      service.profileNotifier.value = ChatPerformanceProfile.low;
      service.snapshotNotifier.value = const FrameBudgetSnapshot(
        p50Ms: 16.0,
        p95Ms: 28.0,
        p99Ms: 35.0,
        jankRatio: 0.12,
        sampleCount: 120,
      );

      final controller = AdaptiveEffectsController(service);
      addTearDown(controller.dispose);
      controller.updateScrollVelocity(3200);

      expect(controller.state.profile, ChatPerformanceProfile.low);
      expect(controller.state.effectsLevel, ChatEffectsLevel.low);
      expect(controller.state.isFastScrolling, isTrue);
      expect(controller.state.chatEntryMode, ChatEntryAnimationMode.off);
      expect(controller.state.allowHeavyBlur, isFalse);
    });

    test('respects rollout flags and can disable motion tokens', () {
      final service = FrameBudgetService.instance;
      service.stopMonitoring();
      service.profileNotifier.value = ChatPerformanceProfile.low;
      service.snapshotNotifier.value = const FrameBudgetSnapshot(
        p50Ms: 14.0,
        p95Ms: 30.0,
        p99Ms: 42.0,
        jankRatio: 0.2,
        sampleCount: 120,
      );

      final controller = AdaptiveEffectsController(service);
      addTearDown(controller.dispose);
      controller.applySettings(
        featureFlags: {
          'chat_perf_v1': false,
          'adaptive_effects_v1': false,
          'motion_tokens_v1': false,
        },
      );
      controller.updateScrollVelocity(3200);

      expect(controller.state.chatPerfEnabled, isFalse);
      expect(controller.state.adaptiveEffectsRolloutEnabled, isFalse);
      expect(controller.state.motionTokensEnabled, isFalse);
      expect(controller.state.effectsLevel, ChatEffectsLevel.high);
      expect(controller.state.chatEntryMode, ChatEntryAnimationMode.full);
      expect(controller.state.isFastScrolling, isFalse);
    });
  });
}
