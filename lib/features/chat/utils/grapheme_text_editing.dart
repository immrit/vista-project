import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

class GraphemeTextEditing {
  const GraphemeTextEditing._();

  static TextEditingValue insertText(
    TextEditingValue current,
    String insertion,
  ) {
    final text = current.text;
    final selection = _safeSelection(current);
    final start = _boundaryBefore(text, selection.start);
    final end = _boundaryAfter(text, selection.end);
    final newText = text.replaceRange(start, end, insertion);
    final caret = start + insertion.length;
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.collapsed(caret),
    );
  }

  static TextEditingValue backspace(TextEditingValue current) {
    final text = current.text;
    if (text.isEmpty) return current;

    final selection = _safeSelection(current);
    if (!selection.isCollapsed) {
      final start = _boundaryBefore(text, selection.start);
      final end = _boundaryAfter(text, selection.end);
      final newText = text.replaceRange(start, end, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.collapsed(start),
      );
    }

    final cursor = _boundaryAfter(text, selection.start);
    if (cursor <= 0) return current;
    final previous = _previousBoundary(text, cursor);
    final newText = text.replaceRange(previous, cursor, '');
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: previous),
      composing: TextRange.collapsed(previous),
    );
  }

  static TextSelection _safeSelection(TextEditingValue value) {
    final textLen = value.text.length;
    if (!value.selection.isValid) {
      return TextSelection.collapsed(offset: textLen);
    }
    final start = value.selection.start.clamp(0, textLen);
    final end = value.selection.end.clamp(0, textLen);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  static int _boundaryBefore(String text, int offset) {
    final safeOffset = offset.clamp(0, text.length);
    if (safeOffset <= 0 || text.isEmpty) return 0;
    var index = 0;
    for (final grapheme in text.characters) {
      final next = index + grapheme.length;
      if (safeOffset <= index) return index;
      if (safeOffset < next) return index;
      if (safeOffset == next) return next;
      index = next;
    }
    return text.length;
  }

  static int _boundaryAfter(String text, int offset) {
    final safeOffset = offset.clamp(0, text.length);
    if (safeOffset <= 0 || text.isEmpty) return 0;
    var index = 0;
    for (final grapheme in text.characters) {
      final next = index + grapheme.length;
      if (safeOffset <= index) return index;
      if (safeOffset < next) return next;
      if (safeOffset == next) return next;
      index = next;
    }
    return text.length;
  }

  static int _previousBoundary(String text, int cursor) {
    var previous = 0;
    var index = 0;
    for (final grapheme in text.characters) {
      final next = index + grapheme.length;
      if (next >= cursor) {
        return index;
      }
      previous = next;
      index = next;
    }
    return previous;
  }
}
