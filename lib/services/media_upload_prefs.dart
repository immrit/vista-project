import 'package:shared_preferences/shared_preferences.dart';

/// Reads the user's "upload quality" choice from the Data & Storage settings
/// so the compression paths actually honor it. Previously the setting was
/// written to SharedPreferences but never read anywhere, so the control did
/// nothing.
///
/// Stored under `data_upload_quality` with values: high | standard | data_saver.
class MediaUploadPrefs {
  MediaUploadPrefs._();

  static const String _key = 'data_upload_quality';

  // Cached so the hot image-picking path doesn't await disk each time. The
  // settings page updates this via [updateCache] when the user changes it.
  static String _quality = 'high';
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _quality = prefs.getString(_key) ?? 'high';
    _loaded = true;
  }

  static void updateCache(String quality) {
    _quality = quality;
    _loaded = true;
  }

  /// JPEG quality (0–100) for picked/compressed post & story images.
  static int get imageQuality {
    switch (_quality) {
      case 'data_saver':
        return 55;
      case 'standard':
        return 75;
      case 'high':
      default:
        return 90;
    }
  }

  /// Max image dimension (px) — data saver also downscales more aggressively.
  static int get maxImageDimension {
    switch (_quality) {
      case 'data_saver':
        return 1280;
      case 'standard':
        return 1600;
      case 'high':
      default:
        return 1920;
    }
  }
}
