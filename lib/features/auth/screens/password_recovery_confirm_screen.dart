import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Vista/core/security/input_policy.dart';

import '../data/auth_repository.dart';
import '../widgets/ribbon_background.dart';

class PasswordRecoveryConfirmScreen extends StatefulWidget {
  const PasswordRecoveryConfirmScreen({super.key});

  @override
  State<PasswordRecoveryConfirmScreen> createState() =>
      _PasswordRecoveryConfirmScreenState();
}

class _PasswordRecoveryConfirmScreenState
    extends State<PasswordRecoveryConfirmScreen> {
  final TextEditingController _codeController = TextEditingController();

  String? _optionId;
  String _method = 'sms';
  String _masked = '';

  bool _isLoading = false;

  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _optionId = args?['optionId'] as String?;
      _method = (args?['method'] as String?)?.toLowerCase() ?? 'sms';
      _masked = (args?['masked'] as String?) ?? '';

      if (_optionId == null || _optionId!.isEmpty) {
        _showError('خطا: اطلاعات بازیابی ناقص است');
        return;
      }
      _startResendCountdown(60);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown -= 1);
      }
    });
  }

  Future<void> _resendCode() async {
    final optionId = _optionId;
    if (optionId == null || optionId.isEmpty) return;
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);
    try {
      await AuthRepository().sendRecoveryCode(optionId);
      if (!mounted) return;
      _startResendCountdown(60);
      _showSuccess('کد مجدداً ارسال شد');
    } catch (_) {
      _showError('خطا در ارسال مجدد کد. لطفاً دوباره تلاش کنید');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final optionId = _optionId;
    if (optionId == null || optionId.isEmpty) return;

    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showError('کد را وارد کنید');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await AuthRepository().verifyRecoveryCode(
        optionId: optionId,
        code: code,
      );
      if (!mounted) return;

      // Navigate to the set password screen
      Navigator.pushNamed(
        context,
        '/reset-password-set',
        arguments: {'token': token},
      );
    } catch (e) {
      _showError(e is String ? e : 'کد نامعتبر است یا خطایی رخ داده است');
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
    final targetLabel = _method == 'email' ? 'ایمیل' : 'پیامک';

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
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'تایید کد',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _masked.isEmpty
                          ? 'کد ارسال‌شده را وارد کنید'
                          : 'کد ارسال‌شده به $targetLabel ($_masked) را وارد کنید',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'کد',
                        prefixIcon: Icon(Icons.verified_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_resendCountdown > 0)
                      Text(
                        'ارسال مجدد کد در $_resendCountdown ثانیه',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      )
                    else
                      TextButton(
                        onPressed: _isLoading ? null : _resendCode,
                        child: const Text('ارسال مجدد کد'),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تایید کد'),
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
