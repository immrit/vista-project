import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/features/chat/utils/grapheme_text_editing.dart';

void main() {
  group('GraphemeTextEditing', () {
    test('backspace deletes single emoji as one grapheme', () {
      const text = 'سلام 😀';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: text.length),
      );

      final result = GraphemeTextEditing.backspace(value);
      expect(result.text, 'سلام ');
      expect(result.selection.baseOffset, 'سلام '.length);
    });

    test('backspace deletes skin tone emoji as one grapheme', () {
      const text = 'ok 👍🏽';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: text.length),
      );

      final result = GraphemeTextEditing.backspace(value);
      expect(result.text, 'ok ');
      expect(result.selection.baseOffset, 'ok '.length);
    });

    test('backspace deletes family emoji ZWJ sequence as one grapheme', () {
      const text = 'x👨‍👩‍👧‍👦';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: text.length),
      );

      final result = GraphemeTextEditing.backspace(value);
      expect(result.text, 'x');
      expect(result.selection.baseOffset, 1);
    });

    test('insertText replaces selection safely in mixed persian and emoji', () {
      const text = 'سلام 😀 دنیا';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection(baseOffset: 5, extentOffset: 7),
      );

      final result = GraphemeTextEditing.insertText(value, '😎');
      expect(result.text, 'سلام 😎 دنیا');
      expect(result.selection.baseOffset, 'سلام 😎'.length);
    });
  });
}
