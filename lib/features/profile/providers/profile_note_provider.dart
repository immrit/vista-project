import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile_note_model.dart';
import '../data/services/profile_note_service.dart';
import '../../auth/providers/auth_controller.dart';

/// Provider برای دریافت وضعیت یک کاربر خاص
final profileNoteProvider =
    FutureProvider.family<ProfileNoteModel?, String>((ref, userId) async {
  final service = ref.watch(profileNoteServiceProvider);
  return service.getActiveNote(userId);
});

/// Provider برای batch loading وضعیت چند کاربر
final profileNotesMapProvider =
    FutureProvider.family<Map<String, ProfileNoteModel>, List<String>>(
        (ref, userIds) async {
  final service = ref.watch(profileNoteServiceProvider);
  return service.getNotesForUsers(userIds);
});

/// StateNotifier برای مدیریت وضعیت کاربر فعلی
class CurrentUserNoteNotifier
    extends StateNotifier<AsyncValue<ProfileNoteModel?>> {
  final ProfileNoteService _service;
  final String _userId;

  CurrentUserNoteNotifier(this._service, this._userId) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final note = await _service.getActiveNote(_userId);
      if (mounted) state = AsyncValue.data(note);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// ایجاد یا بروزرسانی وضعیت
  Future<void> createNote(String content) async {
    state = const AsyncValue.loading();

    try {
      final note = await _service.upsertNote(content);
      state = AsyncValue.data(note);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// حذف وضعیت
  Future<void> deleteNote() async {
    state = const AsyncValue.loading();

    try {
      await _service.deleteNote();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider برای مدیریت وضعیت کاربر فعلی
final currentUserNoteProvider = StateNotifierProvider<CurrentUserNoteNotifier,
    AsyncValue<ProfileNoteModel?>>((ref) {
  final service = ref.watch(profileNoteServiceProvider);
  final userId = ref.watch(authProvider)?.id ?? 'current_user';
  return CurrentUserNoteNotifier(service, userId);
});
