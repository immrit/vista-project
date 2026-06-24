import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
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
    _captionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _exportAndSend() async {
    setState(() => _isExporting = true);
    
    try {
      final start = _controller.startTrim;
      final end = _controller.endTrim;
      
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Stream copy is insanely fast.
      // If _isMuted is true, we add -an to remove audio.
      final audioFlag = _isMuted ? '-an' : '-c:a copy';
      final command = '-i "${widget.file.path}" -ss ${start.inMilliseconds / 1000} -to ${end.inMilliseconds / 1000} -c:v copy $audioFlag "$outPath"';

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          if (mounted) {
            Navigator.pop(
              context,
              MediaEditorResult(File(outPath), _captionController.text.trim()),
            );
          }
        } else {
          if (mounted) setState(() => _isExporting = false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isExporting = false);
    }
  }

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
        child: Column(
          children: [
            // Video Preview Area
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  // Back button
                  Positioned(
                    top: 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Telegram-style Controls
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mute and Edit Cover Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _controller.video.setVolume(_isMuted ? 0 : 1);
                          });
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Edit Cover',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the row
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Trim Slider
                  TrimSlider(
                    controller: _controller,
                    height: 40,
                    horizontalMargin: 8,
                    child: TrimTimeline(
                      controller: _controller,
                      padding: const EdgeInsets.only(top: 10),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Caption Input
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Toolbar and Send Button
                  Row(
                    children: [
                      // Telegram-style tool pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Icon(Icons.crop_rotate, color: Colors.white, size: 22),
                              const Icon(Icons.brush, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send Button
                      GestureDetector(
                        onTap: _isExporting ? null : _exportAndSend,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.blueAccent,
                          child: _isExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
