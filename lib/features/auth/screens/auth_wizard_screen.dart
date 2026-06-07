import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../provider/provider.dart';
import '../../../core/security/input_policy.dart';
import '../../../utils/directional_navigation.dart';
import '../data/auth_repository.dart';
import '../providers/auth_controller.dart';
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

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;

  // Logic State
  bool _isPhoneInput = false;
  bool _isRegistering = false;

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
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    timer?.cancel();
    super.dispose();
  }

  // --- Logic Helpers ---

  String _sanitizeInput(String input) {
    return normalizeDigits(input).trim();
  }

  bool _isDisabledAccount(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'banned' || normalized == 'suspended';
  }

  bool _isPasswordAccountError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('auth_has_password') ||
        text.contains('password') ||
        text.contains('رمز عبور');
  }

  // --- Navigation & State Machine ---

  void _nextPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubicEmphasized,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (page == 1) {
        _passwordFocusNode.requestFocus();
      } else if (page == 2) {
        _otpFocusNode.requestFocus();
      }
    });
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
      final lookup = await AuthRepository().lookupIdentifier(
        _isPhoneInput ? normalizedPhone! : input,
      );

      setState(() {
        _isLoading = false;
      });

      if (_isDisabledAccount(lookup.accountStatus)) {
        _showSnack('حساب کاربری شما غیرفعال شده است');
        return;
      }

      if (_isPhoneInput) {
        _inputController.text =
            lookup.normalizedIdentifier?.trim().isNotEmpty == true
                ? lookup.normalizedIdentifier!
                : normalizedPhone!;
        if (lookup.exists && lookup.authFlow == 'password') {
          setState(() => _isRegistering = false);
          _nextPage(1);
        } else if (lookup.exists) {
          setState(() => _isRegistering = false);
          _sendOtp(isResend: false);
        } else {
          setState(() => _isRegistering = true);
          _nextPage(1);
        }
      } else {
        if (lookup.exists) {
          setState(() => _isRegistering = false);
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

    if (_isRegistering) {
      _sendOtp(isResend: false);
      return;
    }

    try {
      final authState = ref.read(authControllerProvider);
      bool success = false;

      if (authState.is2faRequired) {
        success = await ref
            .read(authControllerProvider.notifier)
            .verify2fa(password: password);
      } else {
        final input = _sanitizeInput(_inputController.text);
        final identifier = _isPhoneInput
            ? normalizePhone09(input) ?? input
            : input.toLowerCase();
        success = await ref.read(authControllerProvider.notifier).login(
              identifier: identifier,
              password: password,
            );
      }

      if (!success) {
        final error = ref.read(authControllerProvider).error;
        throw error ?? 'ورود ناموفق بود';
      }

      setState(() => _isLoading = false);

      final currentAuthState = ref.read(authControllerProvider);
      final currentUser = currentAuthState.currentUser;
      final phoneNumberIsSet = currentUser?.phoneNumber != null &&
          currentUser!.phoneNumber!.isNotEmpty;

      if (phoneNumberIsSet) {
        if (!mounted) return;
        _showSnack('ورود موفقیت آمیز بود');
        if (currentUser.profileCompleted == false) {
          Navigator.pushReplacementNamed(context, '/profile-setup');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
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
          msg.contains('invalid_credentials') ||
          msg.contains('AUTH_INVALID_CREDENTIALS')) {
        msg = 'نام کاربری یا رمز عبور اشتباه است';
      } else if (msg.contains('AUTH_ACCOUNT_DISABLED')) {
        msg = 'حساب کاربری شما غیرفعال شده است';
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

      if (!mounted) return;
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
        if (_isPasswordAccountError(error)) {
          setState(() => _isRegistering = false);
          _passwordController.clear();
          _nextPage(1);
          return;
        }
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
        if (!mounted) return;

        final authState = ref.read(authControllerProvider);
        if (authState.is2faRequired) {
          _passwordController.clear();
          setState(() => _isLoading = false);
          _showSnack('حساب شما مجهز به تایید دو مرحله‌ای است');
          _nextPage(1); // Jump to password slide
          return;
        }

        if (_isRegistering) {
          final password = _passwordController.text;
          if (password.isNotEmpty) {
            try {
              await ref.read(authControllerProvider.notifier).register(
                    phoneNumber: phone,
                    password: password,
                    fullName: '',
                  );
            } catch (e) {
              debugPrint('Error setting password during registration: $e');
            }
          }
          if (!mounted) return;
          _showSnack('خوش آمدید!');
          final finalAuthState = ref.read(authControllerProvider);
          if (finalAuthState.isNewUser ||
              finalAuthState.currentUser?.profileCompleted == false) {
            Navigator.pushReplacementNamed(context, '/profile-setup');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // User successfully logged in via OTP.
          // They DO NOT have a password. Force them to set one.
          Navigator.pushReplacementNamed(context, '/mandatory-password');
        }
      } else {
        setState(() {
          _isLoading = false;
          _otpError = 'کد وارد شده اشتباه است';
        });
      }
    } catch (e) {
      if (!mounted) return;
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
            alignment: isLocaleRtl(context)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: IconButton(
              icon: Icon(directionalBackIcon(context)),
              onPressed: () => _pageController.jumpToPage(0),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _isRegistering ? "انتخاب رمز عبور" : "رمز عبور خود را وارد کنید",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (_isRegistering) ...[
            const SizedBox(height: 8),
            Text(
              "رمز عبوری شامل حداقل ۸ کاراکتر ترکیبی از حروف و اعداد انتخاب کنید.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
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
                : Text(_isRegistering ? "تایید و دریافت کد پیامکی" : "ورود"),
          ),
          const SizedBox(height: 8),
          if (!_isRegistering)
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
            alignment: isLocaleRtl(context)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: IconButton(
              icon: Icon(directionalBackIcon(context)),
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
                focusNode: _otpFocusNode,
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
          // Dev OTP display is completely hidden per user request.
          // if (debugCode != null && debugCode.isNotEmpty) ...[
          //   const SizedBox(height: 12),
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          //     decoration: BoxDecoration(
          //       color: theme.colorScheme.primary.withValues(alpha: 0.08),
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(
          //         color: theme.colorScheme.primary.withValues(alpha: 0.2),
          //       ),
          //     ),
          //     child: Text(
          //       'Dev OTP: $debugCode',
          //       textAlign: TextAlign.center,
          //       style: theme.textTheme.bodyMedium?.copyWith(
          //         color: theme.colorScheme.primary,
          //         fontWeight: FontWeight.w600,
          //       ),
          //     ),
          //   ),
          // ],
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
