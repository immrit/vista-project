import 'package:flutter/material.dart';
import 'package:Vista/core/security/input_policy.dart';

import '../../../utils/directional_navigation.dart';
import '../data/auth_repository.dart';
import '../widgets/ribbon_background.dart';

class PasswordSetScreen extends StatefulWidget {
  const PasswordSetScreen({super.key});

  @override
  State<PasswordSetScreen> createState() => _PasswordSetScreenState();
}

class _PasswordSetScreenState extends State<PasswordSetScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _token;

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _token = args?['token'] as String?;

      if (_token == null || _token!.isEmpty) {
        _showError('توکن بازیابی نامعتبر است');
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showError('رمز جدید را وارد کنید');
      return;
    }
    final passwordValidation = validatePasswordBalanced(newPassword);
    if (!passwordValidation.isValid) {
      _showError(passwordValidation.message);
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('رمز عبور و تایید آن یکسان نیستند');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthRepository().completeRecovery(
        token: token,
        newPassword: newPassword,
      );
      if (!mounted) return;
      _showSuccess('رمز عبور با موفقیت تغییر یافت');
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) {
      _showError(e is String ? e : 'خطایی در تغییر رمز عبور رخ داد');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: RibbonBackground()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: isLocaleRtl(context)
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(directionalBackIcon(context)),
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'تعیین رمز عبور جدید',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لطفاً رمز عبور جدید خود را وارد کنید',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'رمز عبور جدید',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: _isLoading
                              ? null
                              : () => setState(() =>
                                  _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _complete(),
                      decoration: InputDecoration(
                        hintText: 'تایید رمز عبور جدید',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: _isLoading
                              ? null
                              : () => setState(() => _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _complete,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تغییر رمز عبور'),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
