import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../security/simple_2fa_service.dart';
import '../../../provider/theme_provider.dart';

class TwoFactorSetupScreen extends ConsumerStatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  ConsumerState<TwoFactorSetupScreen> createState() =>
      _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends ConsumerState<TwoFactorSetupScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  bool _is2FAEnabled = false;
  bool _isLoading = false;
  bool _showBackupCodes = false;
  List<String> _backupCodes = [];
  String _errorMessage = '';
  String _successMessage = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _check2FAStatus();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// بررسی وضعیت 2FA
  Future<void> _check2FAStatus() async {
    try {
      developer.log('Checking 2FA status...', name: 'TwoFactorSetup');

      // دریافت userId واقعی از Supabase
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        developer.log('No authenticated user found', name: 'TwoFactorSetup');
        setState(() {
          _errorMessage = 'کاربر احراز هویت نشده است';
        });
        return;
      }

      final userId = user.id;
      developer.log('Checking 2FA for user: $userId', name: 'TwoFactorSetup');

      // استفاده از روش refresh برای اطمینان از همگام‌سازی با دیتابیس
      final isEnabled = await Simple2FAService.refresh2FAStatus(userId);
      developer.log('2FA status after refresh: $isEnabled',
          name: 'TwoFactorSetup');

      setState(() {
        _is2FAEnabled = isEnabled;
        _errorMessage = ''; // پاک کردن خطاهای قبلی
      });
    } catch (e) {
      developer.log('Error checking 2FA status: $e', name: 'TwoFactorSetup');
      setState(() {
        _errorMessage = 'خطا در بررسی وضعیت 2FA: $e';
        _is2FAEnabled = false; // در صورت خطا، false در نظر بگیر
      });
    }
  }

  /// تولید کد پیشنهادی
  void _generateSuggestedCode() {
    try {
      final suggestedCode = Simple2FAService.getSuggestedCode();
      developer.log('Generated suggested code: $suggestedCode',
          name: 'TwoFactorSetup');

      setState(() {
        _codeController.text = suggestedCode;
        _errorMessage = '';
      });

      // Focus on the code field
      _codeFocusNode.requestFocus();

      // Show success message
      _showSuccessMessage('کد پیشنهادی تولید شد');
    } catch (e) {
      developer.log('Error generating suggested code: $e',
          name: 'TwoFactorSetup');
      setState(() {
        _errorMessage = 'خطا در تولید کد پیشنهادی: $e';
      });
    }
  }

  /// فعال‌سازی 2FA
  Future<void> _generate2FASetup() async {
    final code = _codeController.text.trim();

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

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'کد باید فقط شامل اعداد باشد';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      developer.log('Enabling 2FA with code: $code', name: 'TwoFactorSetup');

      // دریافت userId واقعی از Supabase
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        developer.log('No authenticated user found', name: 'TwoFactorSetup');
        setState(() {
          _errorMessage = 'کاربر احراز هویت نشده است';
        });
        return;
      }

      final userId = user.id;
      developer.log('Enabling 2FA for user: $userId', name: 'TwoFactorSetup');

      final result = await Simple2FAService.enable2FA(userId, code);
      developer.log('2FA enabled successfully. Result: $result',
          name: 'TwoFactorSetup');

      if (result['success'] == true) {
        final backupCodes = result['backupCodes'] as List<String>;

        // پاک کردن اطلاعات تایید نشست قبلی (اگر وجود داشته باشد)
        await Simple2FAService.clearSessionVerification();

        setState(() {
          _is2FAEnabled = true;
          _backupCodes = backupCodes;
          _showBackupCodes = true;
          _successMessage = 'احراز هویت دو مرحله‌ای با موفقیت فعال شد!';
        });

        // Show backup codes with animation
        _showBackupCodesWithAnimation();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'خطا در فعال‌سازی 2FA';
        });
      }
    } catch (e) {
      developer.log('Error enabling 2FA: $e', name: 'TwoFactorSetup');
      setState(() {
        _errorMessage = 'خطا در فعال‌سازی 2FA: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// نمایش کدهای بکاپ با انیمیشن
  void _showBackupCodesWithAnimation() {
    _scaleController.reset();
    _scaleController.forward();
  }

  /// نمایش پیام موفقیت
  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
    });

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _successMessage = '';
        });
      }
    });
  }

  /// تولید تصویر کدهای بکاپ
  Future<Uint8List> _generateBackupCodesImage(String codesText) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 400);

    // Background
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), borderPaint);

    // Title
    final titleStyle = TextStyle(
      color: Colors.blue.shade800,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    final titleSpan = TextSpan(text: 'کدهای بکاپ 2FA', style: titleStyle);
    final titlePainter = TextPainter(
      text: titleSpan,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    titlePainter.layout();
    titlePainter.paint(
        canvas,
        Offset(
          (size.width - titlePainter.width) / 2,
          20,
        ));

    // Codes
    final codes = codesText.split(',');
    final codeStyle = TextStyle(
      color: Colors.black87,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
    );

    double yOffset = 80;
    for (int i = 0; i < codes.length; i++) {
      final code = codes[i].trim();
      final codeSpan = TextSpan(text: code, style: codeStyle);
      final codePainter = TextPainter(
        text: codeSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      codePainter.layout();

      final xOffset = (size.width - codePainter.width) / 2;
      codePainter.paint(canvas, Offset(xOffset, yOffset));

      yOffset += 30;
    }

    // Warning text
    final warningStyle = TextStyle(
      color: Colors.red.shade600,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final warningSpan = TextSpan(
      text: 'این کدها را در جای امنی نگهداری کنید',
      style: warningStyle,
    );
    final warningPainter = TextPainter(
      text: warningSpan,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    warningPainter.layout();
    warningPainter.paint(
        canvas,
        Offset(
          (size.width - warningPainter.width) / 2,
          yOffset + 20,
        ));

    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 400);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// ذخیره کدهای بکاپ در گالری
  Future<void> _saveBackupCodesToGallery() async {
    try {
      final codesText = _backupCodes.join(',');
      final imageBytes = await _generateBackupCodesImage(codesText);

      await Gal.putImageBytes(imageBytes, name: 'backup_codes_2fa');

      _showSuccessMessage('کدهای بکاپ در گالری ذخیره شد');
    } catch (e) {
      developer.log('Error saving backup codes to gallery: $e',
          name: 'TwoFactorSetup');
      setState(() {
        _errorMessage = 'خطا در ذخیره کدهای بکاپ: $e';
      });
    }
  }

  /// غیرفعال‌سازی 2FA
  Future<void> _disable2FA() async {
    // نمایش dialog تایید
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تایید غیرفعال‌سازی',
          style: TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید احراز هویت دو مرحله‌ای را غیرفعال کنید؟ این کار امنیت حساب شما را کاهش می‌دهد.',
          style: TextStyle(fontFamily: 'Vazir'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'انصراف',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'غیرفعال کن',
              style:
                  TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'کاربر احراز هویت نشده است';
        });
        return;
      }

      final result = await Simple2FAService.disable2FA(user.id);

      if (result['success'] == true) {
        // پاک کردن اطلاعات تایید نشست
        await Simple2FAService.clearSessionVerification();

        setState(() {
          _is2FAEnabled = false;
          _showBackupCodes = false;
          _backupCodes = [];
          _successMessage = 'احراز هویت دو مرحله‌ای با موفقیت غیرفعال شد';
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'خطا در غیرفعال‌سازی 2FA';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در غیرفعال‌سازی 2FA: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// بروزرسانی کدهای بکاپ
  Future<void> _regenerateBackupCodes() async {
    // نمایش dialog تایید
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تایید بروزرسانی کدهای بکاپ',
          style: TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید کدهای بکاپ جدید تولید کنید؟ کدهای قبلی دیگر قابل استفاده نخواهند بود.',
          style: TextStyle(fontFamily: 'Vazir'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'انصراف',
              style: TextStyle(fontFamily: 'Vazir'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'تولید کدهای جدید',
              style:
                  TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'کاربر احراز هویت نشده است';
        });
        return;
      }

      final newCodes = await Simple2FAService.regenerateBackupCodes(user.id);

      setState(() {
        _backupCodes = (newCodes['codes'] as List<dynamic>).cast<String>();
        _showBackupCodes = true;
        _successMessage = 'کدهای بکاپ جدید با موفقیت تولید شدند';
      });

      // پاک کردن اطلاعات تایید نشست قبلی (برای امنیت بیشتر)
      await Simple2FAService.clearSessionVerification();

      _showBackupCodesWithAnimation();
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در تولید کدهای بکاپ جدید: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDisableSection() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'احراز هویت دو مرحله‌ای فعال است',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontFamily: 'Vazir',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'حساب شما با احراز هویت دو مرحله‌ای محافظت می‌شود.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontFamily: 'Vazir',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _regenerateBackupCodes,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'بروزرسانی کدهای بکاپ',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Vazir',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _disable2FA,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.security, color: Colors.white),
                    label: const Text(
                      'غیرفعال کردن',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Vazir',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          'تنظیم احراز هویت دو مرحله‌ای',
          style: TextStyle(
            fontFamily: 'Vazir',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: isDark ? Colors.white : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                _buildHeaderSection(),
                const SizedBox(height: 32),

                // 2FA Status Section
                if (!_is2FAEnabled) _buildSetupSection(),
                if (_is2FAEnabled) _buildDisableSection(),

                // Backup Codes Section
                if (_showBackupCodes) _buildBackupCodesSection(),

                // Error Messages
                if (_errorMessage.isNotEmpty) _buildErrorMessage(),

                // Success Messages
                if (_successMessage.isNotEmpty) _buildSuccessMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.2)]
              : [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              // دکمه refresh
              IconButton(
                onPressed: _isLoading ? null : _check2FAStatus,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        color: primaryColor,
                        size: 28,
                      ),
                tooltip: 'بروزرسانی وضعیت',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'احراز هویت دو مرحله‌ای',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? theme.textTheme.headlineMedium?.color : primaryColor,
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _is2FAEnabled
                ? 'احراز هویت دو مرحله‌ای فعال است'
                : 'برای امنیت بیشتر، احراز هویت دو مرحله‌ای را فعال کنید',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? theme.textTheme.bodyMedium?.color
                  : primaryColor.withOpacity(0.8),
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'کد 6 رقمی خود را تعیین کنید',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? theme.textTheme.headlineSmall?.color
                    : Colors.grey.shade800,
                fontFamily: 'Vazir',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Code Input Field
            TextField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              decoration: InputDecoration(
                labelText: 'کد 6 رقمی',
                hintText: '123456',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: isDark ? theme.cardColor : Colors.grey.shade50,
                prefixIcon: Icon(
                  Icons.security,
                  color: primaryColor,
                ),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Vazir',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _generate2FASetup(),
            ),
            const SizedBox(height: 16),

            // Generate Suggested Code Button
            OutlinedButton.icon(
              onPressed: _generateSuggestedCode,
              icon: Icon(Icons.auto_fix_high, color: Colors.blue.shade600),
              label: Text(
                'تولید کد پیشنهادی',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontFamily: 'Vazir',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                side: BorderSide(color: Colors.blue.shade300),
              ),
            ),
            const SizedBox(height: 24),

            // Enable 2FA Button
            ElevatedButton(
              onPressed: _isLoading ? null : _generate2FASetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 3,
                shadowColor: Colors.blue.withOpacity(0.3),
              ),
              child: _isLoading
                  ? Row(
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
                        const SizedBox(width: 12),
                        const Text(
                          'در حال فعال‌سازی...',
                          style: TextStyle(
                            fontFamily: 'Vazir',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'فعال‌سازی 2FA',
                          style: TextStyle(
                            fontFamily: 'Vazir',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCodesSection() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'کدهای بکاپ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontFamily: 'Vazir',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'این کدها را در جای امنی نگهداری کنید. هر کد فقط یکبار قابل استفاده است.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontFamily: 'Vazir',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Backup Codes Grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _backupCodes.length; i += 2) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildBackupCodeCard(_backupCodes[i]),
                        ),
                        if (i + 1 < _backupCodes.length) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBackupCodeCard(_backupCodes[i + 1]),
                          ),
                        ],
                      ],
                    ),
                    if (i + 2 < _backupCodes.length) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveBackupCodesToGallery,
                    icon: Icon(Icons.save, color: Colors.green.shade600),
                    label: Text(
                      'ذخیره در گالری',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontFamily: 'Vazir',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showBackupCodes = false;
                      });
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'تایید',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Vazir',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCodeCard(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          letterSpacing: 2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red.shade700,
                fontFamily: 'Vazir',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage,
              style: TextStyle(
                color: Colors.green.shade700,
                fontFamily: 'Vazir',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
