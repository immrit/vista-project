import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../homeScreen.dart';
import '../../../provider/security_provider.dart';
import '../../../model/SecurityModels.dart';
import '../../../security/totp_service.dart';

class TwoFactorVerificationScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? redirectRoute;
  final Map<String, dynamic>? routeArguments;

  const TwoFactorVerificationScreen({
    super.key,
    required this.userId,
    this.redirectRoute,
    this.routeArguments,
  });

  @override
  ConsumerState<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends ConsumerState<TwoFactorVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isVerifying = false;
  String _errorMessage = '';
  bool _showBackupCodeInput = false;
  final TextEditingController _backupCodeController = TextEditingController();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _backupCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < _controllers.length - 1) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  String _getCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyCode() async {
    if (_getCode().length != 6) {
      setState(() {
        _errorMessage = 'لطفاً کد ۶ رقمی را کامل وارد کنید';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      // بررسی کد در جدول user_security
      final response = await supabase
          .from('user_security')
          .select('*')
          .eq('user_id', widget.userId)
          .single();

      if (response == null) {
        throw Exception('اطلاعات امنیتی کاربر یافت نشد');
      }

      final twoFactorSecret = response['two_factor_secret'] as String?;
      if (twoFactorSecret == null) {
        throw Exception('تایید دو مرحله‌ای فعال نشده است');
      }

      // تایید کد TOTP با استفاده از سرویس
      final isValidCode = TOTPService.verifyCode(twoFactorSecret, _getCode());
      if (!isValidCode) {
        throw Exception('کد وارد شده صحیح نیست');
      }

      // ثبت لاگ امنیتی
      await supabase.from('security_logs').insert({
        'user_id': widget.userId,
        'event_type': '2fa_verification_success',
        'description': 'تایید دو مرحله‌ای موفق',
        'created_at': DateTime.now().toIso8601String(),
      });

      // انتقال به صفحه اصلی
      if (mounted) {
        if (widget.redirectRoute != null) {
          Navigator.of(context).pushReplacementNamed(
            widget.redirectRoute!,
            arguments: widget.routeArguments,
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'کد وارد شده صحیح نیست. لطفاً دوباره تلاش کنید.';
      });

      // ثبت لاگ امنیتی ناموفق
      try {
        await supabase.from('security_logs').insert({
          'user_id': widget.userId,
          'event_type': '2fa_verification_failed',
          'description': 'تایید دو مرحله‌ای ناموفق',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (logError) {
        print('خطا در ثبت لاگ: $logError');
      }
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _verifyBackupCode() async {
    final backupCode = _backupCodeController.text.trim();
    if (backupCode.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً کد پشتیبان را وارد کنید';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      // بررسی کد پشتیبان در جدول user_security
      final response = await supabase
          .from('user_security')
          .select('backup_codes')
          .eq('user_id', widget.userId)
          .single();

      if (response == null) {
        throw Exception('اطلاعات امنیتی کاربر یافت نشد');
      }

      final backupCodes = List<String>.from(response['backup_codes'] ?? []);
      if (!backupCodes.contains(backupCode)) {
        throw Exception('کد پشتیبان صحیح نیست');
      }

      // حذف کد پشتیبان استفاده شده
      backupCodes.remove(backupCode);
      await supabase.from('user_security').update({
        'backup_codes': backupCodes,
      }).eq('user_id', widget.userId);

      // ثبت لاگ امنیتی
      await supabase.from('security_logs').insert({
        'user_id': widget.userId,
        'event_type': 'backup_code_used',
        'description': 'استفاده از کد پشتیبان',
        'created_at': DateTime.now().toIso8601String(),
      });

      // انتقال به صفحه اصلی
      if (mounted) {
        if (widget.redirectRoute != null) {
          Navigator.of(context).pushReplacementNamed(
            widget.redirectRoute!,
            arguments: widget.routeArguments,
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'کد پشتیبان صحیح نیست. لطفاً دوباره تلاش کنید.';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _toggleBackupCodeInput() {
    setState(() {
      _showBackupCodeInput = !_showBackupCodeInput;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('تایید دو مرحله‌ای'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // آیکون و عنوان
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.security,
                  size: 40,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'تایید دو مرحله‌ای',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              const Text(
                'کد ۶ رقمی ارسال شده به اپلیکیشن احراز هویت خود را وارد کنید',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ورودی کد ۶ رقمی
              if (!_showBackupCodeInput) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _errorMessage.isNotEmpty
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // دکمه تایید
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'تایید',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],

              // ورودی کد پشتیبان
              if (_showBackupCodeInput) ...[
                TextField(
                  controller: _backupCodeController,
                  decoration: InputDecoration(
                    labelText: 'کد پشتیبان',
                    hintText: 'کد ۸ رقمی پشتیبان را وارد کنید',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.backup),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 9, // فرمت: XXXX-XXXX
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyBackupCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'تایید کد پشتیبان',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // دکمه تغییر نوع ورودی
              TextButton(
                onPressed: _toggleBackupCodeInput,
                child: Text(
                  _showBackupCodeInput
                      ? 'ورود با کد تایید'
                      : 'استفاده از کد پشتیبان',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),

              // نمایش خطا
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // راهنما
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'راهنما',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'اگر اپلیکیشن احراز هویت در دسترس نیست، می‌توانید از کدهای پشتیبان استفاده کنید.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
