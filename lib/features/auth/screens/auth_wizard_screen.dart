import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../provider/provider.dart';
import '../../../core/security/input_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ribbon_background.dart';
import '../widgets/blend_mask.dart';

class AuthWizardScreen extends ConsumerStatefulWidget {
  const AuthWizardScreen({super.key});

  @override
  ConsumerState<AuthWizardScreen> createState() => _AuthWizardScreenState();
}

class _AuthWizardScreenState extends ConsumerState<AuthWizardScreen> {
  final PageController _pageController = PageController();

  // Controllers
  final TextEditingController _inputController =
      TextEditingController(); // Phone or Email/Username
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;

  // Logic State
  bool _isPhoneInput = false;

  // OTP State
  int countdown = 60;
  Timer? timer;
  String? _otpError;

  @override
  void dispose() {
    _pageController.dispose();
    _inputController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    timer?.cancel();
    super.dispose();
  }

  // --- Logic Helpers ---

  String _sanitizeInput(String input) {
    return normalizeDigits(input).trim();
  }

  // Check if user exists in DB (Real Supabase Call)
  Future<bool> _checkUserExists(String input) async {
    try {
      if (input.isEmpty) return false;
      final client = Supabase.instance.client;

      final normalizedPhone = normalizePhone09(input);
      if (normalizedPhone != null) {
        final byPhone = await client
            .from('profiles')
            .select('id')
            .eq('phone_number', normalizedPhone)
            .maybeSingle();
        return byPhone != null;
      }

      if (input.contains('@')) {
        final byEmail = await client
            .from('profiles')
            .select('id')
            .eq('email', input.toLowerCase())
            .maybeSingle();
        return byEmail != null;
      }

      final byUsername = await client
          .from('profiles')
          .select('id')
          .eq('username', input.toLowerCase())
          .maybeSingle();
      return byUsername != null;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }
  // --- Navigation & State Machine ---

  void _nextPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  Future<void> _handleInputSubmit() async {
    final rawInput = _inputController.text;
    final input = _sanitizeInput(rawInput);

    if (input.isEmpty) {
      _showSnack('لطفاً ورودی را کامل کنید');
      return;
    }

    setState(() => _isLoading = true);

    final normalizedPhone = normalizePhone09(input);
    _isPhoneInput = normalizedPhone != null;

    try {
      final userExists =
          await _checkUserExists(_isPhoneInput ? normalizedPhone! : input);

      setState(() {
        _isLoading = false;
      });

      if (_isPhoneInput) {
        if (userExists) {
          _inputController.text = normalizedPhone!;
          _nextPage(1);
        } else {
          _inputController.text = normalizedPhone!;
          _sendOtp(isResend: false);
        }
      } else {
        if (userExists) {
          _nextPage(1);
        } else {
          _showSnack('برای ثبت نام جدید لطفاً از شماره موبایل استفاده کنید');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('خطا در بررسی اطلاعات: $e');
    }
  }

  Future<void> _handlePasswordLogin() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      _showSnack('لطفاً رمز عبور را وارد کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final input = _sanitizeInput(_inputController.text);
      String? loginPhone;
      String? loginEmail;
      final client = Supabase.instance.client;

      if (_isPhoneInput) {
        final normalizedPhone = normalizePhone09(input);
        if (normalizedPhone == null) {
          throw 'شماره موبایل نامعتبر است';
        }

        final data = await client
            .from('profiles')
            .select('email, account_status')
            .eq('phone_number', normalizedPhone)
            .maybeSingle();

        if (data != null) {
          if (data['account_status'] == 'banned' ||
              data['account_status'] == 'suspended') {
            throw 'حساب کاربری شما غیرفعال شده است';
          }
          if (data['email'] != null) {
            loginEmail = data['email'];
          } else {
            loginPhone = normalizedPhone;
          }
        } else {
          loginPhone = normalizedPhone;
        }
      } else {
        if (input.contains('@')) {
          loginEmail = input.toLowerCase();
        } else {
          final data = await client
              .from('profiles')
              .select('email, account_status')
              .eq('username', input.toLowerCase())
              .maybeSingle();

          if (data != null) {
            if (data['account_status'] == 'banned' ||
                data['account_status'] == 'suspended') {
              throw 'حساب کاربری شما غیرفعال شده است';
            }
            if (data['email'] != null) {
              loginEmail = data['email'];
            } else {
              throw 'ایمیل متصل به این نام کاربری یافت نشد';
            }
          } else {
            throw 'نام کاربری یافت نشد';
          }
        }
      }

      final emailForAuth = (loginEmail != null && loginEmail.trim().isNotEmpty)
          ? loginEmail
          : null;
      final phoneForAuth = (loginPhone != null && loginPhone.trim().isNotEmpty)
          ? loginPhone
          : null;

      if (emailForAuth == null && phoneForAuth == null) {
        throw 'شناسه ورود معتبر یافت نشد';
      }

      final response = await client.auth.signInWithPassword(
        email: emailForAuth,
        phone: phoneForAuth,
        password: password,
      );
      if (response.user == null) throw 'ورود ناموفق بود';

      setState(() => _isLoading = false);

      final user = response.user!;
      bool phoneNumberIsSet = user.phone != null && user.phone!.isNotEmpty;
      if (!phoneNumberIsSet) {
        final profile = await client
            .from('profiles')
            .select('phone_number')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['phone_number'] != null) {
          phoneNumberIsSet = true;
        }
      }

      if (phoneNumberIsSet) {
        _showSnack('ورود موفقیت آمیز بود');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnack('لطفاً شماره موبایل خود را تایید کنید');
        _inputController.clear();
        _pageController.jumpToPage(0);
        _showSnack('برای تکمیل حساب کاربری، شماره موبایل خود را وارد کنید');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String msg = e.toString();
      if (msg.contains('Invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        msg = 'نام کاربری یا رمز عبور اشتباه است';
      } else if (msg.contains('Email not confirmed')) {
        msg = 'ایمیل شما تایید نشده است';
      }
      _showSnack('خطا در ورود: $msg');
    }
  }

  // --- OTP Logic ---

  void _startTimer() {
    countdown = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          if (countdown > 0) {
            countdown--;
          } else {
            t.cancel();
          }
        });
      }
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = normalizePhone09(_sanitizeInput(_inputController.text));
    if (phone == null) {
      _showSnack('شماره موبایل نامعتبر است');
      return;
    }
    _inputController.text = phone;

    if (!isResend) {
      setState(() => _isLoading = true);
    }

    try {
      final success =
          await ref.read(authControllerProvider.notifier).sendOtp(phone);

      setState(() => _isLoading = false);

      if (success) {
        _otpController.clear();
        _startTimer();
        if (!isResend) {
          _nextPage(2);
        } else {
          _showSnack('کد تایید مجدداً ارسال شد');
        }
      } else {
        final error =
            ref.read(authControllerProvider).error ?? 'خطا در ارسال کد';
        _showSnack(error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('خطا: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _sanitizeInput(_otpController.text);
    final phone = normalizePhone09(_sanitizeInput(_inputController.text));
    if (phone == null) {
      _showSnack('شماره موبایل نامعتبر است');
      return;
    }

    if (otp.length < 4) return;

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      final success = await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: phone, token: otp);

      if (success) {
        timer?.cancel();
        _showSnack('خوش آمدید!');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _isLoading = false;
          _otpError = 'کد وارد شده اشتباه است';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _otpError = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // 1. Background (Fixed)
              const Positioned.fill(child: RibbonBackground()),

              // 2. Content (Scrollable/PageView)
              SafeArea(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildInputSlide(), // Slide 0
                    _buildPasswordSlide(), // Slide 1
                    _buildOtpSlide(), // Slide 2
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableSlide({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildInputSlide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoPath = isDark
        ? 'lib/utils/images/logo/logo-white.png'
        : 'lib/utils/images/logo/black-logo.png';

    return _buildScrollableSlide(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Connect Logo with Blend Mask to remove background
          BlendMask(
            blendMode: isDark ? BlendMode.screen : BlendMode.multiply,
            child: Image.asset(
              logoPath,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 48),

          Text(
            "ورود به ویستا",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Enhance TextField with container/shadow if needed, or keep clean
          TextField(
            controller: _inputController,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) {
                _handleInputSubmit();
              }
            },
            decoration: const InputDecoration(
              hintText: "شماره موبایل، ایمیل یا نام کاربری",
              hintTextDirection: TextDirection.rtl,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleInputSubmit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("ادامه"),
          ),
          const SizedBox(height: 20),
          // Footer / Terms
          Text(
            "با ورود به ویستا، قوانین و مقررات را می‌پذیرم.",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPasswordSlide() {
    return _buildScrollableSlide(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _pageController.jumpToPage(0),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "رمز عبور خود را وارد کنید",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) {
                _handlePasswordLogin();
              }
            },
            decoration: const InputDecoration(
              hintText: "رمز عبور",
              hintTextDirection: TextDirection.rtl,
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("ورود"),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    final prefill = _sanitizeInput(_inputController.text);
                    Navigator.pushNamed(
                      context,
                      '/reset-password',
                      arguments: {
                        'prefill': prefill,
                        'method': _isPhoneInput ? 'sms' : 'email',
                      },
                    );
                  },
            child: const Text('فراموشی رمزعبور؟'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOtpSlide() {
    // Pinput theme based on Monochrome
    // Pinput theme based on Monochrome
    final theme = Theme.of(context);
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return _buildScrollableSlide(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                // Determine where to go back
                // Usually back to input slide (0)
                _pageController.jumpToPage(0);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "کد تایید",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "کد ارسال شده به شماره ${_inputController.text} را وارد کنید",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Pinput(
                length: 5,
                controller: _otpController,
                autofocus: true,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                  border:
                      Border.all(color: theme.colorScheme.primary, width: 1.5),
                ),
                onCompleted: (pin) => _verifyOtp(),
              ),
            ),
          ),
          if (_otpError != null) ...[
            const SizedBox(height: 16),
            Text(_otpError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE53935))),
          ],
          const SizedBox(height: 32),
          if (countdown > 0)
            Text(
              'ارسال مجدد کد در $countdown ثانیه',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            )
          else
            TextButton(
              onPressed: () => _sendOtp(isResend: true),
              child: const Text("ارسال مجدد کد"),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("تایید"),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
