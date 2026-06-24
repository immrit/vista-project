import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Vista/features/nearby/widgets/location_permission_dialog.dart';
import 'package:Vista/services/session_manager_service_v2.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// [LocationPermissionPromptService]
///
/// مدیریت متمرکز نمایش dialog درخواست مجوز مکان برای بخش «اطراف من».
///
/// قوانین:
/// • حداکثر یک‌بار در ۲۴ ساعت نمایش داده می‌شود.
/// • اگر کاربر «دیگه ازم نپرس» را انتخاب کند، دیگر هرگز نمایش نمی‌یابد.
/// • اگر GPS قبلاً granted باشد، نمایش داده نمی‌شود.
/// • فقط برای کاربران لاگین‌شده فعال است.
/// ─────────────────────────────────────────────────────────────────────────────
class LocationPermissionPromptService {
  LocationPermissionPromptService._();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _neverAskKey = 'loc_perm_prompt.never_ask';
  static const _lastPromptMsKey = 'loc_perm_prompt.last_prompt_ms';
  static const _promptInterval = Duration(hours: 24);

  // ── Guard: از نمایش همزمان چند dialog جلوگیری می‌کند ───────────────────
  static bool _isShowing = false;

  // ─────────────────────────────────────────────────────────────────────────
  /// بررسی می‌کند آیا باید dialog نمایش داده شود.
  static Future<bool> _shouldPrompt() async {
    // اگر GPS قبلاً granted است → نیازی نیست
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        return false;
      }
    } catch (_) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // کاربر گفته «دیگه نپرس»
    if (prefs.getBool(_neverAskKey) == true) return false;

    // ۲۴ ساعت نگذشته
    final lastMs = prefs.getInt(_lastPromptMsKey);
    if (lastMs != null) {
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
      if (age < _promptInterval) return false;
    }

    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// بررسی و در صورت لزوم نمایش dialog.
  ///
  /// این متد را از [app_runner.dart] هنگام bootstrap و resume فراخوانی کن.
  /// اگر context آماده نباشد یا شرایط برقرار نباشد، silently بازمی‌گردد.
  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    if (_isShowing) return;
    if (!context.mounted) return;
    if (!await _shouldPrompt()) return;
    if (!context.mounted) return;

    _isShowing = true;
    try {
      await _showAndHandle(context);
    } finally {
      _isShowing = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _showAndHandle(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // بررسی مجدد پس از await (حالت deniedForever)
    LocationPermission perm;
    try {
      perm = await Geolocator.checkPermission();
    } catch (_) {
      return;
    }

    if (!context.mounted) return;

    if (perm == LocationPermission.deniedForever) {
      // ── کاربر قبلاً برای همیشه رد کرده → راهنمای تنظیمات نشون بده ──
      await LocationPermissionDialog.showSettingsGuide(context);
      await prefs.setInt(
          _lastPromptMsKey, DateTime.now().millisecondsSinceEpoch);

      if (!context.mounted) return;
      // پس از بستن dialog تنظیمات، openAppSettings را فراخوانی نمی‌کنیم —
      // کاربر خودش با دکمه «رفتن به تنظیمات» ایمپرسیو می‌شود.
      return;
    }

    // ── نمایش dialog اقناعی ───────────────────────────────────────────────
    final choice = await LocationPermissionDialog.showRequest(context);
    if (!context.mounted) return;

    switch (choice) {
      case LocationPermissionChoice.grant:
        // timestamp ثبت کن
        await prefs.setInt(
            _lastPromptMsKey, DateTime.now().millisecondsSinceEpoch);
        // درخواست سیستم
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.always ||
            result == LocationPermission.whileInUse) {
          // بلافاصله location بگیر و sync کن
          unawaited(SessionManagerServiceV2().updateLocationAndIP());
        }

      case LocationPermissionChoice.later:
        // فردا دوباره نشون بده
        await prefs.setInt(
            _lastPromptMsKey, DateTime.now().millisecondsSinceEpoch);

      case LocationPermissionChoice.neverAsk:
        // برای همیشه خاموش
        await prefs.setBool(_neverAskKey, true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Reset کامل (برای debugging یا logout)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_neverAskKey);
    await prefs.remove(_lastPromptMsKey);
  }
}
