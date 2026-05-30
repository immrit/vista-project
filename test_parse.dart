import 'dart:convert';

void main() {
  String val1 = '["https://example.com/image.jpg"]';
  String val2 = '{https://example.com/image.jpg}';
  
  String parse(dynamic value) {
    if (value == null) return 'null';
    if (value is List) return value.isNotEmpty ? value.first.toString() : 'empty list';
    final result = value.toString();
    if (result.startsWith('[') && result.endsWith(']')) {
      try {
        final List parsed = json.decode(result);
        if (parsed.isNotEmpty) {
          return parsed.first.toString();
        }
      } catch (_) {}
    }
    if (result.startsWith('{') && result.endsWith('}')) {
      final inner = result.substring(1, result.length - 1);
      final parts = inner.split(',');
      if (parts.isNotEmpty) return parts.first.trim();
    }
    return result;
  }
  
  print('val1: ' + parse(val1));
  print('val2: ' + parse(val2));
  print('normal: ' + parse('https://example.com/image.jpg'));
}
