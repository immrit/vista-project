import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'vista_emoji_panel.dart'; // Assuming this exists or works with previous imports

class VistaChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File)? onSendVoiceMessage;
  final Function(String)? onTextChanged;
  final Function()? onAttachPressed;
  final Function(String)? onGifSelected;
  final String? hint;
  final bool enabled;

  const VistaChatInput({
    super.key,
    required this.onSendMessage,
    this.onSendVoiceMessage,
    this.onTextChanged,
    this.onAttachPressed,
    this.onGifSelected,
    this.hint,
    this.enabled = true,
  });

  @override
  State<VistaChatInput> createState() => _VistaChatInputState();
}

class _VistaChatInputState extends State<VistaChatInput>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final RecorderController _recorderController;

  // State
  bool _hasText = false;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _showEmojiPicker = false;
  int _recordingDuration = 0;
  int _lineCount = 1;
  double _slideProgress = 0.0;
  Offset? _longPressStartPosition;

  // Animations
  late AnimationController _sendButtonController;
  late AnimationController _micIconController;
  late AnimationController _slideCancelController;
  late Animation<double> _micIconScaleAnimation;

  // Timers
  Timer? _recordingTimer;

  // Constants
  static const double _minHeight = 48.0;
  static const double _lineHeight = 24.0;
  static const double _maxLines = 5.0;
  static const double _lockThreshold = 80.0;
  static const double _cancelThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupRecorder();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _setupAnimations() {
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _micIconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _micIconScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _micIconController,
        curve: Curves.easeOut,
      ),
    );

    _slideCancelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupRecorder() {
    _recorderController = RecorderController();
  }

  void _onTextChanged() {
    if (!mounted) return;

    final text = _controller.text;
    final newLineCount = '\n'.allMatches(text).length + 1;
    final clampedLineCount = newLineCount.clamp(1, _maxLines.toInt());

    if (clampedLineCount != _lineCount) {
      setState(() => _lineCount = clampedLineCount);
    }

    final newHasText = text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
      if (newHasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }

    widget.onTextChanged?.call(text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  Future<void> _toggleEmojiPicker() async {
    HapticFeedback.lightImpact();

    if (_showEmojiPicker) {
      _focusNode.requestFocus();
      setState(() => _showEmojiPicker = false);
    } else {
      _focusNode.unfocus();
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      setState(() => _showEmojiPicker = true);
    }
  }

  Future<void> _startRecording(Offset position) async {
    final hasPermission = await _recorderController.checkPermission();
    if (!hasPermission) return;

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/vista_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorderController.record(path: path);

    _micIconController.forward();
    _slideCancelController.forward();

    setState(() {
      _isRecording = true;
      _isLocked = false;
      _longPressStartPosition = position;
      _recordingDuration = 0;
      _slideProgress = 0.0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration++);
      }
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _recorderController.stop();
    _resetRecordingState();

    if (path != null && widget.onSendVoiceMessage != null) {
      widget.onSendVoiceMessage!(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    await _recorderController.stop();
    _resetRecordingState();
  }

  void _resetRecordingState() {
    _micIconController.reverse();
    _slideCancelController.reverse();
    _recordingTimer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _longPressStartPosition = null;
        _recordingDuration = 0;
        _slideProgress = 0.0;
      });
    }
  }

  void _lockRecording() {
    HapticFeedback.mediumImpact();
    _micIconController.reverse();
    setState(() => _isLocked = true);
  }

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSendMessage(_controller.text.trim());
      _controller.clear();
      setState(() {
        _hasText = false;
        _lineCount = 1;
      });
      _sendButtonController.reverse();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorderController.dispose();
    _sendButtonController.dispose();
    _micIconController.dispose();
    _slideCancelController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: keyboardHeight > 0
              ? 8
              : (bottomPadding > 0 ? bottomPadding + 8 : 12),
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _isRecording
                    ? _buildRecordingUI(theme, isDark)
                    : _buildInputUI(theme, isDark),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _showEmojiPicker
                    ? Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: keyboardHeight > 0 ? keyboardHeight : 300,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFFF0F2F5),
                        ),
                        child: VistaEmojiPanel(
                          controller: _controller,
                          height: keyboardHeight > 0 ? keyboardHeight : 300,
                          onGifSelected: widget.onGifSelected,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputUI(ThemeData theme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildIconButton(
          icon: _showEmojiPicker
              ? Icons.keyboard_alt_outlined
              : Icons.emoji_emotions_outlined,
          onPressed: _toggleEmojiPicker,
          isActive: _showEmojiPicker,
          theme: theme,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTextField(theme, isDark),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: !_hasText
              ? _buildIconButton(
                  key: const ValueKey('attach'),
                  icon: Icons.attach_file,
                  onPressed: widget.onAttachPressed ?? () {},
                  theme: theme,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        const SizedBox(width: 4),
        _buildSendVoiceButton(theme),
      ],
    );
  }

  Widget _buildTextField(ThemeData theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      constraints: BoxConstraints(
        minHeight: _minHeight,
        maxHeight: _minHeight + (_lineCount - 1) * _lineHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        maxLines: _maxLines.toInt(),
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textDirection: TextDirection.rtl,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: theme.textTheme.bodyLarge
            ?.copyWith(fontFamily: 'Vazir', height: 1.5),
        decoration: InputDecoration(
          filled: false,
          fillColor: Colors.transparent,
          hintText: widget.hint ?? 'پیام...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    Key? key,
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
    bool isActive = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 24,
            color: isActive
                ? theme.primaryColor
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildSendVoiceButton(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_hasText) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _sendMessage,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 24,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onLongPressStart: (details) => _startRecording(details.globalPosition),
        onLongPressEnd: (details) {
          if (_isLocked) return;
          final dragOffsetX =
              details.globalPosition.dx - (_longPressStartPosition?.dx ?? 0);
          if (dragOffsetX < -_cancelThreshold) {
            _cancelRecording();
          } else {
            _stopRecordingAndSend();
          }
        },
        onLongPressMoveUpdate: (details) {
          if (_isLocked) return;
          final dragOffsetY =
              details.globalPosition.dy - (_longPressStartPosition?.dy ?? 0);
          if (dragOffsetY < -_lockThreshold) {
            _lockRecording();
          }
          final dragOffsetX =
              details.globalPosition.dx - (_longPressStartPosition?.dx ?? 0);
          if (dragOffsetX < -_cancelThreshold) {
            _cancelRecording();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              Icons.mic_none_rounded,
              size: 26,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildRecordingUI(ThemeData theme, bool isDark) {
    return Container(
      key: ValueKey(_isLocked ? 'locked' : 'recording'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_isLocked)
            _buildDeleteButton(theme)
          else
            _buildPulsingRecordIndicator(theme),
          const SizedBox(width: 12),
          Expanded(
            child: _isLocked
                ? _buildLockedWaveform(theme, isDark)
                : _buildSlideToCancel(theme),
          ),
          const SizedBox(width: 8),
          _isLocked
              ? _buildSendVoiceButtonInRecording(theme)
              : _buildLockButton(theme),
        ],
      ),
    );
  }

  Widget _buildPulsingRecordIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _micIconScaleAnimation,
          builder: (context, child) {
            final pulse = 0.8 + (_micIconScaleAnimation.value * 0.4);
            return Container(
              width: 10 * pulse,
              height: 10 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5 * pulse),
                    blurRadius: 8 * pulse,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          _formatDuration(_recordingDuration),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(ThemeData theme) {
    return GestureDetector(
      onTap: _cancelRecording,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.1),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
    );
  }

  Widget _buildLockedWaveform(ThemeData theme, bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AudioWaveforms(
              size: const Size(double.infinity, 24),
              recorderController: _recorderController,
              waveStyle: WaveStyle(
                waveColor: isDark ? Colors.white70 : Colors.black54,
                extendWaveform: true,
                showMiddleLine: false,
                spacing: 4,
                waveThickness: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideToCancel(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (!_isRecording || _isLocked) return;
        setState(() {
          _slideProgress =
              (details.localPosition.dx / MediaQuery.of(context).size.width)
                  .clamp(0.0, 1.0);
          if (_slideProgress < 0.3) {
            _cancelRecording();
          }
        });
      },
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chevron_left, color: Colors.grey, size: 16),
            Text(
              'برای لغو بکشید',
              style: TextStyle(
                fontSize: 13,
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity((1.0 - _slideProgress).clamp(0.2, 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockButton(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 16),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.scaffoldBackgroundColor,
          ),
          child: const Icon(Icons.lock_outline, size: 18),
        ),
      ],
    );
  }

  Widget _buildSendVoiceButtonInRecording(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: _stopRecordingAndSend,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.send_rounded,
            size: 20, color: isDark ? Colors.black : Colors.white),
      ),
    );
  }
}
