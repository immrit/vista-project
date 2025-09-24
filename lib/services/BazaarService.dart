import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'AppInfoService.dart';

/// سرویس مدیریت اینتنت‌های کافه‌بازار
class BazaarService {
  static const String _appPackage = 'ir.coffevista.vista';

  /// باز کردن صفحه امتیازدهی در کافه‌بازار
  static Future<bool> openRatingPage(BuildContext context) async {
    try {
      const bazaarRatingUrl = 'bazaar://details?id=$_appPackage';

      if (await canLaunchUrl(Uri.parse(bazaarRatingUrl))) {
        await launchUrl(
          Uri.parse(bazaarRatingUrl),
          mode: LaunchMode.externalApplication,
        );

        _showSuccessMessage(context, 'متشکریم از امتیاز شما!');
        return true;
      } else {
        // اگر کافه‌بازار نصب نیست، به وب‌سایت هدایت کن
        return await _openWebPage(context, 'امتیازدهی');
      }
    } catch (e) {
      return await _openWebPage(context, 'امتیازدهی');
    }
  }

  /// باز کردن صفحه به‌روزرسانی در کافه‌بازار
  static Future<bool> openUpdatePage(BuildContext context) async {
    try {
      const bazaarUpdateUrl = 'bazaar://details?id=$_appPackage';

      if (await canLaunchUrl(Uri.parse(bazaarUpdateUrl))) {
        await launchUrl(
          Uri.parse(bazaarUpdateUrl),
          mode: LaunchMode.externalApplication,
        );

        _showSuccessMessage(context, 'صفحه ویستا در کافه‌بازار باز شد');
        return true;
      } else {
        // اگر کافه‌بازار نصب نیست، به وب‌سایت هدایت کن
        return await _openWebPage(context, 'به‌روزرسانی');
      }
    } catch (e) {
      return await _openWebPage(context, 'به‌روزرسانی');
    }
  }

  /// باز کردن صفحه اصلی اپلیکیشن در کافه‌بازار
  static Future<bool> openAppPage(BuildContext context) async {
    try {
      const bazaarAppUrl = 'bazaar://details?id=$_appPackage';

      if (await canLaunchUrl(Uri.parse(bazaarAppUrl))) {
        await launchUrl(
          Uri.parse(bazaarAppUrl),
          mode: LaunchMode.externalApplication,
        );

        _showSuccessMessage(context, 'صفحه ویستا در کافه‌بازار باز شد');
        return true;
      } else {
        // اگر کافه‌بازار نصب نیست، به وب‌سایت هدایت کن
        return await _openWebPage(context, 'صفحه اپلیکیشن');
      }
    } catch (e) {
      return await _openWebPage(context, 'صفحه اپلیکیشن');
    }
  }

  /// بررسی نصب بودن کافه‌بازار
  static Future<bool> isBazaarInstalled() async {
    try {
      const bazaarUrl = 'bazaar://details?id=$_appPackage';
      return await canLaunchUrl(Uri.parse(bazaarUrl));
    } catch (e) {
      return false;
    }
  }

  /// باز کردن صفحه وب کافه‌بازار
  static Future<bool> _openWebPage(BuildContext context, String action) async {
    try {
      const webUrl = 'https://cafebazaar.ir/app/$_appPackage';

      if (await canLaunchUrl(Uri.parse(webUrl))) {
        await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );

        _showInfoMessage(context, 'صفحه ویستا در کافه‌بازار باز شد');
        return true;
      } else {
        _showErrorMessage(context, 'خطا در باز کردن کافه‌بازار');
        return false;
      }
    } catch (e) {
      _showErrorMessage(context, 'خطا در باز کردن کافه‌بازار');
      return false;
    }
  }

  /// نمایش پیام موفقیت
  static void _showSuccessMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// نمایش پیام اطلاعاتی
  static void _showInfoMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// نمایش پیام خطا
  static void _showErrorMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// نمایش دیالوگ انتخاب روش امتیازدهی
  static void showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('امتیاز به ویستا'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('آیا از ویستا راضی هستید؟'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
              ],
            ),
            SizedBox(height: 8),
            Text('۵ ستاره', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
              'امتیاز شما به ما کمک می‌کند تا ویستا را بهتر کنیم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openRatingPage(context);
            },
            child: const Text('امتیاز در کافه‌بازار'),
          ),
        ],
      ),
    );
  }

  /// نمایش دیالوگ بررسی به‌روزرسانی
  static void showUpdateDialog(BuildContext context) {
    final bazaarInfo = AppInfoService.getBazaarInfo();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بررسی به‌روزرسانی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
                'برای بررسی نسخه‌های جدید ویستا، روی "بررسی به‌روزرسانی" کلیک کنید'),
            const SizedBox(height: 16),
            Text(
              'نسخه فعلی: ${bazaarInfo['version']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'امتیاز: ${bazaarInfo['rating']} از ۵ (${bazaarInfo['ratingCount']})',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'نصب: ${bazaarInfo['installCount']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openUpdatePage(context);
            },
            child: const Text('بررسی به‌روزرسانی'),
          ),
        ],
      ),
    );
  }
}
