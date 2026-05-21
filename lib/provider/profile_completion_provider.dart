import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/input_policy.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../security/logging_utility.dart';

final profileCompletionProvider =
    StateNotifierProvider<ProfileCompletionNotifier, bool>((ref) {
  return ProfileCompletionNotifier();
});

class ProfileCompletionNotifier extends StateNotifier<bool> {
  ProfileCompletionNotifier() : super(false);

  Future<bool> checkProfileCompletion() async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return true;

      final user = await AuthRepository().me(accessToken);
      await TokenStorage.saveUserId(user.id);

      final profile = await ProfileRepository().fetchProfile(user.id);
      final isComplete = _isComplete(profile ?? const <String, dynamic>{});
      state = isComplete;
      return isComplete;
    } catch (e) {
      logInfo('Error checking profile completion: $e');
      state = false;
      return false;
    }
  }

  bool _isComplete(Map<String, dynamic> profile) {
    if (profile['profile_completed'] == true) return true;

    final username = profile['username']?.toString().trim() ?? '';
    final fullName = profile['full_name']?.toString().trim() ?? '';
    final birthDate = profile['birth_date']?.toString().trim() ?? '';
    final phoneVerified = profile['phone_verified_at'] != null;
    final emailVerified = profile['email_verified_at'] != null;

    return validateUsername(username).isValid &&
        fullName.isNotEmpty &&
        birthDate.isNotEmpty &&
        (phoneVerified || emailVerified);
  }
}
