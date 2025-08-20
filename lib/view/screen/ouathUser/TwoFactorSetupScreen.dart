import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';

import '../../../provider/security_provider.dart';
import '../../../security/simple_2fa_service.dart';

class TwoFactorSetupScreen extends ConsumerStatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  ConsumerState<TwoFactorSetupScreen> createState() =>
      _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends ConsumerState<TwoFactorSetupScreen> {
  bool _isLoading = false;
  String? _password;
  List<String>? _backupCodes;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _verificationController = TextEditingController();
  String _errorMessage = '';
  bool _isVerifying = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _generatePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('🔐 شروع تولید رمز 2FA...');

      // تولید رمز 2FA
      final password = Simple2FAService.generatePassword();
      if (password.isEmpty) {
        throw Exception('رمز تولید نشد');
      }
      debugPrint('🔐 رمز تولید شد: $password');

      // تولید کدهای پشتیبان
      final backupCodes = Simple2FAService.generateBackupCodes();
      if (backupCodes.isEmpty) {
        throw Exception('کدهای پشتیبان تولید نشدند');
      }
      debugPrint('🔐 کدهای پشتیبان تولید شدند: ${backupCodes.length} کد');

      setState(() {
        _password = password;
        _backupCodes = backupCodes;
        _isLoading = false;
      });

      debugPrint('✅ رمز و کدهای پشتیبان در state ذخیره شدند');
    } catch (e) {
      debugPrint('❌ خطا در تولید رمز: $e');
      setState(() {
        _errorMessage = 'خطا در تولید رمز: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAndEnable() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final verificationCode = _verificationController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً رمز و تکرار رمز را وارد کنید';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'رمز و تکرار رمز یکسان نیستند';
      });
      return;
    }

    if (password != _password) {
      setState(() {
        _errorMessage = 'رمز وارد شده صحیح نیست';
      });
      return;
    }

    if (verificationCode.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً کد تایید را وارد کنید';
      });
      return;
    }

    // بررسی کد پشتیبان
    if (_backupCodes != null && _backupCodes!.contains(verificationCode)) {
      // حذف کد استفاده شده
      final updatedCodes = Simple2FAService.removeUsedBackupCode(
          _backupCodes!, verificationCode);

      setState(() {
        _backupCodes = updatedCodes;
      });

      // فعال کردن تایید دو مرحله‌ای
      try {
        await ref
            .read(securityNotifierProvider.notifier)
            .enableSimpleTwoFactor(_password!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تایید دو مرحله‌ای با موفقیت فعال شد'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'خطا در فعال‌سازی: $e';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'کد تایید وارد شده صحیح نیست';
      });
    }
  }

  Future<void> _saveBackupCodesAsImage() async {
    if (_backupCodes == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // ایجاد تصویر از کدهای پشتیبان
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // پس‌زمینه سفید
      canvas.drawRect(Rect.fromLTWH(0, 0, 400.0, 600.0), paint);

      // عنوان
      final titleStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      );
      final titleSpan = TextSpan(
        text: 'کدهای پشتیبان Vista',
        style: titleStyle,
      );
      final titlePainter = TextPainter(
        text: titleSpan,
        textDirection: TextDirection.rtl,
      );
      titlePainter.layout();
      titlePainter.paint(canvas, Offset(200.0 - titlePainter.width / 2, 30.0));

      // توضیحات
      final descStyle = TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      );
      final descSpan = TextSpan(
        text:
            'این کدها را در جای امنی نگهداری کنید\nهر کد فقط یک بار قابل استفاده است',
        style: descStyle,
      );
      final descPainter = TextPainter(
        text: descSpan,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      descPainter.layout();
      descPainter.paint(canvas, Offset(200.0 - descPainter.width / 2, 80.0));

      // کدهای پشتیبان
      final codeStyle = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        color: Colors.black,
      );

      for (int i = 0; i < _backupCodes!.length; i++) {
        final y = 140 + (i * 40);
        final codeSpan = TextSpan(
          text: '${i + 1}. ${_backupCodes![i]}',
          style: codeStyle,
        );
        final codePainter = TextPainter(
          text: codeSpan,
          textDirection: TextDirection.rtl,
        );
        codePainter.layout();
        codePainter.paint(
            canvas, Offset(200.0 - codePainter.width / 2, y.toDouble()));
      }

      // تاریخ تولید
      final dateStyle = TextStyle(
        fontSize: 12,
        color: Colors.grey[500],
      );
      final dateSpan = TextSpan(
        text: 'تاریخ تولید: ${DateTime.now().toString().substring(0, 19)}',
        style: dateStyle,
      );
      final datePainter = TextPainter(
        text: dateSpan,
        textDirection: TextDirection.rtl,
      );
      datePainter.layout();
      datePainter.paint(canvas, Offset(200.0 - datePainter.width / 2, 580.0));

      // تبدیل به تصویر
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 600);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // ذخیره در گالری
      await Gal.putImageBytes(
        bytes,
        name: 'vista_backup_codes_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کدهای پشتیبان در گالری ذخیره شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ خطا در ذخیره تصویر: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تنظیم تایید دو مرحله‌ای'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // آیکون و عنوان
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.security,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'تنظیم تایید دو مرحله‌ای',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      'برای فعال‌سازی تایید دو مرحله‌ای، رمز تولید شده را به خاطر بسپارید',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // مرحله 1: رمز تولید شده
                  _buildStep(
                    1,
                    'رمز تولید شده',
                    'رمز زیر را به خاطر بسپارید و در جای امنی نگهداری کنید',
                    Icons.key,
                    Colors.green,
                  ),

                  const SizedBox(height: 16),

                  // نمایش رمز
                  if (_password != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.key,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'رمز 2FA',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // رمز
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _password!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _password!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('رمز کپی شد')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'این رمز را در جای امنی یادداشت کنید',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // مرحله 2: ورودی رمز
                  _buildStep(
                    2,
                    'تایید رمز',
                    'رمز تولید شده را در فیلدهای زیر وارد کنید',
                    Icons.input,
                    theme.colorScheme.primary,
                  ),

                  const SizedBox(height: 16),

                  // ورودی رمز
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'رمز',
                      hintText: 'رمز تولید شده را وارد کنید',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !_showPassword,
                  ),

                  const SizedBox(height: 16),

                  // ورودی تکرار رمز
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'تکرار رمز',
                      hintText: 'رمز را دوباره وارد کنید',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !_showConfirmPassword,
                  ),

                  const SizedBox(height: 20),

                  // مرحله 3: کد تایید
                  _buildStep(
                    3,
                    'کد تایید',
                    'یکی از کدهای پشتیبان زیر را وارد کنید',
                    Icons.verified_user,
                    Colors.orange,
                  ),

                  const SizedBox(height: 16),

                  // ورودی کد تایید
                  TextField(
                    controller: _verificationController,
                    decoration: InputDecoration(
                      labelText: 'کد تایید',
                      hintText: 'یکی از کدهای پشتیبان را وارد کنید',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.security),
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 24),

                  // دکمه فعال‌سازی
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyAndEnable,
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
                              'فعال‌سازی تایید دو مرحله‌ای',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // نمایش خطا
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
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

                  const SizedBox(height: 32),

                  // کدهای پشتیبان
                  if (_backupCodes != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.backup,
                                color: Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'کدهای پشتیبان',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'این کدها را در جای امنی نگهداری کنید. هر کد فقط یک بار قابل استفاده است.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // دکمه ذخیره تصویر
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _saveBackupCodesAsImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.save_alt),
                              label: Text(_isLoading
                                  ? 'در حال ذخیره...'
                                  : 'ذخیره به عنوان تصویر'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // نمایش وضعیت کدهای پشتیبان
                          if (_backupCodes != null) ...[
                            _buildBackupCodesStatus(_backupCodes!),
                            const SizedBox(height: 16),
                          ],

                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: _backupCodes!.length,
                              itemBuilder: (context, index) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _backupCodes![index],
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                              text: _backupCodes![index]),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('کد کپی شد')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // دکمه تولید کدهای جدید
                          if (_backupCodes != null &&
                              Simple2FAService.needsNewBackupCodes(
                                  _backupCodes!)) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isLoading ? null : _generateNewBackupCodes,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh),
                                label: Text(_isLoading
                                    ? 'در حال تولید...'
                                    : 'تولید کدهای جدید'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStep(int number, String title, String description, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: 24),
        ],
      ),
    );
  }

  /// نمایش وضعیت کدهای پشتیبان
  Widget _buildBackupCodesStatus(List<String> backupCodes) {
    final status = Simple2FAService.checkBackupCodesStatus(backupCodes);
    final remainingCount = status['remaining_count'] as int;
    final warningLevel = status['warning_level'] as String;
    final recommendation = status['recommendation'] as String;
    final percentage = status['percentage'] as double;
    final isCritical = status['is_critical'] as bool;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (warningLevel) {
      case 'critical':
        statusColor = Colors.red;
        statusIcon = Icons.dangerous;
        statusText = 'حساب قفل شده!';
        break;
      case 'high':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        statusText = 'کدهای پشتیبان در حال اتمام!';
        break;
      case 'medium':
        statusColor = Colors.orange;
        statusIcon = Icons.info;
        statusText = 'کدهای پشتیبان کم';
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'کدهای پشتیبان کافی';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$remainingCount کد باقی مانده (${percentage.toInt()}%)',
                      style: TextStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    isCritical ? Icons.error : Icons.lightbulb,
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// تولید کدهای پشتیبان جدید
  Future<void> _generateNewBackupCodes() async {
    if (_backupCodes == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // تولید کدهای جدید و اضافه کردن به لیست موجود
      final newCodes =
          Simple2FAService.generateAdditionalBackupCodes(_backupCodes!);

      setState(() {
        _backupCodes = newCodes;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کدهای پشتیبان جدید تولید شدند'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ خطا در تولید کدهای جدید: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تولید کدهای جدید: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
