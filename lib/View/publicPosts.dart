import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Provider/appwriteProvider.dart';

class Publicposts extends ConsumerWidget {
  const Publicposts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.read(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Public Posts'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // سایر محتویات صفحه می‌توانند اینجا قرار بگیرند.

            ElevatedButton(
              onPressed: () async {
                final user = await account.get();
                // منطق خروج از سشن در اینجا قرار می‌گیرد
                await account.deleteSessions().then((v) {
                  Navigator.pushReplacementNamed(context, '/login');
                });
              },
              child: Text('خروج'),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _logout(WidgetRef ref) async {
  //   // منطق خروج از سشن را اینجا پیاده‌سازی کنید
  //   // به عنوان مثال، می‌توانید از authStateProvider برای بروزرسانی وضعیت استفاده کنید

  //   // فرض کنیم که اینجا تابعی دارید برای مدیریت خروج
  //   // به عنوان نمونه:
  //   await ;

  //   // پس از خروج، می‌توانید کاربر را به صفحه ورود بازگردانید
  //   // Navigator.pushReplacementNamed(context, '/login');
  // }
}
