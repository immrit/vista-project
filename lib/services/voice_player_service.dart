import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Centralized voice player service using just_audio.
/// Replaces per-widget AudioPlayer instances with a single shared player.
class VoicePlayerState {
  final String? voiceId;
  final bool isPlaying;
  final bool isLoading;
  final Duration duration;
  final Duration position;
  final double speed;

  const VoicePlayerState({
    this.voiceId,
    required this.isPlaying,
    required this.isLoading,
    required this.duration,
    required this.position,
    required this.speed,
  });

  factory VoicePlayerState.initial() => const VoicePlayerState(
        voiceId: null,
        isPlaying: false,
        isLoading: false,
        duration: Duration.zero,
        position: Duration.zero,
        speed: 1.0,
      );

  VoicePlayerState copyWith({
    String? voiceId,
    bool? isPlaying,
    bool? isLoading,
    Duration? duration,
    Duration? position,
    double? speed,
  }) {
    return VoicePlayerState(
      voiceId: voiceId ?? this.voiceId,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      speed: speed ?? this.speed,
    );
  }
}

class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();
  factory VoicePlayerService() => _instance;
  VoicePlayerService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final BehaviorSubject<VoicePlayerState> _stateController =
      BehaviorSubject.seeded(VoicePlayerState.initial());

  Stream<VoicePlayerState> get playerStateStream => _stateController.stream;
  VoicePlayerState get latestState => _stateController.value;

  String? _currentVoiceId;
  bool _isPreparing = false;

  void _init() {
    // Listen to player streams and broadcast consolidated state
    _player.playerStateStream.listen((playerState) {
      _broadcastState();

      // Haptic on start
      if (playerState.playing) {
        HapticFeedback.lightImpact();
      }

      // auto-reset when completed
      if (playerState.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });

    _player.durationStream.listen((d) => _broadcastState());
    _player.positionStream.listen((p) => _broadcastState());
  }

  void _broadcastState() {
    final state = VoicePlayerState(
      voiceId: _currentVoiceId,
      isPlaying: _player.playing,
      isLoading: _isPreparing,
      duration: _player.duration ?? Duration.zero,
      position: _player.position,
      speed: _player.speed,
    );
    if (!_stateController.isClosed) _stateController.add(state);
  }

  /// Toggles play / pause for given voiceId. If a different voiceId is
  /// requested, the previous one will be stopped and the new one prepared.
  Future<void> playOrPause(String voiceId, String url) async {
    try {
      // If a different voice is requested, stop current and prepare new
      if (_currentVoiceId != voiceId) {
        await _player.stop();
        _currentVoiceId = voiceId;
        _isPreparing = true;
        _broadcastState();

        // Try to set audio source. For simplicity, use uri; local file paths are supported.
        final uri = Uri.parse(url);
        await _player.setAudioSource(AudioSource.uri(uri));

        _isPreparing = false;
        _broadcastState();
        await _player.play();
        return;
      }

      // same voiceId: toggle
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e, st) {
      // If anything fails, clear preparing flag and broadcast
      _isPreparing = false;
      _broadcastState();
      // preserve crash info in logs only (avoid throwing unless caller needs it)
      // ignore: avoid_print
      print('VoicePlayerService.playOrPause error: $e\n$st');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentVoiceId = null;
    _broadcastState();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}

// Convenience singleton accessor
VoicePlayerService get voicePlayerService => VoicePlayerService();
