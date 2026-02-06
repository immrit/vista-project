import 'package:flutter/material.dart';

import '../../../services/auth_api_service.dart';
import '../widgets/ribbon_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _identifierController = TextEditingController();

  bool _isLoading = false;
  List<RecoveryOption> _options = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final prefill = (args?['prefill'] as String?)?.trim();
      if (prefill != null && prefill.isNotEmpty) {
        _identifierController.text = prefill;
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showError('شماره موبایل، ایمیل یا نام کاربری را وارد کنید');
      return;
    }

    setState(() {
      _isLoading = true;
      _options = const [];
    });

    try {
      final options = await AuthApiService().getRecoveryOptions(identifier);
      if (!mounted) return;
      setState(() {
        _options = options;
      });

      if (options.isEmpty) {
        _showError('راه بازیابی فعالی برای این حساب پیدا نشد');
      }
    } catch (e) {
      _showError(e is String
          ? e
          : 'خطا در دریافت گزینه‌های بازیابی. لطفاً دوباره تلاش کنید');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectOption(RecoveryOption option) async {
    setState(() => _isLoading = true);
    try {
      await AuthApiService().sendRecoveryCode(option.id);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/reset-password-confirm',
        arguments: {
          'optionId': option.id,
          'method': option.method,
          'masked': option.masked,
        },
      );
    } catch (e) {
      _showError(e is String ? e : 'خطا در ارسال کد. لطفاً دوباره تلاش کنید');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
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
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'بازیابی رمز عبور',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'برای ادامه، نام کاربری یا اطلاعات ورود را وارد کنید',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _identifierController,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'شماره موبایل، ایمیل یا نام کاربری',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onSubmitted: (_) => _loadOptions(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadOptions,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ادامه'),
                    ),
                    if (_options.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'ارسال کد به:',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      ..._options.map(
                        (opt) => Card(
                          child: ListTile(
                            leading: Icon(
                              opt.method == 'sms'
                                  ? Icons.sms_outlined
                                  : Icons.email_outlined,
                            ),
                            title: Text(
                              opt.method == 'sms'
                                  ? 'ارسال پیامک به ${opt.masked}'
                                  : 'ارسال ایمیل به ${opt.masked}',
                              textDirection: TextDirection.rtl,
                            ),
                            onTap: _isLoading ? null : () => _selectOption(opt),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _options = const []),
                        child: const Text('ویرایش اطلاعات'),
                      ),
                    ],
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
