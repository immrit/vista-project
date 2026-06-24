import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import '../../../utils/user_friendly_error_utils.dart';
import 'media_editor_result.dart';
import '../theme/telegram_editor_theme.dart';

class TelegramImageEditor extends StatefulWidget {
  final File file;
  final String initialCaption;

  const TelegramImageEditor({
    super.key,
    required this.file,
    this.initialCaption = '',
  });

  @override
  State<TelegramImageEditor> createState() => _TelegramImageEditorState();
}

class _TelegramImageEditorState extends State<TelegramImageEditor> {
  late final TextEditingController _captionController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleEditingComplete(Uint8List bytes) async {
    try {
      // Compress bytes to a valid JPEG - the editor may return raw RGBA bytes
      // which would cause FlutterImageCompress to fail during upload
      final jpegBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 720,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final finalBytes = (jpegBytes.isNotEmpty) ? jpegBytes : bytes;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(finalBytes);

      if (mounted) {
        Navigator.pop(
          context,
          MediaEditorResult(tempFile, _captionController.text.trim()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        UserFriendlyErrorUtils.showErrorSnackBar(
            context, 'خطا در ذخیره تصویر ویرایش شده');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: ProImageEditor.file(
        widget.file,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: _handleEditingComplete,
        ),
        configs: TelegramEditorConfigs.build().copyWith(
          mainEditor: TelegramEditorConfigs.build().mainEditor.copyWith(
                widgets:
                    TelegramEditorConfigs.build().mainEditor.widgets.copyWith(
                  bottomBar: (editor, rebuildStream, key) {
                    return ReactiveWidget(
                      key: key,
                      stream: rebuildStream,
                      builder: (_) {
                        return Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Caption Input
                                TextField(
                                  controller: _captionController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Add a caption...',
                                    hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                  Icons.crop_rotate,
                                                  color: Colors.white,
                                                  size: 22),
                                              onPressed: () =>
                                                  editor.openCropRotateEditor(),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(Icons.brush,
                                                  color: Colors.white,
                                                  size: 22),
                                              onPressed: () =>
                                                  editor.openPaintEditor(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Send Button
                                    GestureDetector(
                                      onTap: () {
                                        if (_isExporting) return;
                                        setState(() => _isExporting = true);
                                        // Trigger the editor to complete and return bytes
                                        editor.doneEditing();
                                      },
                                      child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.blueAccent,
                                        child: _isExporting
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2),
                                              )
                                            : const Icon(Icons.send,
                                                color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        ),
      ),
    );
  }
}
