import 'dart:io';
import 'dart:convert';

void main() {
  final dir = Directory(r'E:\vista\lib\features\chat');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalReplaced = 0;

  for (final file in files) {
    String content = file.readAsStringSync(encoding: latin1);
    bool changed = false;

    // DEBT-3: Empty catch blocks
    if (content.contains('catch (_) {}')) {
      content = content.replaceAll(
          'catch (_) {}', 
          "catch (e) { logError('Silent error swallowed', error: e); }");
      changed = true;
    }

    // DEBT-4: console prints
    final printReg = RegExp(r'\bprint\(');
    if (printReg.hasMatch(content)) {
      content = content.replaceAll(printReg, 'logInfo(');
      changed = true;
    }

    final debugPrintReg = RegExp(r'\bdebugPrint\(');
    if (debugPrintReg.hasMatch(content)) {
      content = content.replaceAll(debugPrintReg, 'logInfo(');
      changed = true;
    }

    // ARCH-1 & 2
    if (file.path.endsWith('chat_repository_impl.dart')) {
       final m1 = RegExp(r'final Map<String, int> _lastMsgSyncMs = \{\};\s*final Map<String, bool> _msgSyncInFlight = \{\};\s*int _lastConvSyncMs = 0;\s*bool _convSyncInFlight = false;\s*int _convRateLimitedUntilMs = 0;');
       if (m1.hasMatch(content)) {
         content = content.replaceFirst(m1, 'final Map<String, Timer?> _msgSyncTimers = {};\n  final Map<String, bool> _msgSyncInFlight = {};\n  Timer? _convSyncTimer;\n  bool _convSyncInFlight = false;\n  int _convRateLimitedUntilMs = 0;');
         changed = true;
       }

       final m2 = RegExp(r'SseManager\.instance\.start\(\);\s*\}');
       if (m2.hasMatch(content)) {
         content = content.replaceFirst(m2, 'SseManager.instance.start();\n\n    SseManager.instance.connectionState.listen((state) {\n      if (state == SseConnectionState.connected) {\n        _userId().then((uid) {\n          if (uid != null) {\n            _syncConversations(uid);\n            if (_activeConversationId != null) {\n              _syncMessages(_activeConversationId!, uid);\n            }\n          }\n        });\n      }\n    });\n  }');
         changed = true;
       }

       final m3 = RegExp(r'Future<void> _syncConversations\(String uid\) async \{\s*if \(_convSyncInFlight\) return;\s*final now = DateTime\.now\(\)\.millisecondsSinceEpoch;\s*if \(now < _convRateLimitedUntilMs\) return;\s*if \(now - _lastConvSyncMs < _convSyncThrottle\.inMilliseconds\) return;\s*_lastConvSyncMs = now;\s*_convSyncInFlight = true;');
       if (m3.hasMatch(content)) {
         content = content.replaceFirst(m3, 'Future<void> _syncConversations(String uid) async {\n    if (_convSyncTimer?.isActive ?? false) return;\n    _convSyncTimer = Timer(const Duration(milliseconds: 500), () async {\n      if (_convSyncInFlight) return;\n      final now = DateTime.now().millisecondsSinceEpoch;\n      if (now < _convRateLimitedUntilMs) return;\n      _convSyncInFlight = true;');
         changed = true;
       }

       final m4 = RegExp(r'\} finally \{\s*_convSyncInFlight = false;\s*\}\s*\}');
       if (m4.hasMatch(content)) {
         content = content.replaceFirst(m4, '} finally {\n        _convSyncInFlight = false;\n      }\n    });\n  }');
         changed = true;
       }

       final m5 = RegExp(r'Future<void> _syncMessages\(String conversationId, String uid\) async \{\s*if \(_msgSyncInFlight\[conversationId\] == true\) return;\s*final now = DateTime\.now\(\)\.millisecondsSinceEpoch;\s*if \(now - \(_lastMsgSyncMs\[conversationId\] \?\? 0\) <\s*_msgSyncThrottle\.inMilliseconds\) \{\s*return;\s*\}\s*_lastMsgSyncMs\[conversationId\] = now;\s*_msgSyncInFlight\[conversationId\] = true;');
       if (m5.hasMatch(content)) {
         content = content.replaceFirst(m5, 'Future<void> _syncMessages(String conversationId, String uid) async {\n    if (_msgSyncTimers[conversationId]?.isActive ?? false) return;\n    _msgSyncTimers[conversationId] = Timer(const Duration(milliseconds: 500), () async {\n      if (_msgSyncInFlight[conversationId] == true) return;\n      _msgSyncInFlight[conversationId] = true;');
         changed = true;
       }

       final m6 = RegExp(r'\} finally \{\s*_msgSyncInFlight\.remove\(conversationId\);\s*\}\s*\}');
       if (m6.hasMatch(content)) {
         content = content.replaceFirst(m6, '} finally {\n        _msgSyncInFlight.remove(conversationId);\n      }\n    });\n  }');
         changed = true;
       }
    }

    if (changed) {
      if (!content.contains('package:Vista/security/logging_utility.dart')) {
        content = "import 'package:Vista/security/logging_utility.dart';\n" + content;
      }
      file.writeAsStringSync(content, encoding: latin1);
      totalReplaced++;
      print('Fixed ${file.path}');
    }
  }

  print('Total files modified: $totalReplaced');
}
