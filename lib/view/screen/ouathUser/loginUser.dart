import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/util/widgets.dart';

import '../../../provider/provider.dart';
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

  @override
  void dispose() {
    emailOrUsernameController.dispose();
    passController.dispose();
    super.dispose();
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

    Future<void> signIn() async {
      ref.read(isLoadingProvider.notifier).state = true;
      try {
        String email;

        if (isEmail(emailOrUsernameController.text.trim())) {
          email = emailOrUsernameController.text.trim();
        } else {
          final response = await Supabase.instance.client
              .from('profiles')
              .select('email')
              .eq('username', emailOrUsernameController.text.trim())
              .maybeSingle();

          if (response == null) {
            context.showSnackBar('نام کاربری یا رمز عبور اشتباه است',
                isError: true);
            return;
          }

          email = response['email'] as String;
        }

        // Sign in with email and password
        final user = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: passController.text.trim(),
        );

        context.showSnackBar('خوش آمدید');
        emailOrUsernameController.clear();
        passController.clear();
        getIpAddress();
      } on AuthException {
        context.showSnackBar('نام کاربری یا رمز عبور اشتباه است',
            isError: true);
      } catch (error) {
        context.showSnackBar('خطایی پیش آمد', isError: true);
      } finally {
        ref.read(isLoadingProvider.notifier).state = false;
      }
    }

    Future<void> resetPassword() async {
      if (emailOrUsernameController.text.isEmpty) {
        context.showSnackBar('لطفاً ایمیل یا نام کاربری خود را وارد کنید',
            isError: true);
        return;
      }

      try {
        // Assuming the entered text is an email for password reset
        await Supabase.instance.client.auth
            .resetPasswordForEmail(emailOrUsernameController.text.trim());
        context.showSnackBar('ایمیل بازیابی رمز عبور ارسال شد');
      } catch (e) {
        context.showSnackBar('خطایی رخ داد، دوباره تلاش کنید', isError: true);
      }
    }

    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (next.value != null && !redirecting) {
        ref.read(isRedirectingProvider.notifier).state = true;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    });

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Column(
            children: [
              topText(text: '!خوش برگشتی'),
              const SizedBox(height: 80),
              customTextField('نام کاربری یا ایمیل', emailOrUsernameController,
                  (value) {
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
        child: customButton(isLoading ? null : signIn,
            isLoading ? '...در حال ورود' : 'ورود', ref),
      ),
    );
  }

  bool isEmail(String input) {
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    return emailRegex.hasMatch(input);
  }
}
