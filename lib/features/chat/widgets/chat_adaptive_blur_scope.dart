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
        (state) => (
          state.blurSigma,
          state.allowHeavyBlur,
          state.effectsLevel,
        ),
      ),
    );

    return builder(
      context,
      config.$1,
      config.$2,
      config.$3,
    );
  }
}
