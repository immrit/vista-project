import 'package:Vista/security/logging_utility.dart';
import 'dart:io';

import 'package:screen_protector/screen_protector.dart';

/// Manages screenshot/screen-record protection for secret chat screens.
///
/// Uses a simple reference counter so nested secret screens do not
/// accidentally clear secure mode while another secure screen is still open.
class SecretChatPrivacyService {
  SecretChatPrivacyService._();

  static final SecretChatPrivacyService instance = SecretChatPrivacyService._();
  static int _activeSecureScreens = 0;

  Future<void> enableSecureDisplay() async {
    if (!Platform.isAndroid) return;
    _activeSecureScreens += 1;
    if (_activeSecureScreens > 1) return;

    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      logInfo('Failed to enable secure display: $e');
    }
  }

  Future<void> disableSecureDisplay() async {
    if (!Platform.isAndroid) return;
    if (_activeSecureScreens <= 0) return;
    _activeSecureScreens -= 1;
    if (_activeSecureScreens > 0) return;

    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      logInfo('Failed to disable secure display: $e');
    }
  }
}
