import 'package:flutter/material.dart';
import 'dart:ui'; // Required for ImageFilter
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
    final primaryColor = theme.primaryColor;

    // Glassmorphism background color (semi-transparent)
    final capsuleColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    final iconColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors
          .transparent, // Make outer container transparent to show wallpaper/content
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Capsule Container with Glass Effect
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: capsuleColor,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
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
                            padding: const EdgeInsets.symmetric(
                                vertical:
                                    2), // Reduced vertical padding as TextField has its own contentPadding
                            child: TextField(
                              controller: _controller,
                              maxLines: 5,
                              minLines: 1,
                              // Text Color: Black in Light, White in Dark
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              // Cursor Color: Primary Color
                              cursorColor: primaryColor,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Message...',
                                hintStyle: TextStyle(color: iconColor),
                                filled: true,
                                // Make Input Transparent
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 12),
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
                                      color: primaryColor,
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
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mic_none_rounded,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
