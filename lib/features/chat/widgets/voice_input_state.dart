import 'package:flutter/material.dart';

enum VoiceInputState {
  idle,
  typing,
  recordingHold,
  recordingLocked,
  cancelSwipe,
  previewSend,
}

enum VoiceInputPreset {
  adaptive,
  soft,
  balanced,
  strict,
}

@immutable
class VoiceGestureThresholds {
  final double lockDragDistance;
  final double cancelDragDistance;
  final Duration minRecordDuration;

  const VoiceGestureThresholds({
    this.lockDragDistance = 56,
    this.cancelDragDistance = 96,
    this.minRecordDuration = const Duration(milliseconds: 350),
  });
}

class VoiceGestureThresholdsResolver {
  const VoiceGestureThresholdsResolver._();

  static VoiceGestureThresholds resolve(
    VoiceInputPreset preset, {
    required double devicePixelRatio,
    required double shortestSide,
  }) {
    switch (preset) {
      case VoiceInputPreset.soft:
        return const VoiceGestureThresholds(
          lockDragDistance: 72,
          cancelDragDistance: 124,
          minRecordDuration: Duration(milliseconds: 420),
        );
      case VoiceInputPreset.balanced:
        return const VoiceGestureThresholds(
          lockDragDistance: 56,
          cancelDragDistance: 96,
          minRecordDuration: Duration(milliseconds: 350),
        );
      case VoiceInputPreset.strict:
        return const VoiceGestureThresholds(
          lockDragDistance: 48,
          cancelDragDistance: 84,
          minRecordDuration: Duration(milliseconds: 280),
        );
      case VoiceInputPreset.adaptive:
        if (shortestSide < 390) {
          return const VoiceGestureThresholds(
            lockDragDistance: 70,
            cancelDragDistance: 118,
            minRecordDuration: Duration(milliseconds: 430),
          );
        }
        if (devicePixelRatio >= 3.0 && shortestSide >= 411) {
          return const VoiceGestureThresholds(
            lockDragDistance: 50,
            cancelDragDistance: 88,
            minRecordDuration: Duration(milliseconds: 300),
          );
        }
        return const VoiceGestureThresholds();
    }
  }
}

class VoiceInputStateMachine {
  VoiceInputState _state = VoiceInputState.idle;

  VoiceInputState get state => _state;

  bool get isRecording =>
      _state == VoiceInputState.recordingHold ||
      _state == VoiceInputState.recordingLocked;

  bool get isLocked => _state == VoiceInputState.recordingLocked;

  void setTyping(bool hasText) {
    if (isRecording) return;
    _state = hasText ? VoiceInputState.typing : VoiceInputState.idle;
  }

  void startRecording() {
    _state = VoiceInputState.recordingHold;
  }

  void lockRecording() {
    _state = VoiceInputState.recordingLocked;
  }

  void markCancelSwipe() {
    _state = VoiceInputState.cancelSwipe;
  }

  void markPreviewSend() {
    _state = VoiceInputState.previewSend;
  }

  void reset({bool hasText = false}) {
    _state = hasText ? VoiceInputState.typing : VoiceInputState.idle;
  }
}
