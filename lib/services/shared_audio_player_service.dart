import 'package:just_audio/just_audio.dart';

/// Shared app-wide audio player instance.
/// just_audio_background supports a single active player, so chat voice
/// and post music must use the same AudioPlayer.
class SharedAudioPlayerService {
  SharedAudioPlayerService._();

  static final SharedAudioPlayerService instance = SharedAudioPlayerService._();

  final AudioPlayer player = AudioPlayer();
}
