import 'dart:io';

void main() {
  final dir = Directory(r'E:\vista\lib\features\chat\screens');
  
  // 1. Rename extensions to be private
  for (final file in dir.listSync().whereType<File>()) {
    if (file.path.endsWith('.dart') && file.path.contains('modern_chat_screen_')) {
      var content = file.readAsStringSync();
      content = content.replaceAll('extension ModernChatAppBarExt on', 'extension _ModernChatAppBarExt on');
      content = content.replaceAll('extension ModernChatListExt on', 'extension _ModernChatListExt on');
      content = content.replaceAll('extension ModernChatInputExt on', 'extension _ModernChatInputExt on');
      content = content.replaceAll('extension ModernChatBubblesExt on', 'extension _ModernChatBubblesExt on');
      
      // 2. Remove setState for _messageReactionNotifiers because it's redundant
      content = content.replaceAll('setState(() {\\n      for (final notifier in _messageReactionNotifiers.values) {\\n        notifier.value = _enrichReactions(notifier.value);\\n      }\\n    });', 'for (final notifier in _messageReactionNotifiers.values) {\\n      notifier.value = _enrichReactions(notifier.value);\\n    }');
      
      file.writeAsStringSync(content);
    }
  }
  print('Fixed extensions and redundant setState');
}
