import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({Key? key}) : super(key: key);

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = supabase.auth.currentUser != null
      ? TextEditingController(text: supabase.auth.currentUser!.email)
      : TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تماس با ما'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'ارتباط با تیم ویستا',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/images/contact_us.jpg', // تصویر خود را اضافه کنید
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.contact_support,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32.0),
              const Text(
                'ما همیشه آماده کمک به شما هستیم',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'تیم پشتیبانی ویستا در ۷ روز هفته آماده پاسخگویی به سؤالات، پیشنهادات و مشکلات شما است. با ما از طریق یکی از روش‌های زیر در تماس باشید:',
                style: TextStyle(
                  fontSize: 16.0,
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 32.0),
              _buildContactCard(
                context,
                icon: Icons.email_outlined,
                title: 'ایمیل',
                subtitle: 'ahmadesmaili.official@gmail.com',
                onTap: () => _launchEmail('ahmadesmaili.official@gmail.com'),
                onCopy: () => _copyToClipboard(
                  context,
                  'ahmadesmaili.official@gmail.com',
                  'ایمیل',
                ),
              ),
              const SizedBox(height: 16.0),
              _buildContactCard(
                context,
                icon: Icons.telegram,
                title: 'تلگرام',
                subtitle: 't.me/vistasupp',
                onTap: () => _launchURL('https://t.me/vistasupp'),
                onCopy: () => _copyToClipboard(
                  context,
                  't.me/vistasupp',
                  'آدرس تلگرام',
                ),
              ),
              const SizedBox(height: 32.0),
              _buildContactForm(context),
              const SizedBox(height: 30.0),
              const Center(
                child: Text(
                  'ساعات پاسخگویی: ۹ صبح تا ۶ عصر (شنبه تا پنجشنبه)',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.grey),
                onPressed: onCopy,
                tooltip: 'کپی کردن',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'فرم تماس با ما',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'نام و نام خانوادگی',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً نام خود را وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'ایمیل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً ایمیل خود را وارد کنید';
                  }
                  // یک الگوی ساده برای بررسی ایمیل
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'لطفاً یک ایمیل معتبر وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'موضوع',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.subject),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً موضوع پیام را وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'پیام شما',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً پیام خود را وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitContactForm,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text(
                          'ارسال پیام',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitContactForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSubmitting = true;
        });

        // تهیه داده‌ها برای ارسال به سوپابیس
        final contactData = {
          'full_name': _nameController.text,
          'email': supabase.auth.currentUser?.email,
          'subject': _subjectController.text,
          'message': _messageController.text,
          // اگر کاربر لاگین باشد، شناسه کاربر را اضافه می‌کنیم
          if (_supabase.auth.currentUser != null)
            'user_id': _supabase.auth.currentUser!.id,
        };

        // ارسال داده‌ها به جدول contact_requests در سوپابیس
        await _supabase.from('contact_requests').insert(contactData);

        // نمایش پیام موفقیت‌آمیز
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('پیام شما با موفقیت ارسال شد. با تشکر از همراهی شما.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }

        // پاک کردن فرم
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در ارسال پیام: ${error.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'امکان باز کردن ایمیل وجود ندارد: $email';
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'امکان باز کردن لینک وجود ندارد: $url';
    }
  }

  Future<void> _copyToClipboard(
      BuildContext context, String text, String itemName) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$itemName با موفقیت کپی شد'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
