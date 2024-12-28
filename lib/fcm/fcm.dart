import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> saveFcmTokenToSupabase() async {
  final supabase = Supabase.instance.client;

  // دریافت توکن از Firebase Messaging
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) {
    print("Unable to fetch FCM token");
    return;
  }

  print("FCM Token: $fcmToken");

  // دریافت اطلاعات کاربر فعلی از Supabase
  final user = supabase.auth.currentUser;
  if (user == null) {
    print("No authenticated user found");
    return;
  }

  try {
    // به‌روزرسانی توکن FCM در جدول profiles
    final response = await supabase
        .from('profiles')
        .update({'fcm_token': fcmToken}).eq('id', user.id);

    if (response.error != null) {
      print("Error updating FCM token: ${response.error!.message}");
    } else {
      print("FCM token successfully updated for user ${user.id}");
    }
  } catch (error) {
    print("Error saving FCM token: $error");
  }
}
