import '../security/logging_utility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Vista/core/security/input_policy.dart';

final profileCompletionProvider =
    StateNotifierProvider<ProfileCompletionNotifier, bool>((ref) {
  return ProfileCompletionNotifier();
});

class ProfileCompletionNotifier extends StateNotifier<bool> {
  ProfileCompletionNotifier() : super(false);

  Future<bool> checkProfileCompletion() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return true;

      final response = await supabase
          .from('profiles')
          .select('username, full_name, birth_date, phone_number')
          .eq('id', user.id)
          .single();

      final username = response['username']?.toString() ?? '';
      final usernameValidation = validateUsername(username);
      final phone = response['phone_number']?.toString() ?? '';
      final normalizedPhone = normalizePhone09(phone);

      final bool isComplete = usernameValidation.isValid &&
          response['full_name'] != null &&
          response['full_name'].toString().isNotEmpty &&
          response['birth_date'] != null &&
          response['birth_date'].toString().isNotEmpty &&
          phone.isNotEmpty &&
          normalizedPhone != null &&
          normalizedPhone == phone;

      state = isComplete;
      return isComplete;
    } catch (e) {
      logInfo('Error checking profile completion: $e');
      return false;
    }
  }
}
