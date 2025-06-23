import 'package:supabase_flutter/supabase_flutter.dart';

const String defaultAvatarUrl = 'lib/view/util/images/default-avatar.jpg';

const String supabaseCdnUrl = 'https://api.coffevista.ir:8443';
const String supabaseDirectUrl = 'https://cdn.vistanet.sbs';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

Future<void> initializeSupabaseWithFailover() async {
  // تلاش اول: استفاده از CDN URL
  try {
    print('Attempting Supabase initialization with CDN URL: $supabaseCdnUrl');
    await Supabase.initialize(url: supabaseCdnUrl, anonKey: supabaseAnonKey);
    print('Supabase initialized with CDN URL. Pinging...');
    await Supabase.instance.client.from('profiles').select().limit(1);
    print('Successfully connected to Supabase via CDN (cloudflare).');
    return; // اتصال موفق، خروج از تابع
  } catch (e) {
    print('Supabase CDN attempt failed: $e');

    // بررسی اینکه آیا Supabase در تلاش اول مقداردهی اولیه شده بود یا خیر.
    // اگر مقداردهی اولیه شده بود (حتی اگر پینگ ناموفق بود)، باید dispose شود.
    bool needsDisposal = false;
    try {
      // دسترسی به Supabase.instance در صورتی که _initialized false باشد، خطا می‌دهد.
      // از این طریق می‌توانیم بفهمیم که آیا _initialized true شده است یا خیر.
      Supabase.instance; // اگر این خط اجرا شود یعنی _initialized true بوده.
      needsDisposal = true;
    } catch (assertionError) {
      // اگر خطای assertion رخ دهد، یعنی Supabase.instance قابل دسترسی نیست
      // و _initialized false است. پس نیازی به dispose نیست.
      print(
          'Supabase was not fully initialized by the first attempt, no disposal needed.');
      needsDisposal = false;
    }

    if (needsDisposal) {
      print('Disposing previous Supabase instance before trying fallback...');
      try {
        await Supabase.instance.dispose(); // ریست کردن وضعیت Supabase
        print('Previous Supabase instance disposed.');
      } catch (disposeError) {
        print(
            'Error disposing Supabase instance: $disposeError. Proceeding with fallback anyway.');
        // اگر dispose هم خطا بدهد، احتمالاً مقداردهی اولیه بعدی هم ناموفق خواهد بود
        // مگر اینکه خطای dispose مربوط به بخشی باشد که _initialized را false نکرده.
        // متد dispose در انتها _initialized را false می‌کند.
      }
    }

    // تلاش دوم: استفاده از Direct URL
    print(
        'Attempting Supabase initialization with Direct URL: $supabaseDirectUrl');
    try {
      await Supabase.initialize(
          url: supabaseDirectUrl, anonKey: supabaseAnonKey);
      print('Supabase initialized with Direct URL. Pinging...');
      await Supabase.instance.client.from('profiles').select().limit(1);
      print('Successfully connected to Supabase via Direct URL (Cloudflare).');
    } catch (err) {
      print('Supabase Direct URL attempt also failed: $err');
      print('Both API endpoints failed. Supabase could not be initialized.');
      // TODO: در اینجا بهتر است به کاربر اطلاع داده شود یا برنامه به صفحه خطا هدایت شود.
    }
  }
}
