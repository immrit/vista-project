import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_compress/video_compress.dart';
import 'media_editor_result.dart';

class TelegramVideoEditor extends StatefulWidget {
  final File file;
  final String initialCaption;

  const TelegramVideoEditor({
    super.key,
    required this.file,
    this.initialCaption = '',
  });

  @override
  State<TelegramVideoEditor> createState() => _TelegramVideoEditorState();
}

class _TelegramVideoEditorState extends State<TelegramVideoEditor> {
  late final VideoEditorController _controller;
  late final TextEditingController _captionController;
  bool _isExporting = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _controller = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(minutes: 5),
    );
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    VideoCompress.cancelCompression();
    _captionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exportAndSend() async {
    setState(() => _isExporting = true);

    try {
      final startSec = _controller.startTrim.inSeconds;
      final durationSec =
          _controller.endTrim.inSeconds - startSec;

      final info = await VideoCompress.compressVideo(
        widget.file.path,
        quality: VideoQuality.DefaultQuality,
        deleteOrigin: false,
        startTime: startSec,
        duration: durationSec,
        includeAudio: !_isMuted,
      );

      if (!mounted) return;
      if (info?.file != null) {
        Navigator.pop(
          context,
          MediaEditorResult(info!.file!, _captionController.text.trim()),
        );
      } else {
        setState(() => _isExporting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.video.setVolume(_isMuted ? 0 : 1);
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_controller.initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(children: [
          Expanded(child: _buildVideoPreview()),
          _buildBottomControls(),
        ]),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Stack(alignment: Alignment.center, children: [
      GestureDetector(
        onTap: () {
          if (_controller.isPlaying) {
            _controller.video.pause();
          } else {
            _controller.video.play();
          }
        },
        child: CropGridViewer.preview(controller: _controller),
      ),
      if (!_controller.isPlaying)
        Container(
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 52),
        ),
      Positioned(
        top: 12,
        left: 12,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildTopRow(),
        const SizedBox(height: 10),
        _buildTrimBar(),
        const SizedBox(height: 14),
        _buildCaptionField(),
        const SizedBox(height: 12),
        _buildToolbarRow(),
      ]),
    );
  }

  // Mute (left) | Edit Cover (center) | spacer (right)
  Widget _buildTopRow() {
    return Row(children: [
      // Mute button — outlined circle style
      GestureDetector(
        onTap: _toggleMute,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            color: Colors.black,
          ),
          child: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      const Spacer(),
      // Edit Cover pill
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ویرایش کاور',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Vazirmatn',
                fontSize: 13,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, color: Colors.white, size: 16),
          ],
        ),
      ),
      const Spacer(),
      const SizedBox(width: 40), // balance
    ]);
  }

  Widget _buildTrimBar() {
    return TrimSlider(
      controller: _controller,
      height: 50,
      horizontalMargin: 4,
      child: TrimTimeline(
        controller: _controller,
        padding: const EdgeInsets.only(top: 8),
        textStyle: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      controller: _captionController,
      style: const TextStyle(color: Colors.white, fontFamily: 'Vazirmatn'),
      textDirection: TextDirection.rtl,
      maxLines: null,
      decoration: InputDecoration(
        hintText: 'کپشن اضافه کنید...',
        hintStyle: const TextStyle(
          color: Colors.white38,
          fontFamily: 'Vazirmatn',
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildToolbarRow() {
    return Row(children: [
      // Tool pill with 4 icons (matching Telegram)
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.crop_rotate, color: Colors.white70, size: 22),
              Icon(Icons.brush_outlined, color: Colors.white70, size: 22),
              _GifIcon(),
              Icon(Icons.tune, color: Colors.white70, size: 22),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Send button
      GestureDetector(
        onTap: _isExporting ? null : _exportAndSend,
        child: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xFF2AABEE),
            shape: BoxShape.circle,
          ),
          child: _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send, color: Colors.white, size: 22),
        ),
      ),
    ]);
  }
}

// GIF text icon (exactly like Telegram's GIF button)
class _GifIcon extends StatelessWidget {
  const _GifIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
