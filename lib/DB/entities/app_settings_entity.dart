import 'package:isar/isar.dart';

part 'app_settings_entity.g.dart';

@collection
class AppSettingsEntity {
  Id id = Isar.autoIncrement; // Single record usually, id=1

  late String selectedColor; // 'red', 'blue', etc.

  late bool isDark;

  // Auto Download
  String? autoDownloadPhotos;
  String? autoDownloadVoices;

  // Font Size
  double? messageFontSize;

  // Performance
  bool? batterySaverMode;
  bool? smartCache;
  bool? messagePreloading;

  // Localization
  String? languageCode;
}
