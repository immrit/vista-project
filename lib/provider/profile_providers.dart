import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../services/profile_service.dart';

// سیستم لاگ گذاری
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

// Profile state
class ProfileState {
  final String? username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? birthDate;
  final bool loading;
  final String? error;

  ProfileState({
    this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.birthDate,
    this.loading = false,
    this.error,
  });

  ProfileState copyWith({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? birthDate,
    bool? loading,
    String? error,
  }) {
    return ProfileState(
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthDate: birthDate ?? this.birthDate,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  String toString() {
    return 'ProfileState(username: $username, fullName: $fullName, bio: $bio, avatarUrl: $avatarUrl, birthDate: $birthDate, loading: $loading, error: $error)';
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(ProfileState());

  Future<void> fetchProfile(String userId) async {
    state = state.copyWith(loading: true, error: null);
    logger.i('دریافت اطلاعات پروفایل برای کاربر با آی‌دی: $userId');

    try {
      final data = await ProfileService.getProfile(userId);
      if (data != null) {
        logger.d('$data اطلاعات پروفایل دریافت شد');
        state = state.copyWith(
          username: data['username'] ?? '',
          fullName: data['full_name'] ?? '',
          bio: data['bio'] ?? '',
          avatarUrl: data['avatar_url'] ?? '',
          birthDate: data['birth_date'] ?? '',
          loading: false,
        );
      } else {
        logger.d('اطلاعات کاربر یافت نشد، کاربر احتمالاً جدید است');
        state = state.copyWith(loading: false);
      }
    } catch (e) {
      logger.e('$e خطا در دریافت پروفایل');
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> saveProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(loading: true, error: null);
    logger.i('ذخیره اطلاعات پروفایل با مقادیر: $updates');

    try {
      // Timeout 10 ثانیه
      await ProfileService.upsertProfile(updates).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logger.w('تایم‌اوت در ذخیره‌سازی پروفایل');
          throw 'مدت‌زمان ذخیره‌سازی بیش از حد معمول شد.';
        },
      );

      // بروزرسانی state بعد از ذخیره موفق
      state = state.copyWith(
        loading: false,
        username: updates['username'],
        fullName: updates['full_name'],
        bio: updates['bio'],
        birthDate: updates['birth_date'],
      );
      logger.i('پروفایل با موفقیت ذخیره شد');
    } catch (e) {
      logger.e(
        '$e خطا در ذخیره پروفایل',
      );
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> updateAvatar(String userId, String url) async {
    state = state.copyWith(loading: true);
    logger.i('بروزرسانی تصویر پروفایل برای کاربر: $userId با URL: $url');

    try {
      await ProfileService.updateAvatar(userId, url);
      state = state.copyWith(avatarUrl: url, loading: false);
      logger.i('تصویر پروفایل با موفقیت به‌روزرسانی شد');
    } catch (e) {
      logger.e('$e خطا در بروزرسانی تصویر پروفایل');
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  void setTimeoutError() {
    state = state.copyWith(
        error: 'مدت‌زمان ذخیره‌سازی بیش از حد معمول شد.', loading: false);
    logger.w('وضعیت تایم‌اوت خطا تنظیم شد');
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

// ارائه یک state provider برای بارگذاری
final loadingProvider = StateProvider<bool>((ref) => false);
