import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'package:Vista/widgets/VideoPlayerConfig.dart';
import 'package:path_provider/path_provider.dart';
import '../DB/profile_cache_service.dart';
import '../DB/settings_cache_service.dart';
import '../services/animation_controller_service.dart';
import '../services/video_autoplay_service.dart';
import '../services/image_quality_service.dart';
import '../core/data/cache/cache_repository.dart';
import '../model/SearchResut.dart';
import '/model/ProfileModel.dart';
import '/model/publicPostModel.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import '../widgets/verification_badge_icon.dart';
import 'package:Vista/utils/themes.dart';
import '../services/user_friendly_error_handler.dart';
import '../services/voice_cache_service.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/services/profile_note_service.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../features/stories/data/repositories/story_repository.dart';
import '../services/comment_repository.dart';
import 'notification_provider.dart' as go_notifications;

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';
export '../features/profile/providers/profile_controller.dart';

final themeProvider = StateProvider<ThemeData>((ref) {
  final platformBrightness = PlatformDispatcher.instance.platformBrightness;

  return platformBrightness == Brightness.dark
      ? VistaThemes.darkTheme
      : VistaThemes.lightTheme;
});

class BrightnessNotifier extends StateNotifier<Brightness> {
  BrightnessNotifier() : super(PlatformDispatcher.instance.platformBrightness);

  void updateBrightness(Brightness brightness) {
    state = brightness;
  }
}

final brightnessProvider =
    StateNotifierProvider<BrightnessNotifier, Brightness>((ref) {
  return BrightnessNotifier();
});

final dynamicThemeProvider = StateProvider<ThemeData>((ref) {
  final brightness = ref.watch(brightnessProvider);
  return brightness == Brightness.dark
      ? VistaThemes.darkTheme
      : VistaThemes.lightTheme;
});
