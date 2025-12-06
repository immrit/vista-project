// PHASE 3: ADVANCED MEDIA MANAGEMENT - IMPLEMENTATION SUMMARY
// ============================================================
//
// ✅ COMPLETED: VoicePlayerService singleton created
// ⏳ IN PROGRESS: Integrate with VoiceMessageBubble widget
// 📋 NEXT: Test and validate implementation
//
// ============================================================
// FILE: lib/services/voice_player_service.dart
// ============================================================
//
// This is the COMPLETE, READY-TO-USE implementation:
//
import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// State model for voice player UI
class VoicePlayerState {
  final String? playingMessageId;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration totalDuration;

  VoicePlayerState({
    this.playingMessageId,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
  });

  VoicePlayerState copyWith({
    String? playingMessageId,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? totalDuration,
  }) {
    return VoicePlayerState(
      playingMessageId: playingMessageId ?? this.playingMessageId,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}

/// Centralized voice player service - Singleton pattern
/// Single AudioPlayer instance manages all voice message playback
class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();

  factory VoicePlayerService() => _instance;

  VoicePlayerService._internal();

  late final AudioPlayer _audioPlayer;
  late final StreamController<VoicePlayerState> _stateController;

  Stream<VoicePlayerState> get playerStateStream => _stateController.stream;

  bool _initialized = false;
  VoicePlayerState _currentState = VoicePlayerState();

  void init() {
    if (_initialized) return;

    _audioPlayer = AudioPlayer();
    _stateController = StreamController<VoicePlayerState>.broadcast();

    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      if (processingState == ProcessingState.completed) {
        _stop();
      } else {
        _updateState(
          isPlaying: isPlaying,
          isLoading: processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering,
        );
      }
    });

    _audioPlayer.positionStream.listen((position) {
      _updateState(position: position);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _updateState(totalDuration: duration);
      }
    });

    _initialized = true;
  }

  Future<void> playOrPause(String messageId, String url) async {
    if (!_initialized) init();

    if (_currentState.playingMessageId == messageId) {
      if (_currentState.isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } else {
      await _playNewAudio(messageId, url);
    }
  }

  Future<void> _playNewAudio(String messageId, String url) async {
    try {
      _updateState(
        playingMessageId: messageId,
        isLoading: true,
        isPlaying: false,
        position: Duration.zero,
      );

      try {
        await _audioPlayer.stop();
      } catch (e) {
        // Ignore
      }

      final source = LockCachingAudioSource(Uri.parse(url));
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
    } catch (e) {
      await _stop();
    }
  }

  Future<void> stop() async {
    await _stop();
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // Ignore
    }

    _updateState(
      playingMessageId: null,
      isPlaying: false,
      isLoading: false,
      position: Duration.zero,
    );
  }

  Future<void> seek(double percent) async {
    if (!_initialized) return;

    if (_currentState.totalDuration.inMilliseconds > 0) {
      final position = Duration(
        milliseconds:
            (_currentState.totalDuration.inMilliseconds * percent).toInt(),
      );
      await _audioPlayer.seek(position);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (!_initialized) return;
    await _audioPlayer.setSpeed(speed);
  }

  void _updateState({
    String? playingMessageId,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? totalDuration,
  }) {
    _currentState = _currentState.copyWith(
      playingMessageId: playingMessageId,
      isPlaying: isPlaying,
      isLoading: isLoading,
      position: position,
      totalDuration: totalDuration,
    );
    _stateController.add(_currentState);
  }

  void dispose() {
    if (_initialized) {
      _audioPlayer.dispose();
      _stateController.close();
      _initialized = false;
    }
  }
}


// ============================================================
// HOW TO USE IN VoiceMessageBubble:
// ============================================================
//
// 1. ADD MESSAGEDETAILED PARAMETER TO WIDGET:
//    final String messageId;  // Add to VoiceMessageBubble properties
//
// 2. IN STATE CLASS initState():
//    late final VoicePlayerService _playerService = VoicePlayerService();
//    
//    @override
//    void initState() {
//      super.initState();
//      _playerService.init();
//    }
//
// 3. REPLACE ENTIRE build() WITH StreamBuilder:
//    @override
//    Widget build(BuildContext context) {
//      return StreamBuilder<VoicePlayerState>(
//        stream: _playerService.playerStateStream,
//        builder: (context, snapshot) {
//          final playerState = snapshot.data ?? VoicePlayerState();
//          final isPlayingThis = playerState.playingMessageId == widget.messageId;
//          final isPlaying = isPlayingThis && playerState.isPlaying;
//          final isLoading = isPlayingThis && playerState.isLoading;
//          
//          // Your existing UI code here, using isPlaying and isLoading
//          return RepaintBoundary(
//            child: Container(
//              // ... UI code ...
//            ),
//          );
//        },
//      );
//    }
//
// 4. UPDATE PLAY/PAUSE BUTTON LOGIC:
//    Future<void> _togglePlayPause(String url) async {
//      final playUrl = _localFilePath ?? url;
//      await _playerService.playOrPause(widget.messageId, playUrl);
//    }
//
// 5. UPDATE SEEK LOGIC:
//    void _seekToPosition(double progress) {
//      _playerService.seek(progress);
//    }
//
// 6. UPDATE PLAYBACK SPEED:
//    void _changePlaybackSpeed() {
//      // ... existing speed cycling code ...
//      await _playerService.setPlaybackSpeed(_playbackSpeed);
//    }
//
// ============================================================
// KEY ARCHITECTURAL BENEFITS:
// ============================================================
//
// ✅ SINGLE INSTANCE: One AudioPlayer for entire app
// ✅ MEMORY EFFICIENT: No per-message AudioPlayer instances
// ✅ REACTIVE UI: StreamBuilder auto-updates when service state changes
// ✅ SIMPLE STATE: Only 5 properties in VoicePlayerState
// ✅ STREAM-BASED: Works with Dart streams (no rxdart needed)
// ✅ SINGLETON SAFE: Factory constructor ensures single instance
// ✅ BROADCAST STREAM: Multiple widgets can listen simultaneously
//
// ============================================================
// STATUS: READY FOR INTEGRATION
// ============================================================
