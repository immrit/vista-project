import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../provider/MusicProvider.dart';
import '../Music/MusicDownloadManager.dart';

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
  bool _isDownloading = false;
  bool _showDownloadButton = false;

  @override
  void initState() {
    super.initState();
    _waveformAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _generateWaveform();
    _setupPlaybackListeners();
    _checkDownloadStatus();
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

  Future<void> _checkDownloadStatus() async {
    if (kIsWeb) return;

    final downloadManager = ref.read(musicDownloadManagerProvider.notifier);
    final isDownloaded = downloadManager.isDownloaded(widget.musicUrl);

    if (mounted) {
      setState(() {
        _showDownloadButton = !isDownloaded;
      });
    }
  }

  Future<void> _handlePlayPause() async {
    if (_isDownloading) return;

    final downloadManager = ref.read(musicDownloadManagerProvider.notifier);
    final isDownloaded = downloadManager.isDownloaded(widget.musicUrl);

    if (!isDownloaded && !kIsWeb) {
      // برای پخش، نیاز به دانلود نیست، اما برای اطمینان
      // فایل را در حافظه موقت ذخیره می‌کنیم
      final tempDir = await getTemporaryDirectory();
      final filename = widget.musicUrl.split('/').last;
      final localPath = '${tempDir.path}/$filename';

      if (!File(localPath).existsSync()) {
        setState(() => _isDownloading = true);

        await downloadManager.downloadMusic(
          widget.musicUrl,
          onProgress: (progress) {
            // می‌توان حالت پیشرفت دانلود را نمایش داد
          },
        );

        if (mounted) {
          setState(() => _isDownloading = false);
        }
      }
    }

    widget.onPlayPause?.call();
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);
    debugPrint('شروع دانلود از MusicWaveform: ${widget.musicUrl}');

    try {
      final downloadManager = ref.read(musicDownloadManagerProvider.notifier);

      // نمایش شروع دانلود
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('در حال دانلود فایل...'),
          duration: Duration(seconds: 2),
        ),
      );

      final filePath = await downloadManager.downloadMusic(
        widget.musicUrl,
        onProgress: (progress) {
          debugPrint('پیشرفت دانلود: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      if (filePath != null) {
        debugPrint('دانلود با موفقیت انجام شد: $filePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'فایل با موفقیت دانلود شد و در "${filePath.split('/').last}" ذخیره شد'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'فهمیدم',
                onPressed: () {},
              ),
            ),
          );

          setState(() {
            _showDownloadButton = false;
          });
        }
      } else {
        debugPrint('خطا در دانلود فایل: مسیر خالی برگشت داده شد');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در دانلود فایل'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('خطا در دانلود: $e');
      debugPrint('جزئیات خطا: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در دانلود: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
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

    if (widget.musicUrl != oldWidget.musicUrl) {
      _checkDownloadStatus();
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

    // نمایش وضعیت دانلود
    final downloadInfo =
        ref.watch(musicDownloadManagerProvider)[widget.musicUrl];
    final isDownloading = downloadInfo?.status == DownloadStatus.downloading;
    final downloadProgress = downloadInfo?.progress ?? 0.0;

    return Container(
      height: 60,
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
                    final width = constraints.maxWidth - 120; // تنظیم عرض
                    final dx =
                        (details.localPosition.dx - 50).clamp(0.0, width);
                    final progress = dx / width;
                    if (widget.duration != null) {
                      final newPosition = widget.duration! * progress;
                      ref.read(musicPlayerProvider.notifier).seek(newPosition);
                    }
                  },
                  onTapDown: (details) {
                    final width = constraints.maxWidth - 120; // تنظیم عرض
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
                            size: Size(
                                constraints.maxWidth - 120, 40), // تنظیم عرض
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
                      // دکمه دانلود
                      if (_showDownloadButton && !kIsWeb)
                        _buildDownloadButton(
                            context, isDownloading, downloadProgress),
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
        // color: Theme.of(context).primaryColor,
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
                          // color: Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildDownloadButton(
      BuildContext context, bool isDownloading, double downloadProgress) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloading ? null : _handleDownload,
          borderRadius: BorderRadius.circular(20),
          child: isDownloading
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: downloadProgress,
                      strokeWidth: 2,
                      // valueColor: AlwaysStoppedAnimation<Color>(
                      //   Theme.of(context).primaryColor,
                      // ),
                    ),
                    Text(
                      '${(downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        // color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                )
              : Icon(
                  Icons.download_rounded,
                  // color: Theme.of(context).primaryColor,
                  size: 24,
                ),
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
