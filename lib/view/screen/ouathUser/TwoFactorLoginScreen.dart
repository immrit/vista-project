import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class TwoFactorLoginScreen extends ConsumerStatefulWidget {
  const TwoFactorLoginScreen({super.key});

  @override
  ConsumerState<TwoFactorLoginScreen> createState() =>
      _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends ConsumerState<TwoFactorLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _backupCodeController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  bool _useBackupCode = false;
  String _errorMessage = '';
  String _successMessage = '';

  // انیمیشن کنترلرها
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shakeController;

  // انیمیشن‌ها
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeController = AnimationController(
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
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    _passwordController.dispose();
    _backupCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyTwoFactor() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      if (_useBackupCode) {
        // استفاده از کد پشتیبان
        final backupCode = _backupCodeController.text.trim();
        if (backupCode.isEmpty) {
          setState(() {
            _errorMessage = 'لطفاً کد پشتیبان را وارد کنید';
          });
          _shakeError();
          return;
        }

        // اینجا باید کد پشتیبان را بررسی کنیم
        // فعلاً فقط یک پیام موفقیت نمایش می‌دهیم
        setState(() {
          _successMessage = 'ورود با کد پشتیبان موفقیت‌آمیز بود';
        });

        // انتقال به صفحه اصلی
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // استفاده از رمز 2FA
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          setState(() {
            _errorMessage = 'لطفاً رمز تایید دو مرحله‌ای را وارد کنید';
          });
          _shakeError();
          return;
        }

        // اینجا باید رمز 2FA را بررسی کنیم
        // فعلاً فقط یک پیام موفقیت نمایش می‌دهیم
        setState(() {
          _successMessage = 'ورود با رمز 2FA موفقیت‌آمیز بود';
        });

        // انتقال به صفحه اصلی
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در ورود: $e';
      });
      _shakeError();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shakeError() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  void _toggleBackupCode() {
    setState(() {
      _useBackupCode = !_useBackupCode;
      _errorMessage = '';
      _successMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تایید دو مرحله‌ای'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                const SizedBox(height: 40),

                // آیکون امنیت
                Center(
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeAnimation.value *
                              10 *
                              (_errorMessage.isNotEmpty ? 1 : 0),
                          0,
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security,
                            size: 50,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // عنوان
                Text(
                  'تایید دو مرحله‌ای',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  'برای ورود به حساب، رمز تایید دو مرحله‌ای یا کد پشتیبان را وارد کنید',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // دکمه‌های انتخاب روش
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: _useBackupCode ? null : _toggleBackupCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _useBackupCode
                                ? Colors.grey[300]
                                : theme.colorScheme.primary,
                            foregroundColor: _useBackupCode
                                ? Colors.grey[600]
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _useBackupCode ? 0 : 4,
                          ),
                          child: const Text('رمز 2FA'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: _useBackupCode ? _toggleBackupCode : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _useBackupCode
                                ? theme.colorScheme.primary
                                : Colors.grey[300],
                            foregroundColor: _useBackupCode
                                ? Colors.white
                                : Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _useBackupCode ? 4 : 0,
                          ),
                          child: const Text('کد پشتیبان'),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // فیلد ورودی
                if (!_useBackupCode) ...[
                  // فیلد رمز 2FA
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'رمز تایید دو مرحله‌ای',
                      hintText: 'رمز 2FA خود را وارد کنید',
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
                ] else ...[
                  // فیلد کد پشتیبان
                  TextField(
                    controller: _backupCodeController,
                    decoration: InputDecoration(
                      labelText: 'کد پشتیبان',
                      hintText: 'یکی از کدهای پشتیبان را وارد کنید',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.backup),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],

                const SizedBox(height: 24),

                // دکمه ورود
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyTwoFactor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
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
                            'ورود',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // نمایش خطا
                if (_errorMessage.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // نمایش موفقیت
                if (_successMessage.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // راهنما
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'راهنما',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _useBackupCode
                            ? 'کدهای پشتیبان را در جای امنی نگهداری کنید. هر کد فقط یک بار قابل استفاده است.'
                            : 'رمز تایید دو مرحله‌ای همان رمزی است که هنگام فعال‌سازی 2FA تنظیم کرده‌اید.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
