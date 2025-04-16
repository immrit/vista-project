import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .select('username, full_name, birth_date')
          .eq('id', user.id)
          .single();

      final bool isComplete = response != null &&
          response['username'] != null &&
          response['username'].toString().isNotEmpty &&
          response['full_name'] != null &&
          response['full_name'].toString().isNotEmpty &&
          response['birth_date'] != null &&
          response['birth_date'].toString().isNotEmpty;

      state = isComplete;
      return isComplete;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }
}
