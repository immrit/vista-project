import 'package:Vista/view/util/widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;

  const VerifyCodePage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _newPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyAndResetPassword() async {
    if (_newPasswordController.text.isEmpty || _otpController.text.isEmpty) {
      context.showSnackBar('لطفاً کد تایید و رمز عبور جدید را وارد کنید',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text,
        type: OtpType.recovery,
      );

      if (res.user != null) {
        await supabase.auth
            .updateUser(UserAttributes(password: _newPasswordController.text));
      }
      if (mounted) {
        context.showSnackBar('رمز عبور با موفقیت تغییر کرد');
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('خطا در تغییر رمز عبور: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغییر رمز عبور')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'کد تایید',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'رمز عبور جدید',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyAndResetPassword,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('تایید و تغییر رمز عبور'),
            ),
          ],
        ),
      ),
    );
  }
}
