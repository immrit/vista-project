import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../util/widgets.dart';

import '../../../provider/provider.dart';

class ChangePasswordWidget extends ConsumerWidget {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ChangePasswordWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changePasswordState =
        ref.watch(changePasswordProvider(_newPasswordController.text));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش رمزعبور'),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18.sp),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            customTextField('رمزعبور', _newPasswordController, (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا پسورد جدید را وارد نمایید';
              }
              return null;
            }, true, TextInputType.visiblePassword),
            SizedBox(
              height: 10.h,
            ),
            customTextField('تایید رمزعبور', _confirmPasswordController,
                (value) {
              if (value == null || value.isEmpty) {
                return 'لطفا تایید رمزعبور را وارد نمایید';
              }
              if (value != _newPasswordController.text) {
                return 'عدم تطابق رمزعبور';
              }
              return null;
            }, true, TextInputType.visiblePassword),
            SizedBox(
              height: 10.h,
            ),
            customButton(() {
              if (_formKey.currentState!.validate()) {
                ref
                    .read(changePasswordProvider(_newPasswordController.text)
                        .future)
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password updated successfully')),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پسورد جدید ثبت شد')),
                  );
                });
              }
            }, 'ویرایش رمز عبور', ref),
          ],
        ),
      ),
    );
  }
}
