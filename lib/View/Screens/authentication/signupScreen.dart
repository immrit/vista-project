import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';

import '../../../Provider/appwriteProvider.dart';
import '../../utility/widgets.dart';
import 'setProfile.dart';

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
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String getErrorMessage(String message) {
    if (message.contains('email already exists')) {
      return 'این ایمیل قبلاً ثبت شده است. لطفاً از ایمیل دیگری استفاده کنید.';
    } else if (message.contains('weak password')) {
      return 'رمز عبور انتخابی ضعیف است. لطفاً رمز عبور قوی‌تری وارد کنید.';
    } else if (message.contains('invalid email')) {
      return 'فرمت ایمیل وارد شده معتبر نیست. لطفاً ایمیل صحیح وارد کنید.';
    } else {
      return 'خطای نامشخصی رخ داده است. لطفاً دوباره تلاش کنید.';
    }
  }

  Future<void> createProfileIfNotExists() async {
    try {
      final account = ref.read(accountProvider);
      final user = await account.get();
      final databases = ref.read(databasesProvider);

      final documents = await databases.listDocuments(
        collectionId: '6759a45a0035156253ce',
        queries: [
          Query.equal('userId', user.$id),
        ],
        databaseId: 'vista_db',
      );

      if (documents.documents.isEmpty) {
        await databases.createDocument(
          collectionId: '6759a45a0035156253ce',
          data: {
            'id': ID.unique(),
            'userId': user.$id,
            'email': emailController.text.trim(),
          },
          databaseId: 'vista_db',
          documentId: user.$id, // ensures the document is linked to the user
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp() async {
    if (passController.text != confirmPasswordController.text) {
      context.showSnackBar('رمزعبور و تایید رمزعبور تطابق ندارد.',
          isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final account = ref.read(accountProvider);

      await account.create(
        userId: ID.unique(),
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );

      await account.createEmailPasswordSession(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );

      await createProfileIfNotExists();

      context.showSnackBar('حساب کاربری شما با موفقیت ایجاد شد :)');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SetProfileData()),
      );
    } on AppwriteException catch (e) {
      print('Appwrite Exception: $e'); // لاگ خطا
      final errorMessage = getErrorMessage(e.toString());
      context.showSnackBar(errorMessage, isError: true);
    } catch (e) {
      print('خطای غیرمنتظره: $e');
      context.showSnackBar('خطای غیرمنتظره‌ای رخ داده است.', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        children: [
          topText(text: 'به ویستا خوش اومدی'),
          const SizedBox(height: 80),
          customTextField('ایمیل', emailController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا مقادیر را وارد نمایید';
            }
          }, false, TextInputType.emailAddress, maxLines: 1),
          const SizedBox(height: 10),
          customTextField('رمزعبور', passController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا مقادیر را وارد نمایید';
            }
          }, true, TextInputType.visiblePassword, maxLines: 1),
          const SizedBox(height: 10),
          customTextField('تایید رمزعبور', confirmPasswordController, (value) {
            if (value == null || value.isEmpty) {
              return 'لطفا تایید رمزعبور را وارد نمایید';
            }
            if (value != passController.text) {
              return 'عدم تطابق رمزعبور';
            }
            return null;
          }, true, TextInputType.visiblePassword, maxLines: 1),
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
        child: customButton(
          isLoading ? null : signUp,
          isLoading ? '...در حال ورود' : 'ثبت نام',
          ref,
        ),
      ),
    );
  }
}

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
