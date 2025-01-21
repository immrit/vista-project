import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  // متد لانچ تلگرام
  Future<void> _launchTelegram(BuildContext context) async {
    final Uri telegramUrl = Uri.parse('https://t.me/i_mrit');
    try {
      await launchUrl(telegramUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar(context, 'امکان باز کردن تلگرام وجود ندارد');
    }
  }

  // متد ارسال ایمیل
  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'ahamdesmaili.official@gmail.com',
    );
    try {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar(context, 'امکان ارسال ایمیل وجود ندارد');
    }
  }

  // متد نمایش اسنک بار خطا
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Vazir'),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پشتیبانی'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'تمرکز ویستا نوت علاوه بر امنیت که تاکید شدید و دائمی ما در حفظ اطلاعات کاربران بوده آسودگی کاربران از همه جهات نیز میباشد \n منتظر بازخوردهای سازنده شما هستیم :)',
                    style: TextStyle(fontFamily: 'Vazir'),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 50),

                // دکمه تلگرام
                ElevatedButton.icon(
                  onPressed: () => _launchTelegram(context),
                  icon: const Icon(Icons.telegram, color: Colors.white),
                  label: const Text(
                    'تماس با تلگرام',
                    style: TextStyle(color: Colors.white, fontFamily: 'Vazir'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),

                const SizedBox(height: 20),

                // دکمه ارسال ایمیل
                ElevatedButton.icon(
                  onPressed: () => _launchEmail(context),
                  icon: const Icon(Icons.email, color: Colors.white),
                  label: const Text(
                    'ارسال ایمیل',
                    style: TextStyle(color: Colors.white, fontFamily: 'Vazir'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
