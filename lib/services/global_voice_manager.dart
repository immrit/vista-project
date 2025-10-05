import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// مدیریتگر جهانی وویس برای جلوگیری از پخش همزمان چندین وویس
class GlobalVoiceManager {
  static final GlobalVoiceManager _instance = GlobalVoiceManager._internal();
  factory GlobalVoiceManager() => _instance;
  GlobalVoiceManager._internal();

  AudioPlayer? _currentPlayer;
  String? _currentVoiceId;
  StreamSubscription? _playerStateSubscription;

  /// شروع پخش وویس جدید
  Future<void> playVoice(String voiceId, AudioPlayer player) async {
    // توقف وویس قبلی اگر در حال پخش است
    if (_currentPlayer != null && _currentPlayer != player) {
      await _currentPlayer!.stop();
      print('🔇 Stopped previous voice: $_currentVoiceId');
    }

    _currentPlayer = player;
    _currentVoiceId = voiceId;

    // تنظیم listener برای تشخیص پایان پخش
    _playerStateSubscription?.cancel();
    _playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _currentPlayer = null;
        _currentVoiceId = null;
        print('🎵 Voice playback completed: $voiceId');
      }
    });

    print('🎵 Started playing voice: $voiceId');
  }

  /// توقف وویس فعلی
  Future<void> stopCurrentVoice() async {
    if (_currentPlayer != null) {
      await _currentPlayer!.stop();
      print('🔇 Stopped current voice: $_currentVoiceId');
      _currentPlayer = null;
      _currentVoiceId = null;
    }
    _playerStateSubscription?.cancel();
  }

  /// بررسی اینکه آیا وویس خاص در حال پخش است
  bool isPlaying(String voiceId) {
    return _currentVoiceId == voiceId && _currentPlayer != null;
  }

  /// دریافت وویس فعلی در حال پخش
  String? get currentVoiceId => _currentVoiceId;

  /// پاکسازی منابع
  void dispose() {
    _playerStateSubscription?.cancel();
    _currentPlayer = null;
    _currentVoiceId = null;
    print('🧹 GlobalVoiceManager disposed');
  }
}

