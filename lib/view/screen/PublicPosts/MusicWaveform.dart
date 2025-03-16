import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // اضافه کردن این import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../provider/MusicProvider.dart';

class MusicWaveform extends ConsumerStatefulWidget {
  final String musicUrl;
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;
  final Function()? onPlayPause;

  const MusicWaveform({
    super.key,
    required this.musicUrl,
    required this.isPlaying,
    this.position,
    this.duration,
    this.onPlayPause,
  });

  @override
  ConsumerState<MusicWaveform> createState() => _MusicWaveformState();
}

class _MusicWaveformState extends ConsumerState<MusicWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveformAnimation;
  final List<double> _waveform = [];
  bool _isInitialized = false;
  bool _isDownloaded = false;
  String? _localPath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _waveformAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _generateWaveform();
    _setupPlaybackListeners();
    _downloadInBackground();
  }

  void _generateWaveform() {
    if (_isInitialized) return;

    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      double height;
      if (i < 8 || i > 42) {
        height = 0.3 + random.nextDouble() * 0.2;
      } else if (i < 15 || i > 35) {
        height = 0.4 + random.nextDouble() * 0.3;
      } else {
        height = 0.5 + random.nextDouble() * 0.5;
      }
      _waveform.add(height);
    }
    _isInitialized = true;
  }

  void _setupPlaybackListeners() {
    final player = ref.read(audioPlayerProvider);

    player.playingStream.listen((playing) {
      if (mounted) {
        setState(() {});
      }
    });

    player.positionStream.listen((position) {
      if (mounted) {
        setState(() {});
      }
    });

    player.durationStream.listen((duration) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _downloadInBackground() async {
    if (kIsWeb) {
      // در نسخه وب، نیازی به دانلود نیست
      setState(() => _isDownloaded = true);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filename = widget.musicUrl.split('/').last;
      _localPath = '${tempDir.path}/$filename';

      if (!File(_localPath!).existsSync()) {
        final response = await http.get(Uri.parse(widget.musicUrl));
        await File(_localPath!).writeAsBytes(response.bodyBytes);
      }

      if (mounted) {
        setState(() => _isDownloaded = true);
      }
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      // در صورت خطا هم اجازه پخش می‌دهیم
      setState(() => _isDownloaded = true);
    }
  }

  Future<void> _handlePlayPause() async {
    if (_isDownloading) return;

    if (kIsWeb) {
      // در نسخه وب مستقیماً پخش می‌کنیم
      widget.onPlayPause?.call();
      return;
    }

    if (!_isDownloaded) {
      setState(() => _isDownloading = true);
      try {
        final downloaded = await _downloadMusic();
        const SnackBar(content: Text('دانلود'));

        if (!downloaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در دانلود موزیک')),
          );
          return;
        }
      } finally {
        if (mounted) {
          setState(() => _isDownloading = false);
        }
      }
    }
    widget.onPlayPause?.call();
  }

  Future<bool> _downloadMusic() async {
    if (_isDownloaded || kIsWeb) return true;

    try {
      final tempDir = await getTemporaryDirectory();
      final filename = widget.musicUrl.split('/').last;
      _localPath = '${tempDir.path}/$filename';

      if (!File(_localPath!).existsSync()) {
        final response = await http.get(Uri.parse(widget.musicUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to download music');
        }
        await File(_localPath!).writeAsBytes(response.bodyBytes);
      }

      if (mounted) {
        setState(() => _isDownloaded = true);
      }
      return true;
    } catch (e) {
      debugPrint('Error downloading music: $e');
      return false;
    }
  }

  void _handleSeek(TapDownDetails details, BoxConstraints constraints) {
    final tapPosition = details.localPosition.dx;
    final fullWidth = constraints.maxWidth;
    final progress = tapPosition / fullWidth;

    if (widget.duration != null) {
      final newPosition = widget.duration! * progress;
      ref.read(musicPlayerProvider.notifier).seek(newPosition);
    }
  }

  @override
  void didUpdateWidget(MusicWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveformAnimation.repeat();
      } else {
        _waveformAnimation.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveformAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final progress = widget.position != null && widget.duration != null
        ? widget.position!.inMilliseconds / widget.duration!.inMilliseconds
        : 0.0;

    return Container(
      height: 55,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.3)
            : Colors.grey[100]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final width = constraints.maxWidth - 80;
                    final dx =
                        (details.localPosition.dx - 50).clamp(0.0, width);
                    final progress = dx / width;
                    if (widget.duration != null) {
                      final newPosition = widget.duration! * progress;
                      ref.read(musicPlayerProvider.notifier).seek(newPosition);
                    }
                  },
                  onTapDown: (details) {
                    final width = constraints.maxWidth - 80;
                    final dx =
                        (details.localPosition.dx - 50).clamp(0.0, width);
                    final progress = dx / width;
                    if (widget.duration != null) {
                      final newPosition = widget.duration! * progress;
                      ref.read(musicPlayerProvider.notifier).seek(newPosition);
                    }
                  },
                  child: Row(
                    children: [
                      _buildPlayButton(context),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: CustomPaint(
                            size: Size(constraints.maxWidth - 80, 40),
                            painter: TelegramWaveformPainter(
                              waveData: _waveform,
                              progress: progress,
                              activeColor: Theme.of(context).primaryColor,
                              inactiveColor: isDarkMode
                                  ? Colors.grey[700]!.withOpacity(0.5)
                                  : Colors.grey[400]!.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      _buildDuration(context),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isDownloading ? null : _handlePlayPause,
          borderRadius: BorderRadius.circular(21),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isDownloading
                ? Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.download,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 16,
                        ),
                      ],
                    ),
                  )
                : Icon(
                    widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                    key: ValueKey(widget.isPlaying),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuration(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 46,
      alignment: Alignment.center,
      child: Text(
        _formatDuration(widget.position ?? Duration.zero),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class TelegramWaveformPainter extends CustomPainter {
  final List<double> waveData;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  TelegramWaveformPainter({
    required this.waveData,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveData.isEmpty) return;

    final barWidth = 2.5;
    final spacing = 2.0;
    final totalBars = waveData.length;
    final availableWidth = size.width;
    final totalSpacing = spacing * (totalBars - 1);
    final effectiveBarWidth = (availableWidth - totalSpacing) / totalBars;
    final progressPoint = size.width * progress;

    var currentX = 0.0;
    for (var i = 0; i < totalBars; i++) {
      final height = waveData[i] * size.height;
      final isPlayed = currentX <= progressPoint;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          currentX,
          (size.height - height) / 2,
          effectiveBarWidth,
          height,
        ),
        const Radius.circular(1),
      );

      if (isPlayed) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = activeColor.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }

      canvas.drawRRect(
        rect,
        Paint()
          ..color = isPlayed ? activeColor : inactiveColor
          ..style = PaintingStyle.fill,
      );

      currentX += effectiveBarWidth + spacing;
    }
  }

  @override
  bool shouldRepaint(TelegramWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
