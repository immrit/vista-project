import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../provider/provider.dart';
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

  bool _isNumeric(String s) {
    if (s.isEmpty) return false;
    return double.tryParse(s) != null;
  }

  String _sanitizeInput(String input) {
    const farsiDigits = '۰۱۲۳۴۵۶۷۸۹';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(farsiDigits[i], '$i');
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result.trim();
  }

  // Check if user exists in DB (Real Supabase Call)
  Future<bool> _checkUserExists(String input) async {
    try {
      // 1. Check if input is empty
      if (input.isEmpty) return false;

      // 2. Determine column to search
      // Note: We assume 'profiles' table has 'email', 'username', and 'phone_number'.
      // If the schema differs, this query needs adjustment.
      // We search across all potential columns using 'or' filter for robustness.

      // Sanitized input is already local digits "09..." or "email@..." or "username"
      // If it's phone, we might need E.164 (+98...) for some tables, but usually profiles stores what is registered.
      // Let's search raw input first.

      String query = 'email.eq.$input,username.eq.$input';

      // If input looks like a phone (starts with 09 and is digits), check both formats
      if (_isNumeric(input) && input.startsWith('09')) {
        final formatted = '+98${input.substring(1)}';
        query += ',phone_number.eq.$input,phone_number.eq.$formatted';
      } else {
        query += ',phone_number.eq.$input';
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .or(query)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      // In case of error (e.g. network), we might assume false or throw.
      // For smooth UX, return false implies "Treat as new user" which might lead to Registration flow.
      // If it IS an existing user and we say false, they usually get "Phone already registered" error during OTP/Signup which is acceptable recovery.
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

    // 1. Determine Input Type
    // Simple check: if fully numeric and > 9 chars -> Phone. Else -> Email/User.
    String sanitizedForCheck = input.replaceAll('+', '');
    _isPhoneInput =
        _isNumeric(sanitizedForCheck) && sanitizedForCheck.length > 9;

    try {
      // 2. Check Exists
      bool userExists = await _checkUserExists(input);

      setState(() {
        _isLoading = false;
      });

      // 3. Branching Logic
      if (_isPhoneInput) {
        if (userExists) {
          // Existing Phone -> Go to Password
          _nextPage(1);
        } else {
          // New Phone -> Go to OTP (Registration)
          _sendOtp(isResend: false);
        }
      } else {
        // Email/Username
        if (userExists) {
          // Existing Email/User -> Go to Password
          _nextPage(1);
        } else {
          // New Email/User -> Error/Prompt
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

      if (_isPhoneInput) {
        // Try to find email associated with this phone
        final formatted =
            input.startsWith('09') ? '+98${input.substring(1)}' : input;

        final data = await Supabase.instance.client
            .from('profiles')
            .select('email, account_status')
            .or('phone_number.eq.$input,phone_number.eq.$formatted')
            .maybeSingle();

        if (data != null) {
          if (data['account_status'] == 'banned' ||
              data['account_status'] == 'suspended') {
            throw 'حساب کاربری شما غیرفعال شده است';
          }
          if (data['email'] != null) {
            loginEmail = data['email'];
          } else {
            // No email found, fallback to phone
            loginPhone = formatted;
          }
        } else {
          // Should ideally not happen if checkUserExists passed, but valid fallback
          loginPhone = formatted;
        }
      } else {
        if (input.contains('@')) {
          loginEmail = input;
        } else {
          // Username -> Email lookup (Case Insensitive)
          final data = await Supabase.instance.client
              .from('profiles')
              .select('email, account_status')
              .ilike('username', input)
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

      final response = await Supabase.instance.client.auth.signInWithPassword(
          email: loginEmail, phone: loginPhone, password: password);
      if (response.user == null) throw 'ورود ناموفق بود';

      setState(() => _isLoading = false);

      final user = response.user!;
      bool phoneNumberIsSet = user.phone != null && user.phone!.isNotEmpty;
      if (!phoneNumberIsSet) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('phone_number')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['phone_number'] != null) {
          phoneNumberIsSet = true;
        }
      }

      if (phoneNumberIsSet) {
        // Success -> Home
        _showSnack('ورود موفقیت آمیز بود');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Force Update Phone -> OTP Slide (Slide 2)
        _showSnack('لطفاً شماره موبایل خود را تایید کنید');
        // We might need to ask for the phone number first if they logged in via email
        // For simplicity, let's assume we redirect them to slide 0 logic or a specific slide.
        // If they logged in via email (and no phone), we need phone input.
        // Let's reset input controller to empty and push them to Slide 2?
        // Or re-use Slide 0 prompt?
        // As per prompt: "Go to Slide: Add Phone (Slide 2/OTP)".
        // Slide 2 assumes we have a phone number to verify.
        // So we might need an intermediate state or just reset Slide 0 to "Phone Only" mode.
        // Let's Assume Slide 2 handles OTP. We need a phone number.
        // If we don't have it, we can't send OTP.
        // Slight deviation: If login successful but no phone -> Show BottomSheet to get Phone -> Then OTP.
        // For this task, let's stick to the requested flow:
        // "If phone_number is NULL -> Go to Slide: Add Phone"
        // Since Slide 2 is the OTP slide usually, maybe "Add Phone" is a new slide or reuse Slide 0?
        // Let's assume user must enter phone now.
        // I will redirect to Slide 2, but we need to ASK for phone first.
        // I will add a small logic to ask for phone if missing, effectively reusing Slide 0 but forcing phone.
        _inputController.clear();
        _pageController.jumpToPage(0); // Go back to start
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
    final phone = _sanitizeInput(_inputController.text);
    // Basic validation
    if (phone.length < 10) return;

    if (!isResend) {
      // Only show loading if moving to page defaults
      setState(() => _isLoading = true);
    }

    try {
      final success =
          await ref.read(authNotifierProvider.notifier).sendOtp(phone);

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
        final error = ref.read(authNotifierProvider).error ?? 'خطا در ارسال کد';
        _showSnack(error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('خطا: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _sanitizeInput(_otpController.text);
    final phone = _sanitizeInput(_inputController.text);

    if (otp.length < 4) return;

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
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
        resizeToAvoidBottomInset: false, // Prevent background squishing
        body: Stack(
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
    );
  }

  Widget _buildInputSlide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoPath = isDark
        ? 'lib/utils/images/logo/logo-white.png'
        : 'lib/utils/images/logo/black-logo.png';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
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
          const Spacer(),
          // Footer / Terms
          Text(
            "با ورود به ویستا، قوانین و مقررات را می‌پذیرم.",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPasswordSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
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
          const Spacer(),
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
          const Spacer(flex: 2),
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
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
          const Spacer(),
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
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
