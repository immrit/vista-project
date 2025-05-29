import 'package:supabase_flutter/supabase_flutter.dart';

const String defaultAvatarUrl = 'lib/view/util/images/default-avatar.jpg';

const String supabaseCdnUrl = 'https://api.coffevista.ir:8443';
const String supabaseDirectUrl = 'http://mydash.coffevista.ir:8000';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

Future<void> initializeSupabaseWithFailover() async {
  try {
    await Supabase.initialize(url: supabaseCdnUrl, anonKey: supabaseAnonKey);
    // یه پینگ ساده:
    await Supabase.instance.client.from('profiles').select().limit(1);
    print('Connected to ArvanCloud API.');
  } catch (e) {
    print('Supabase CDN failed, trying direct...');
    try {
      await Supabase.initialize(
          url: supabaseDirectUrl, anonKey: supabaseAnonKey);
      await Supabase.instance.client.from('profiles').select().limit(1);
      print('Connected to Direct API.');
    } catch (err) {
      print('Both API endpoints failed.');
      // notify user dialog/open page
    }
  }
}
