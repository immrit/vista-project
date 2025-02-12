import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/util/widgets.dart';
import '/view/screen/ouathUser/SetProfile.dart';
import '../../../main.dart';
import '../../../provider/provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool redirecting = false;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // تابع برای پردازش پیام‌های خطا
  String getErrorMessage(String message) {
    if (message.contains('email already registered')) {
      return 'این ایمیل قبلاً ثبت شده است. لطفاً از ایمیل دیگری استفاده کنید.';
    } else if (message.contains('weak password')) {
      return 'رمز عبور انتخابی ضعیف است. لطفاً رمز عبور قوی‌تری وارد کنید.';
    } else if (message.contains('invalid email')) {
      return 'فرمت ایمیل وارد شده معتبر نیست. لطفاً ایمیل صحیح وارد کنید.';
    } else if (message.contains('network')) {
      return 'مشکلی در ارتباط با شبکه وجود دارد. لطفاً اتصال اینترنت خود را بررسی کنید.';
    } else if (message.contains('Password should be at least 6 characters')) {
      return 'رمز عبور باید حداقل ۶ کاراکتر باشد.';
    }
    return 'خطای نامشخصی رخ داده است. لطفاً دوباره تلاش کنید.';
  }

  // گوش دادن به وضعیت تغییرات احراز هویت
  void authStateListener(AuthState data) {
    if (redirecting) return;
    final session = data.session;
    if (session != null) {
      redirecting = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SetProfileData()),
      );
    }
  }

  // متد برای ثبت نام
  Future<void> signUp() async {
    ref.read(isLoadingProvider.notifier).state = true;
    try {
      await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );
      context.showSnackBar('حساب کاربری شما با موفقیت ایجاد شد :)');
      emailController.clear();
      passController.clear();
      confirmPasswordController.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SetProfileData()),
      );
    } on AuthException catch (error) {
      String errorMessage = getErrorMessage(error.message);
      context.showSnackBar(errorMessage, isError: true);
    } catch (error) {
      print('Error: $error');
      context.showSnackBar('خطای غیرمنتظره‌ای رخ داده است.', isError: true);
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = ref.watch(isLoadingProvider);
    supabase.auth.onAuthStateChange.listen(authStateListener);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        children: [
          topText(text: 'به ویستا خوش اومدی'),
          const SizedBox(height: 80),
          customTextField(
            'ایمیل',
            emailController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا مقادیر را وارد نمایید';
              }
            },
            false,
            TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          customTextField(
            'رمزعبور',
            passController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا مقادیر را وارد نمایید';
              }
            },
            true,
            TextInputType.visiblePassword,
          ),
          const SizedBox(height: 10),
          customTextField(
            'تایید رمزعبور',
            confirmPasswordController,
            (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا تایید رمزعبور را وارد نمایید';
              }
              if (value != passController.text) {
                return 'عدم تطابق رمزعبور';
              }
              return null;
            },
            true,
            TextInputType.visiblePassword,
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => showPrivicyDialog(context),
              child: const Text(
                "سیاست حفظ حریم خصوصی",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            right: 10,
            left: 10),
        child: customButton(isLoading ? null : signUp,
            isLoading ? '...در حال ورود' : 'ثبت نام', ref),
      ),
    );
  }
}

// تابع برای نمایش دیالوگ سیاست حفظ حریم خصوصی
void showPrivicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.grey[700],
        title: const Directionality(
          textDirection: TextDirection.rtl,
          child: Text('سیاست نامه حفظ حریم خصوصی ویستا'),
        ),
        content: const Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
              'به ویستا خوش اومدید... \n اینجا میتونید همه یادداشت هاتون رو ذخیره کنید و همیشه و توی همه دستگاهاتون بهشون دسترسی داشته باشید\n ضمن اینکه این سرویس بصورت سینک شده در اختیار کاربر قرار میگیرد ملزم به ثبت نام از طریق ایمیل میباشد \n ویستا امنیت داده های شمارا همواره تضمین میکند و ما دائما در حال تلاش برای بهبود زیرساخت و امنیت ویستا هستیم \n ما امکان در اختیار گذاشتن داده های هیچ یک از کاربران را نداریم و داده ها بصورت ایمن در سرورهای ما محفوظ خواهد ماند  \n از حضور شما بسیار خرسندیم :)'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'تایید',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}
