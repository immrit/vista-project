import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/core/security/input_policy.dart';

import '../data/auth_repository.dart';
import '../providers/auth_controller.dart';
import '../widgets/ribbon_background.dart';

class MandatoryPasswordScreen extends ConsumerStatefulWidget {
  const MandatoryPasswordScreen({super.key});

  @override
  ConsumerState<MandatoryPasswordScreen> createState() =>
      _MandatoryPasswordScreenState();
}

class _MandatoryPasswordScreenState
    extends ConsumerState<MandatoryPasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showError('رمز عبور را وارد کنید');
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
      final token = await TokenStorage.getAccessToken();
      if (token == null) {
        throw 'نشست شما معتبر نیست';
      }

      // Use Set2FAPassword to set the password hash directly.
      await AuthRepository().set2FaPassword(
        password: newPassword,
        accessToken: token,
      );

      final user = await AuthRepository().me(token);
      ref.read(authControllerProvider.notifier).acceptAuthenticatedUser(user);

      if (!mounted) return;
      _showSuccess('رمز عبور با موفقیت ثبت شد');

      // Navigate to home or profile setup based on user status
      final finalAuthState = ref.read(authControllerProvider);
      if (finalAuthState.isNewUser ||
          finalAuthState.currentUser?.profileCompleted == false) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError(e is String ? e : 'خطایی در ثبت رمز عبور رخ داد');
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

  // Prevent back navigation by overriding WillPopScope / PopScope
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent going back
      child: Directionality(
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
                      const Spacer(),
                      const Icon(Icons.security, size: 64, color: Colors.teal),
                      const SizedBox(height: 24),
                      Text(
                        'تعریف رمز عبور اجباری',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'شما با موفقیت وارد شدید.\nبرای امنیت بیشتر و جلوگیری از نیاز به ارسال پیامک در دفعات بعد، لطفاً یک رمز عبور برای حساب خود تعیین کنید.',
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
                          hintText: 'رمز عبور',
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
                          hintText: 'تایید رمز عبور',
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
                            : const Text('ثبت رمز عبور و ورود'),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
