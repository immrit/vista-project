import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../main.dart';
import '../../../../provider/provider.dart';

class EmailEditPage extends ConsumerStatefulWidget {
  const EmailEditPage({super.key});

  @override
  ConsumerState<EmailEditPage> createState() => _EmailEditPageState();
}

class _EmailEditPageState extends ConsumerState<EmailEditPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _isVerifying = false;
  String? _newEmail;
  String? _currentEmail;

  // Pattern validation for email
  final _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  void _loadCurrentEmail() {
    _currentEmail = supabase.auth.currentUser?.email;
    if (_currentEmail != null) {
      _emailController.text = _currentEmail!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ویرایش ایمیل'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // نمایش ایمیل فعلی
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ایمیل فعلی',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentEmail ?? 'در حال بارگذاری...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // فرم ویرایش ایمیل
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ایمیل جدید',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isCodeSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: _isCodeSent ? Colors.white : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'لطفاً ایمیل خود را وارد کنید';
                      }
                      if (!_emailPattern.hasMatch(value.trim())) {
                        return 'لطفاً یک ایمیل معتبر وارد کنید';
                      }
                      if (value.trim() == _currentEmail) {
                        return 'ایمیل جدید باید با ایمیل فعلی متفاوت باشد';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // دکمه ارسال کد تایید
                  if (!_isCodeSent) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('ارسال کد تایید'),
                      ),
                    ),
                  ],

                  // بخش وارد کردن کد تایید
                  if (_isCodeSent) ...[
                    const Divider(height: 32),

                    const Text(
                      'کد تایید',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'کد تایید به $_newEmail ارسال شد. لطفاً کد را وارد کنید:',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _verificationCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: '123456',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'لطفاً کد تایید را وارد کنید';
                        }
                        if (value.trim().length != 6) {
                          return 'کد تایید باید ۶ رقم باشد';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // دکمه‌های عمل
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isVerifying ? null : _cancelEmailChange,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('انصراف'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyEmailChange,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('تایید ایمیل'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // دکمه ارسال مجدد کد
                    Center(
                      child: TextButton(
                        onPressed: _sendVerificationCode,
                        child: const Text('ارسال مجدد کد تایید'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // راهنمای تغییر ایمیل
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'نکات مهم',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• پس از تغییر ایمیل، باید با ایمیل جدید وارد شوید\n'
                    '• کد تایید فقط ۱۰ دقیقه معتبر است\n'
                    '• در صورت عدم دریافت کد، پوشه اسپم را بررسی کنید',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _newEmail = _emailController.text.trim();

    try {
      // ارسال کد تایید برای تغییر ایمیل
      final response = await supabase.auth.updateUser(
        UserAttributes(
          email: _newEmail,
          data: {'redirectTo': 'vista://auth/email-change'},
        ),
      );

      if (response.user != null) {
        setState(() {
          _isCodeSent = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کد تایید به $_newEmail ارسال شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'خطا در ارسال کد تایید';
      if (e.toString().contains('email')) {
        errorMessage = 'این ایمیل قبلاً استفاده شده است';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyEmailChange() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);
    final code = _verificationCodeController.text.trim();

    try {
      // تایید کد و تکمیل تغییر ایمیل
      final response = await supabase.auth.verifyOTP(
        type: OtpType.emailChange,
        token: code,
        email: _newEmail,
      );

      if (response.user != null) {
        // به‌روزرسانی پروفایل با ایمیل جدید
        await supabase.from('profiles').update({
          'email': _newEmail,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', response.user!.id);

        // بازخوانی اطلاعات پروفایل
        final _ = ref.refresh(profileProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ایمیل با موفقیت تغییر کرد'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _isVerifying = false);

      String errorMessage = 'کد تایید نامعتبر است';
      if (e.toString().contains('expired')) {
        errorMessage = 'کد تایید منقضی شده است';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEmailChange() {
    setState(() {
      _isCodeSent = false;
      _newEmail = null;
      _verificationCodeController.clear();
      _emailController.text = _currentEmail ?? '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تغییر ایمیل لغو شد'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }
}
