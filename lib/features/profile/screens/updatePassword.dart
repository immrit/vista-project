import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:Vista/core/security/input_policy.dart';

import '../../../provider/provider.dart';
import '../../auth/providers/auth_controller.dart';

class ChangePasswordWidget extends ConsumerStatefulWidget {
  const ChangePasswordWidget({super.key});

  @override
  ConsumerState<ChangePasswordWidget> createState() =>
      _ChangePasswordWidgetState();
}

class _ChangePasswordWidgetState extends ConsumerState<ChangePasswordWidget> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: do NOT ref.watch(changePasswordProvider) here — that would fire a
    // change-password request with empty fields on every build. It's invoked
    // only from the submit button via ref.read(...).future below.
    final activeUser = ref.watch(activeUserProvider);
    final prefill = activeUser?.phoneNumber ??
        activeUser?.email ??
        activeUser?.username ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش رمزعبور'),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18.sp),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64.w,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: 24.h),
                Text(
                  'ویرایش رمز عبور',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'لطفاً رمز عبور فعلی و جدید خود را وارد کنید',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOld,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    hintText: 'رمز عبور فعلی',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOld ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureOld = !_obscureOld;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا رمز عبور فعلی را وارد نمایید';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    hintText: 'رمز عبور جدید',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا پسورد جدید را وارد نمایید';
                    }
                    final validation = validatePasswordBalanced(value);
                    if (!validation.isValid) {
                      return validation.message;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    hintText: 'تایید رمز عبور جدید',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا تایید رمز عبور را وارد نمایید';
                    }
                    if (value != _newPasswordController.text) {
                      return 'عدم تطابق رمز عبور';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await ref.read(changePasswordProvider((
                            oldPassword: _oldPasswordController.text,
                            newPassword: _newPasswordController.text,
                          )).future);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('پسورد جدید با موفقیت ثبت شد')),
                            );
                            Navigator.pop(context);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ویرایش رمز عبور',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/reset-password',
                      arguments: {
                        'prefill': prefill,
                      },
                    );
                  },
                  child: const Text('فراموشی رمز عبور؟'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
