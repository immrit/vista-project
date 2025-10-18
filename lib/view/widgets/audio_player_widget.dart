import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';

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
  late final AudioPlayer _audioPlayer;
  late final PlayerController _waveformController;

  bool _isInitialized = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _waveformController = PlayerController();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print("🎵 AudioPlayerWidget: Preparing player for ${widget.audioUrl}");

      // چک کردن URL
      if (widget.audioUrl.isEmpty) {
        throw Exception('URL فایل صوتی خالی است');
      }

      // تنظیم listeners برای just_audio
      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _totalDuration = duration;
          });
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      _audioPlayer.playerStateStream.listen((playerState) {
        if (mounted) {
          setState(() {
            _isPlaying = playerState.playing;
          });
        }
      });

      // آماده‌سازی فایل صوتی
      await _audioPlayer.setUrl(widget.audioUrl);

      // انتظار برای بارگذاری کامل
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isInitialized = true;
      });

      print("🎵 AudioPlayerWidget: Player prepared successfully");
    } catch (e) {
      print("❌ AudioPlayerWidget: Error preparing player: $e");
      // Error preparing player
      // Optionally handle error state in UI
    }
  }

  Future<void> _playPause() async {
    try {
      print("🎵 AudioPlayerWidget: Play/Pause button pressed");
      print(
          "🎵 AudioPlayerWidget: Current state: ${_isPlaying ? 'playing' : 'paused'}");

      // چک کردن وضعیت پلیر
      if (!_isInitialized) {
        print("⚠️ AudioPlayerWidget: Player not initialized, preparing...");
        await _initializePlayer();
        return;
      }

      if (_isPlaying) {
        print("⏸️ AudioPlayerWidget: Pausing audio");
        await _audioPlayer.pause();
      } else {
        print("▶️ AudioPlayerWidget: Starting audio");
        await _audioPlayer.play();
      }

      print("✅ AudioPlayerWidget: Play/Pause operation completed");
    } catch (e) {
      print("❌ AudioPlayerWidget: Error in play/pause: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.grey.shade800);

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
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            color: textColor,
            splashColor: textColor.withValues(alpha: 0.2),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  // Background progress bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Progress indicator
                  Container(
                    height: 4,
                    width: _totalDuration.inMilliseconds > 0
                        ? (MediaQuery.of(context).size.width * 0.4) *
                            (_currentPosition.inMilliseconds /
                                _totalDuration.inMilliseconds)
                        : 0,
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_totalDuration),
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
