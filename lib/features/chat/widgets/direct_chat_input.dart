import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class DirectChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(PlatformFile?)? onAttachmentSelected;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;
  final bool isRecording;

  const DirectChatInput({
    super.key,
    required this.onSend,
    this.onAttachmentSelected,
    this.onRecordStart,
    this.onRecordEnd,
    this.isRecording = false,
  });

  @override
  State<DirectChatInput> createState() => _DirectChatInputState();
}

class _DirectChatInputState extends State<DirectChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  void _handleAttachment() async {
    // Basic file picker trigger - implementation can be expanded
    if (widget.onAttachmentSelected != null) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          widget.onAttachmentSelected!(result.files.first);
        }
      } catch (e) {
        debugPrint('Error picking file: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor, // Blend with background
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Capsule Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attachment Button
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate_outlined,
                          color: iconColor),
                      onPressed: _handleAttachment,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(),
                    ),

                    // Text Field
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: TextField(
                          controller: _controller,
                          maxLines: 5,
                          minLines: 1,
                          style: theme.textTheme.bodyLarge,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Message...',
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),

                    // Right Side Action Button (Mic or Send)
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _hasText
                          ? GestureDetector(
                              onTap: _handleSend,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onLongPress: widget.onRecordStart,
                              onLongPressUp: widget.onRecordEnd,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors
                                      .transparent, // Transparent when mic
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mic_none_rounded, // Mic icon
                                  color: iconColor,
                                  size: 24,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
