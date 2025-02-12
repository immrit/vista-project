import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../homeScreen.dart';
import '/util/widgets.dart';

import '../../../provider/provider.dart';
import 'VerifyCodePage.dart';
import 'signupUser.dart';

class Loginuser extends ConsumerStatefulWidget {
  const Loginuser({super.key});

  @override
  _LoginuserState createState() => _LoginuserState();
}

class _LoginuserState extends ConsumerState<Loginuser> {
  final TextEditingController emailOrUsernameController =
      TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailOrUsernameController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    try {
      setState(() => _isLoading = true);

      final input = emailOrUsernameController.text.trim();
      final password = passController.text.trim();

      if (input.isEmpty || password.isEmpty) {
        showError('لطفا تمامی فیلدها را پر کنید');
        return;
      }

      String email;
      Map<String, dynamic> userProfile;

      // بررسی نوع ورود (ایمیل یا نام کاربری)
      if (input.contains('@')) {
        email = input;
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('email', email)
            .single();
      } else {
        userProfile = await supabase
            .from('profiles')
            .select('*')
            .eq('username', input)
            .single();
        email = userProfile['email'];
      }

      // لاگین کردن کاربر
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // آپدیت متادیتا بعد از لاگین موفق
      if (authResponse.user != null) {
        await updateUserMetadata(authResponse.user!, userProfile);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (e is PostgrestException) {
        showError('نام کاربری یا ایمیل یافت نشد');
      } else if (e is AuthException) {
        showError('نام کاربری یا رمز عبور اشتباه است');
      } else {
        showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showError(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ورود: $message')),
      );
    });
  }

  Future<void> updateUserMetadata(
      User user, Map<String, dynamic> profile) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'id': profile['id'],
            'username': profile['username'],
            'full_name': profile['full_name'],
            'avatar_url': profile['avatar_url'],
            'email': profile['email'],
            'updated_at': profile['updated_at'],
          },
        ),
      );
    } catch (e) {
      print('Error updating user metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بروزرسانی اطلاعات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(isLoadingProvider);
    final redirecting = ref.watch(isRedirectingProvider);
    Future<String> getIpAddress() async {
      try {
        final response =
            await http.get(Uri.parse('https://api.ipify.org?format=json'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['ip'];
        } else {
          throw Exception('Failed to fetch IP address');
        }
      } catch (error) {
        throw Exception('Failed to fetch IP address');
      }
    }

    Future<void> resetPassword() async {
      setState(() => _isLoading = true);

      try {
        final email = emailOrUsernameController.text.trim();
        if (email.isEmpty) {
          context.showSnackBar('لطفاً ایمیل خود را وارد کنید', isError: true);
          return;
        }

        await supabase.auth.resetPasswordForEmail(
          email,
          redirectTo: 'vista://auth/reset-password',
        );

        if (mounted) {
          // Navigate to verify code page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VerifyCodePage(
                email: email,
              ),
            ),
          );

          context.showSnackBar('کد بازیابی به ایمیل شما ارسال شد');
        }
      } catch (error) {
        print('Reset password error: $error');
        if (mounted) {
          context.showSnackBar('خطا در ارسال ایمیل', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (next.value != null && !redirecting) {
        ref.read(isRedirectingProvider.notifier).state = true;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    });

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Column(
              children: [
                topText(text: '!خوش برگشتی'),
                const SizedBox(height: 80),
                customTextField(
                    'نام کاربری یا ایمیل', emailOrUsernameController, (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفا مقادیر را وارد نمایید';
                  }
                  return null;
                }, false, TextInputType.emailAddress),
                const SizedBox(height: 10),
                customTextField('رمزعبور', passController, (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفا مقادیر را وارد نمایید';
                  }
                  return null;
                }, true, TextInputType.visiblePassword),
                TextButton(
                  onPressed: resetPassword,
                  child: const Text(
                    'فراموشی رمز عبور؟',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: const Text(
                          "ثبت نام کنید ",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      const Text("حساب کاربری ندارید؟"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              right: 10,
              left: 10),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
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
                      SizedBox(width: 10),
                      Text('درحال ورود...'),
                    ],
                  )
                : const Text('ورود'),
          ),
        ),
      ),
    );
  }

  bool isEmail(String input) {
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    return emailRegex.hasMatch(input);
  }
}
