import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../performance/adaptive_effects_provider.dart';
import '../performance/chat_performance_profile.dart';

typedef ChatAdaptiveBlurBuilder = Widget Function(
  BuildContext context,
  double blurSigma,
  bool allowHeavyBlur,
  ChatEffectsLevel effectsLevel,
);

/// Rebuilds only when blur/effects-level settings change — not on scroll velocity.
class ChatAdaptiveBlurScope extends ConsumerWidget {
  const ChatAdaptiveBlurScope({
    super.key,
    required this.builder,
  });

  final ChatAdaptiveBlurBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      adaptiveEffectsProvider.select(
        // allowHeavyBlur intentionally excluded: it's velocity-driven and would cause
        // a rebuild on every fast-scroll threshold crossing. The blur on/off during
        // scroll is already handled by _isScrollingNotifier at the call site.
        // allowHeavyBlur is derived from effectsLevel: high ↔ heavy blur allowed.
        (state) => (
          state.blurSigma,
          state.effectsLevel,
        ),
      ),
    );

    // effectsLevel==high already implies gpuEnabled && !reduceMotion (those degrade
    // effectsLevel), so this derivation is equivalent to the original allowHeavyBlur
    // minus the isFastScrolling factor (which is handled by _isScrollingNotifier).
    final allowHeavyBlur = config.$2 == ChatEffectsLevel.high;

    return builder(
      context,
      config.$1,
      allowHeavyBlur,
      config.$2,
    );
  }
}
