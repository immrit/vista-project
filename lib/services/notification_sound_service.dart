import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/logging_utility.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();

  factory NotificationSoundService() {
    return _instance;
  }

  NotificationSoundService._internal();

  static NotificationSoundService get instance => _instance;

  final AudioPlayer _sentPlayer = AudioPlayer();
  final AudioPlayer _receivedPlayer = AudioPlayer();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final audioContext = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.media, // Changed from notificationEvent to media
          audioFocus: AndroidAudioFocus.none, // Prevent ducking (lowering background music)
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {
            AVAudioSessionOptions.mixWithOthers
          },
        ),
      );
      
      await _sentPlayer.setAudioContext(audioContext);
      await _receivedPlayer.setAudioContext(audioContext);
      
      await _sentPlayer.setSourceAsset('sounds/message-sent.mp3');
      await _receivedPlayer.setSourceAsset('sounds/message-recive.mp3');
      // Pre-load logic if needed, but setSourceAsset is enough for quick playback usually.
      _initialized = true;
    } catch (e, st) {
      logError('Failed to initialize NotificationSoundService', error: e, stackTrace: st);
    }
  }

  Future<bool> _isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if not set
    return prefs.getBool('in_app_chat_sounds') ?? true;
  }

  Future<void> playMessageSentSound() async {
    try {
      if (!await _isSoundEnabled()) return;
      if (!_initialized) await init();
      
      // Stop current playback to restart it immediately if called multiple times rapidly
      await _sentPlayer.stop();
      await _sentPlayer.play(AssetSource('sounds/message-sent.mp3'), volume: 0.4);
    } catch (e, st) {
      logError('Failed to play message sent sound', error: e, stackTrace: st);
    }
  }

  Future<void> playMessageReceivedSound() async {
    try {
      if (!await _isSoundEnabled()) return;
      if (!_initialized) await init();

      await _receivedPlayer.stop();
      await _receivedPlayer.play(AssetSource('sounds/message-recive.mp3'), volume: 0.4);
    } catch (e, st) {
      logError('Failed to play message received sound', error: e, stackTrace: st);
    }
  }

  void dispose() {
    _sentPlayer.dispose();
    _receivedPlayer.dispose();
  }
}
