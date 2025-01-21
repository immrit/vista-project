import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;

  const ResetPasswordPage({super.key, required this.token});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لطفاً رمز عبور جدید را وارد کنید')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // استفاده از توکن و تنظیم رمز عبور جدید
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رمز عبور با موفقیت تغییر یافت')));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطایی رخ داد، لطفا دوباره تلاش کنید')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تغییر رمز عبور'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: 'رمز عبور جدید'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('ثبت رمز عبور جدید'),
            ),
          ],
        ),
      ),
    );
  }
}
