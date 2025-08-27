import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import '../../../security/simple_2fa_service.dart';
import '../../../provider/theme_provider.dart';

class TwoFactorVerificationScreen extends ConsumerStatefulWidget {
  final String userId;
  final VoidCallback onSuccess;

  const TwoFactorVerificationScreen({
    super.key,
    required this.userId,
    required this.onSuccess,
  });

  @override
  ConsumerState<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends ConsumerState<TwoFactorVerificationScreen> {
  final TextEditingController _totpCodeController = TextEditingController();
  final TextEditingController _backupCodeController = TextEditingController();
  final FocusNode _totpCodeFocusNode = FocusNode();
  final FocusNode _backupCodeFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _showBackupCodeInput = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _totpCodeController.dispose();
    _backupCodeController.dispose();
    _totpCodeFocusNode.dispose();
    _backupCodeFocusNode.dispose();
    super.dispose();
  }

  /// تایید کد 6 رقمی کاربر
  Future<void> _verifyUserCode() async {
    final code = _totpCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً کد 6 رقمی را وارد کنید';
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'کد باید دقیقاً 6 رقم باشد';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      developer.log('Verifying user code for user: ${widget.userId}',
          name: 'TwoFactorVerification');

      // اعتبارسنجی کد کاربر
      final isValid =
          await Simple2FAService.validateUserCode(widget.userId, code);

      developer.log('Code validation result: $isValid',
          name: 'TwoFactorVerification');

      if (isValid) {
        developer.log('Code validation successful, marking session as verified',
            name: 'TwoFactorVerification');

        // علامت‌گذاری نشست فعلی به عنوان تایید شده
        await Simple2FAService.markSessionAsVerified(widget.userId);

        developer.log('Session marked as verified, calling onSuccess',
            name: 'TwoFactorVerification');

        // کمی صبر کن و سپس به صفحه اصلی برو
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          widget.onSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'کد وارد شده صحیح نیست';
        });
      }
    } catch (e) {
      developer.log('Error verifying user code: $e',
          name: 'TwoFactorVerification');
      setState(() {
        _errorMessage = 'خطا در تایید کد: $e';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  /// تایید کد بکاپ
  Future<void> _verifyBackupCode() async {
    final code = _backupCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً کد بکاپ را وارد کنید';
      });
      return;
    }

    if (code.length != 8) {
      setState(() {
        _errorMessage = 'کد بکاپ باید دقیقاً 8 رقم باشد';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      developer.log('Verifying backup code for user: ${widget.userId}',
          name: 'TwoFactorVerification');

      // اعتبارسنجی کد بکاپ
      final isValid =
          await Simple2FAService.validateBackupCode(widget.userId, code);

      developer.log('Backup code validation result: $isValid',
          name: 'TwoFactorVerification');

      if (isValid) {
        developer.log(
            'Backup code validation successful, marking session as verified',
            name: 'TwoFactorVerification');

        // علامت‌گذاری نشست فعلی به عنوان تایید شده
        await Simple2FAService.markSessionAsVerified(widget.userId);

        developer.log('Session marked as verified, calling onSuccess',
            name: 'TwoFactorVerification');
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = 'کد بکاپ وارد شده صحیح نیست';
        });
      }
    } catch (e) {
      developer.log('Error verifying backup code: $e',
          name: 'TwoFactorVerification');
      setState(() {
        _errorMessage = 'خطا در تایید کد بکاپ: $e';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  /// تغییر به حالت ورود کد بکاپ
  void _switchToBackupCode() {
    setState(() {
      _showBackupCodeInput = true;
      _errorMessage = '';
    });
    _backupCodeFocusNode.requestFocus();
  }

  /// تغییر به حالت ورود کد کاربر
  void _switchToTOTPCode() {
    setState(() {
      _showBackupCodeInput = false;
      _errorMessage = '';
    });
    _totpCodeFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'تایید احراز هویت دو مرحله‌ای',
          style: TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // آیکون امنیت
            Icon(
              Icons.security,
              size: 80,
              color: primaryColor,
            ),
            const SizedBox(height: 32),

            // عنوان
            Text(
              'احراز هویت دو مرحله‌ای',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Vazir',
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? theme.textTheme.headlineMedium?.color
                        : primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // توضیحات
            Text(
              _showBackupCodeInput
                  ? 'کد بکاپ 8 رقمی خود را وارد کنید'
                  : 'کد 6 رقمی احراز هویت خود را وارد کنید',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Vazir',
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ورودی کد
            if (!_showBackupCodeInput) ...[
              // ورودی کد 6 رقمی
              TextField(
                controller: _totpCodeController,
                focusNode: _totpCodeFocusNode,
                decoration: InputDecoration(
                  labelText: 'کد 6 رقمی',
                  hintText: '123456',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.security),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  letterSpacing: 2,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _verifyUserCode(),
              ),
            ] else ...[
              // ورودی کد بکاپ
              TextField(
                controller: _backupCodeController,
                focusNode: _backupCodeFocusNode,
                decoration: InputDecoration(
                  labelText: 'کد بکاپ 8 رقمی',
                  hintText: '12345678',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.backup),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  letterSpacing: 2,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onSubmitted: (_) => _verifyBackupCode(),
              ),
            ],

            const SizedBox(height: 24),

            // دکمه تایید
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying
                    ? null
                    : (_showBackupCodeInput
                        ? _verifyBackupCode
                        : _verifyUserCode),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('در حال تایید...'),
                        ],
                      )
                    : Text(
                        _showBackupCodeInput ? 'تایید کد بکاپ' : 'تایید کد',
                        style: const TextStyle(
                          fontFamily: 'Vazir',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // دکمه تغییر حالت
            TextButton(
              onPressed: _showBackupCodeInput
                  ? _switchToTOTPCode
                  : _switchToBackupCode,
              child: Text(
                _showBackupCodeInput
                    ? 'استفاده از کد 6 رقمی'
                    : 'استفاده از کد بکاپ',
                style: const TextStyle(
                  fontFamily: 'Vazir',
                  color: Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // نمایش خطا
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    fontFamily: 'Vazir',
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),

            // راهنما
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'راهنما',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showBackupCodeInput
                        ? 'کدهای بکاپ 8 رقمی هستند و پس از استفاده حذف می‌شوند'
                        : 'کد 6 رقمی خود را که هنگام فعال‌سازی 2FA تعیین کرده‌اید وارد کنید',
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
