import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class TelegramEditorConfigs {
  static ProImageEditorConfigs build() {
    return ProImageEditorConfigs(
      designMode: ImageEditorDesignMode.material,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
        ),
      ),
      // Basic editors enabled by default, others can be used as needed.
      paintEditor: const PaintEditorConfigs(),
      cropRotateEditor: const CropRotateEditorConfigs(),
      textEditor: const TextEditorConfigs(),
      imageGeneration: const ImageGenerationConfigs(
        outputFormat: OutputFormat.jpg,
        enableUseOriginalBytes: false,
      ),
      i18n: const I18n(
        cancel: 'لغو',
        undo: 'بازگردانی',
        redo: 'از نو',
        done: 'تأیید',
        remove: 'حذف',
        doneLoadingMsg: 'در حال اعمال تغییرات...',
        cropRotateEditor: I18nCropRotateEditor(
          bottomNavigationBarText: 'برش و چرخش',
          rotate: 'چرخش',
          ratio: 'نسبت',
          back: 'بازگشت',
          done: 'تأیید',
          cancel: 'لغو',
          undo: 'بازگردانی',
          redo: 'از نو',
          reset: 'بازنشانی',
          flip: 'آینه',
        ),
        paintEditor: I18nPaintEditor(
          bottomNavigationBarText: 'نقاشی',
          freestyle: 'آزاد',
          arrow: 'پیکان',
          line: 'خط',
          rectangle: 'مستطیل',
          circle: 'دایره',
          dashLine: 'خط چین',
          eraser: 'پاک‌کن',
          undo: 'بازگردانی',
          redo: 'از نو',
          done: 'تأیید',
          back: 'بازگشت',
          opacity: 'شفافیت',
          color: 'رنگ',
          strokeWidth: 'ضخامت',
          cancel: 'لغو',
        ),
      ),
    );
  }
}
