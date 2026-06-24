import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

Widget testEditor(File file) {
  return ProImageEditor.file(
    file,
    callbacks: ProImageEditorCallbacks(
      onImageEditingComplete: (Uint8List bytes) async {
      },
    ),
    configs: const ProImageEditorConfigs(
      designMode: ImageEditorDesignMode.material,
    ),
  );
}
