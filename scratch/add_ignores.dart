import 'dart:io';

void main() {
  final dir = Directory(r'E:\vista\lib\features\chat\screens');
  for (final file in dir.listSync().whereType<File>()) {
    if (file.path.endsWith('.dart') && file.path.contains('modern_chat_screen_') && !file.path.endsWith('modern_chat_screen.dart')) {
      var content = file.readAsStringSync();
      
      final ignores = '// ignore_for_file: invalid_use_of_protected_member, unused_element\n';
      if (!content.contains(ignores)) {
        content = ignores + content;
        file.writeAsStringSync(content);
      }
    }
  }
  print('Added ignore directives to part files.');
}
