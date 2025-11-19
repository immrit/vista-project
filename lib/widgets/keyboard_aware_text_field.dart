import 'package:flutter/material.dart';
import '../utils/deferred_initialization_manager.dart';

/// ✅ Keyboard-Aware TextField
/// عملیات سنگین را هنگام باز شدن کیبورد متوقف می‌کند
class KeyboardAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Function(String)? onSubmitted;
  final int? maxLines;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool enableSuggestions;

  const KeyboardAwareTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = '',
    this.onSubmitted,
    this.maxLines,
    this.decoration,
    this.style,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  @override
  State<KeyboardAwareTextField> createState() => _KeyboardAwareTextFieldState();
}

class _KeyboardAwareTextFieldState extends State<KeyboardAwareTextField>
    with WidgetsBindingObserver {
  final _deferredManager = DeferredInitializationManager();
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Monitor focus changes
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // TextField focused - کیبورد در حال باز شدن
      _deferredManager.keyboardOpened();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // بررسی وضعیت کیبورد
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (_wasKeyboardVisible != isKeyboardVisible) {
      _wasKeyboardVisible = isKeyboardVisible;

      if (isKeyboardVisible) {
        _deferredManager.keyboardOpened();
      } else {
        _deferredManager.keyboardClosed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultDecoration = InputDecoration(
      hintText: widget.hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: widget.decoration ?? defaultDecoration,
      style: widget.style,
      maxLines: widget.maxLines,
      textInputAction: TextInputAction.newline,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType ?? TextInputType.multiline,
      // ✅ تنظیمات مهم برای performance
      enableInteractiveSelection: true,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
    );
  }
}








