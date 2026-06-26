import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:Vista/core/theme/app_theme.dart';

// ─── Public result ────────────────────────────────────────────────────────────

class MusicTrimResult {
  final Duration start;
  final Duration end;
  final bool backgroundMode;
  const MusicTrimResult({
    required this.start,
    required this.end,
    required this.backgroundMode,
  });
}

// ─── Entry point ──────────────────────────────────────────────────────────────

Future<MusicTrimResult?> showMusicTrimSheet(
  BuildContext context, {
  required File file,
  required String title,
  Duration initialStart = Duration.zero,
  Duration? initialEnd,
  bool initialBackgroundMode = false,
}) {
  return showModalBottomSheet<MusicTrimResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _MusicTrimSheet(
      file: file,
      title: title,
      initialStart: initialStart,
      initialEnd: initialEnd,
      initialBackgroundMode: initialBackgroundMode,
    ),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _MusicTrimSheet extends StatefulWidget {
  final File file;
  final String title;
  final Duration initialStart;
  final Duration? initialEnd;
  final bool initialBackgroundMode;

  const _MusicTrimSheet({
    required this.file,
    required this.title,
    required this.initialStart,
    this.initialEnd,
    required this.initialBackgroundMode,
  });

  @override
  State<_MusicTrimSheet> createState() => _MusicTrimSheetState();
}

class _MusicTrimSheetState extends State<_MusicTrimSheet>
    with SingleTickerProviderStateMixin {
  // ── Audio ─────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoaded = false;

  // ── Trim: "bracket slides over fixed waveform" ────────────────────────────
  // _startFrac ∈ [0, _maxStartFrac]  —  bracket left edge as fraction of waveform
  double _startFrac = 0.0;
  Duration _clipDuration = const Duration(seconds: 30);

  double get _clipFrac =>
      _duration > Duration.zero
          ? (_clipDuration.inMilliseconds / _duration.inMilliseconds)
                .clamp(0.0, 1.0)
          : 1.0;

  Duration get _trimStart => Duration(
      milliseconds: (_startFrac * _duration.inMilliseconds).round());

  Duration get _trimEnd {
    final e = _trimStart + _clipDuration;
    return e > _duration ? _duration : e;
  }

  // ── Drag state ────────────────────────────────────────────────────────────
  // Store viewport width so drag handler can convert px → frac
  double _viewW = 1.0;

  // ── Mode ──────────────────────────────────────────────────────────────────
  bool _backgroundMode = false;

  // ── Waveform bars (seeded random, computed once) ──────────────────────────
  // Fixed 120 bars regardless of song length; painter scales them to viewW
  static const int _kBarCount = 120;
  static final List<double> _kBars = List.generate(_kBarCount, (i) {
    final r = Random(i * 43 + 11);
    // slightly lower at edges for realistic look
    final edge = (i < 10 || i > _kBarCount - 11) ? 0.20 : 0.0;
    return (edge + r.nextDouble() * (1.0 - edge)).clamp(0.08, 1.0);
  });

  // ── Disc rotation ─────────────────────────────────────────────────────────
  late final AnimationController _rotCtrl;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _backgroundMode = widget.initialBackgroundMode;
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Register streams before async work so they're always active
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      // Auto-stop at trim end
      if (_isPlaying && pos >= _trimEnd) {
        _player.pause();
        _player.seek(_trimStart);
        if (mounted) setState(() => _isPlaying = false);
      }
    });
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    
    _player.durationStream.listen((dur) {
      if (!mounted || dur == null || dur <= Duration.zero) return;
      if (_duration <= Duration.zero) {
        _initializeTrim(dur);
      }
    });

    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      String audioPath = widget.file.path;
      
      // On Windows and Android, Media Foundation / ExoPlayer rely heavily on file extensions 
      // to sniff the format. FilePicker sometimes returns files without extensions.
      // If there's no extension (or a very long extension which means it's not a real extension),
      // we copy it to a temporary .mp3 file to ensure decoding works.
      final extensionIndex = audioPath.lastIndexOf('.');
      if (extensionIndex == -1 || audioPath.length - extensionIndex > 5) {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await widget.file.copy(tempFile.path);
        audioPath = tempFile.path;
      }

      // Using setFilePath is the most robust method for local files in just_audio
      final dur = await _player.setFilePath(audioPath) ?? _player.duration;
      if (!mounted) return;
      
      if (dur != null && dur > Duration.zero) {
        _initializeTrim(dur);
      } else {
        setState(() => _isLoaded = true);
      }
    } catch (e) {
      debugPrint('MusicTrimSheet: audio load error: $e');
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  void _initializeTrim(Duration dur) {
    if (_duration > Duration.zero) return; // Already initialized
    
    final clip = dur < const Duration(seconds: 30) ? dur : const Duration(seconds: 30);
    final initEnd = widget.initialEnd;
    final restoredClip =
        (initEnd != null && initEnd > widget.initialStart)
            ? initEnd - widget.initialStart
            : clip;

    double startFrac = dur.inMilliseconds > 0
        ? widget.initialStart.inMilliseconds / dur.inMilliseconds
        : 0.0;

    final clipFracNow = restoredClip.inMilliseconds / dur.inMilliseconds;
    final maxFrac = (1.0 - clipFracNow).clamp(0.0, 1.0);
    startFrac = startFrac.clamp(0.0, maxFrac);

    setState(() {
      _duration = dur;
      _clipDuration = restoredClip;
      _startFrac = startFrac;
      _isLoaded = true;
    });
  }

  // ── Drag logic ────────────────────────────────────────────────────────────

  void _onPanUpdate(double dx) {
    if (_viewW <= 0 || _duration <= Duration.zero) return;
    final bracketW = _viewW * _clipFrac;
    final maxOffsetPx = _viewW - bracketW;
    if (maxOffsetPx <= 0) return; // entire song selected, can't scroll
    final currentOffsetPx = _startFrac * maxOffsetPx;
    final newOffsetPx = (currentOffsetPx + dx).clamp(0.0, maxOffsetPx);
    setState(() => _startFrac = newOffsetPx / maxOffsetPx);
    if (_isPlaying) _player.seek(_trimStart);
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final pos = _position;
      if (pos < _trimStart || pos >= _trimEnd) {
        await _player.seek(_trimStart);
      }
      await _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _rotCtrl.dispose();
    super.dispose();
  }

  // ── Format ────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 4),
            _buildHeader(),
            const SizedBox(height: 28),
            if (!_isLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: CircularProgressIndicator(
                  color: AppColors.secondary,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildWaveform(),
              ),
              const SizedBox(height: 12),
              _buildTimeRow(),
              const SizedBox(height: 24),
              _buildPlayRow(),
            ],
            const SizedBox(height: 28),
            _buildDivider(),
            const SizedBox(height: 18),
            _buildModeRow(),
            const SizedBox(height: 22),
            _buildConfirmButton(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
      child: Row(
        children: [
          RotationTransition(
            turns: _rotCtrl,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.secondary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'انتخاب بخش موزیک',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.35), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// The core interaction: waveform fixed, bracket slides left/right.
  Widget _buildWaveform() {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // Store viewport width for drag handler
        if (w > 0) _viewW = w;

        final bracketW = (w * _clipFrac).clamp(0.0, w);
        final bracketX = _startFrac * (w - bracketW);
        final playheadFrac = _duration > Duration.zero
            ? (_position.inMilliseconds / _duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;
        final endFrac = (_startFrac + _clipFrac).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _onPanUpdate(d.delta.dx),
          child: SizedBox(
            height: 80,
            width: w,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Waveform bars (full width, fixed)
                CustomPaint(
                  size: Size(w, 80),
                  painter: _WaveformPainter(
                    bars: _kBars,
                    bracketStartFrac: _startFrac,
                    bracketEndFrac: endFrac,
                    selectedColor:
                        AppColors.secondary.withValues(alpha: 0.80),
                    dimColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

                // Bracket overlay (slides)
                Positioned(
                  left: bracketX,
                  width: bracketW,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.75),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),

                // Left handle (grab indicator)
                Positioned(
                  left: bracketX,
                  width: 16,
                  top: 10,
                  bottom: 10,
                  child: _BracketHandle(left: true),
                ),

                // Right handle
                Positioned(
                  left: bracketX + bracketW - 16,
                  width: 16,
                  top: 10,
                  bottom: 10,
                  child: _BracketHandle(left: false),
                ),

                // Playhead (only while playing, within bracket)
                if (_isPlaying &&
                    playheadFrac >= _startFrac &&
                    playheadFrac <= endFrac)
                  Positioned(
                    left: playheadFrac * w,
                    top: 4,
                    bottom: 4,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _fmt(_trimStart),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '← بکش انتخاب کن →',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 11,
            ),
          ),
          Text(
            _fmt(_trimEnd),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayRow() {
    final posStr = _fmt(_position);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play / Pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              posStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'از ${_fmt(_duration)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.07),
        ),
      );

  Widget _buildModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نمایش در پست',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  icon: Icons.library_music_rounded,
                  label: 'حباب موزیک',
                  selected: !_backgroundMode,
                  color: AppColors.secondary,
                  onTap: () => setState(() => _backgroundMode = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeChip(
                  icon: Icons.image_rounded,
                  label: 'پس‌زمینه',
                  selected: _backgroundMode,
                  color: AppColors.accent,
                  onTap: () => setState(() => _backgroundMode = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.accent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.pop(
                context,
                MusicTrimResult(
                  start: _trimStart,
                  end: _trimEnd,
                  backgroundMode: _backgroundMode,
                ),
              ),
              child: const Center(
                child: Text(
                  'تایید',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Waveform painter ─────────────────────────────────────────────────────────
//
// Draws fixed-width bars across [size.width].
// Bars within [bracketStartFrac, bracketEndFrac] are highlighted.
// No scrolling — the bracket slides, not the waveform.

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double bracketStartFrac;
  final double bracketEndFrac;
  final Color selectedColor;
  final Color dimColor;

  const _WaveformPainter({
    required this.bars,
    required this.bracketStartFrac,
    required this.bracketEndFrac,
    required this.selectedColor,
    required this.dimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selPaint = Paint()..color = selectedColor;
    final dimPaint = Paint()..color = dimColor;
    const rr = Radius.circular(2.5);
    final count = bars.length;
    final barW = size.width / count * 0.62; // 62% bar, 38% gap

    for (int i = 0; i < count; i++) {
      final frac = i / count;
      final x = frac * size.width;
      final h = size.height * 0.88 * bars[i];
      final top = (size.height - h) / 2;
      final inBracket = frac >= bracketStartFrac && frac < bracketEndFrac;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barW, h), rr),
        inBracket ? selPaint : dimPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter o) =>
      o.bracketStartFrac != bracketStartFrac ||
      o.bracketEndFrac != bracketEndFrac;
}

// ─── Bracket handle (left / right edge pill) ──────────────────────────────────

class _BracketHandle extends StatelessWidget {
  final bool left;
  const _BracketHandle({required this.left});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Mode chip ────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? color
                  : Colors.white.withValues(alpha: 0.28),
              size: 16,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? color
                      : Colors.white.withValues(alpha: 0.32),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
