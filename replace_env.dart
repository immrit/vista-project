import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    if (content
        .contains("import 'package:flutter_dotenv/flutter_dotenv.dart';")) {
      content = content.replaceAll(
          "import 'package:flutter_dotenv/flutter_dotenv.dart';",
          "import 'package:Vista/utils/env_config.dart';");
      changed = true;
    }

    if (content.contains("dotenv.env['BACKEND_URL']")) {
      content = content.replaceAll(
          "dotenv.env['BACKEND_URL']", "EnvConfig.apiBaseUrl");
      if (!content.contains("import 'package:Vista/utils/env_config.dart';")) {
        content = "import 'package:Vista/utils/env_config.dart';\n$content";
      }
      changed = true;
    }

    if (content.contains("dotenv.env['ARVAN_BUCKET']")) {
      content =
          content.replaceAll("dotenv.env['ARVAN_BUCKET']", "'vista-bucket'");
      changed = true;
    }

    if (content.contains("dotenv.env['ARVAN_BUCKET_NAME']")) {
      content = content.replaceAll(
          "dotenv.env['ARVAN_BUCKET_NAME']", "'vista-bucket-name'");
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated: ${file.path}');
    }
  }
}
