import 'package:Vista/DB/advanced_settings_service.dart';

class EmojiRenderPolicy {
  const EmojiRenderPolicy._();

  // Cached per session — settings don't change mid-session without app restart.
  // Call invalidateCache() after user changes emoji style in settings.
  static bool? _cachedUseModernPanel;
  static bool? _cachedUseModernRenderer;

  static void invalidateCache() {
    _cachedUseModernPanel = null;
    _cachedUseModernRenderer = null;
  }

  static bool useModernEmojiPanel() {
    return _cachedUseModernPanel ??= _computeUseModernPanel();
  }

  static bool _computeUseModernPanel() {
    final service = AdvancedSettingsService();
    final app = service.getAdvancedAppSettings();
    final performance = service.getPerformanceSettings();

    final appearance = app['appearance'] as Map<String, dynamic>? ?? {};
    final style =
        (appearance['emoji_style'] as String? ?? 'custom').toLowerCase().trim();
    final featureFlags =
        performance['feature_flags'] as Map<String, dynamic>? ?? {};
    final panelEnabled =
        featureFlags['modern_emoji_panel_v1'] as bool? ?? true;

    return panelEnabled && style != 'system';
  }

  static bool useModernEmojiRenderer() {
    return _cachedUseModernRenderer ??= _computeUseModernRenderer();
  }

  static bool _computeUseModernRenderer() {
    final service = AdvancedSettingsService();
    final app = service.getAdvancedAppSettings();
    final performance = service.getPerformanceSettings();

    final appearance = app['appearance'] as Map<String, dynamic>? ?? {};
    final style =
        (appearance['emoji_style'] as String? ?? 'custom').toLowerCase().trim();
    final featureFlags =
        performance['feature_flags'] as Map<String, dynamic>? ?? {};
    final rendererEnabled = featureFlags['emoji_renderer_v1'] as bool? ?? true;

    return rendererEnabled && style != 'system';
  }
}
