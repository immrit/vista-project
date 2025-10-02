import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Uint8List? audioBytes;
  final List<double>? waveformData;
  final bool isMe;
  final bool isPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.audioBytes,
    this.waveformData,
    required this.isMe,
    this.isPreview = false,
    this.onDelete,
    this.onReply,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final PlayerController _playerController;
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();
    _preparePlayer();
    _playerStateSubscription =
        _playerController.onPlayerStateChanged.listen((_) {
      setState(() {});
    });
  }

  Future<void> _preparePlayer() async {
    try {
      if (widget.audioBytes != null) {
        // For local previews before upload
        await _playerController.preparePlayer(
          path: widget.audioUrl, // Assuming path is available for previews
          shouldExtractWaveform: widget.waveformData == null,
        );
      } else {
        // For network audio files
        await _playerController.preparePlayer(
          path: widget.audioUrl,
          shouldExtractWaveform: widget.waveformData == null,
        );
        // Note: updateWaveform method is not available in current audio_waveforms version
        // if (widget.waveformData != null && widget.waveformData!.isNotEmpty) {
        //    _playerController.updateWaveform(widget.waveformData!);
        // }
      }
    } catch (e) {
      print("Error preparing player: $e");
      // Optionally handle error state in UI
    }
  }

  Future<void> _playPause() async {
    if (_playerController.playerState.isPlaying) {
      await _playerController.pausePlayer();
    } else {
      await _playerController.startPlayer();
    }
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _playPause,
            icon: Icon(
              _playerController.playerState.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            color: textColor,
            splashColor: textColor.withOpacity(0.2),
          ),
          Expanded(
            child: AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width, 40.0),
              playerController: _playerController,
              enableSeekGesture: true,
              waveformType: WaveformType.long,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: textColor.withOpacity(0.3),
                liveWaveColor: textColor,
                spacing: 6.0,
                showSeekLine: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<PlayerState>(
            stream: _playerController.onPlayerStateChanged,
            builder: (context, snapshot) {
              final state = snapshot.data ?? _playerController.playerState;
              return Text(
                _formatDuration(
                  state.isStopped || state.isInitialised
                      ? _playerController.maxDuration
                      : _playerController
                          .maxDuration, // Using maxDuration as fallback
                ),
                style: TextStyle(color: textColor, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? millis) {
    if (millis == null) return "00:00";
    final duration = Duration(milliseconds: millis);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
