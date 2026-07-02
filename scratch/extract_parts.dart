import 'dart:io';

void main() {
  final file =
      File(r'E:\vista\lib\features\chat\screens\modern_chat_screen.dart');
  final content = file.readAsStringSync();

  // Find start index of each section
  final appBarStart =
      content.indexOf('  Widget _buildEmojiPanel(ChatTheme theme) {');
  final listStart = content.indexOf('  Widget _buildMessageList(');
  final inputStart = content.indexOf('  Widget _buildInputDockHalo({');
  final bubblesStart = content.indexOf(
      '  Widget _buildMessagePreviewWidget(MessageModel message, bool isMe) {');

  // Find the start of the next class to avoid including classes in the extension
  final endOfStateClass = content.indexOf('class _ChatRenderItem');

  if (appBarStart == -1 ||
      listStart == -1 ||
      inputStart == -1 ||
      bubblesStart == -1 ||
      endOfStateClass == -1) {
    print('Error: Could not find one of the start indices.');
    return;
  }

  // Extract sections
  final appBarCode = content.substring(appBarStart, listStart);
  final listCode = content.substring(listStart, inputStart);
  final inputCode = content.substring(inputStart, bubblesStart);
  final bubblesCode = content.substring(
      bubblesStart, endOfStateClass - 2); // -2 for trailing \n}

  // Write to part files
  _writePartFile(
      'modern_chat_screen_app_bar.dart', 'ModernChatAppBarExt', appBarCode);
  _writePartFile('modern_chat_screen_list.dart', 'ModernChatListExt', listCode);
  _writePartFile(
      'modern_chat_screen_input.dart', 'ModernChatInputExt', inputCode);
  _writePartFile(
      'modern_chat_screen_bubbles.dart', 'ModernChatBubblesExt', bubblesCode);

  // Update main file
  final mainCode =
      '${content.substring(0, appBarStart)}}\n\n${content.substring(endOfStateClass)}';

  // Insert part directives after the last import
  final lastImportIndex = mainCode.lastIndexOf('import ');
  final endOfLastImport = mainCode.indexOf('\n', lastImportIndex) + 1;

  final newMainCode =
      "${mainCode.substring(0, endOfLastImport)}\npart 'modern_chat_screen_app_bar.dart';\npart 'modern_chat_screen_list.dart';\npart 'modern_chat_screen_input.dart';\npart 'modern_chat_screen_bubbles.dart';\n${mainCode.substring(endOfLastImport)}";

  file.writeAsStringSync(newMainCode);
  print('Successfully split modern_chat_screen.dart!');
}

void _writePartFile(String filename, String extensionName, String code) {
  final file = File('E:\\vista\\lib\\features\\chat\\screens\\$filename');
  final buffer = StringBuffer();
  buffer.writeln("part of 'modern_chat_screen.dart';");
  buffer.writeln();
  buffer.writeln("extension $extensionName on _ModernChatScreenState {");
  buffer.write(code);
  buffer.writeln("}");
  file.writeAsStringSync(buffer.toString());
}
