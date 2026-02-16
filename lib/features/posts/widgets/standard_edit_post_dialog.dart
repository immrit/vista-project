import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/model/publicPostModel.dart';
import '../../../utils/user_friendly_error_utils.dart';

void showStandardEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PublicPostModel post,
  VoidCallback? onSuccess,
}) {
  final TextEditingController contentController =
      TextEditingController(text: post.content);
  bool isLoading = false;

  // تابع تشخیص جهت متن
  TextDirection getTextDirection(String text) {
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    final englishRegex = RegExp(r'[a-zA-Z]');

    int persianCount = persianRegex.allMatches(text).length;
    int englishCount = englishRegex.allMatches(text).length;

    if (persianCount > englishCount) {
      return TextDirection.rtl;
    } else {
      return TextDirection.ltr;
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('ویرایش پست'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بخش متن پست
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('متن پست:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection:
                              getTextDirection(contentController.text),
                          child: TextField(
                            controller: contentController,
                            maxLines: 4,
                            maxLength: 300,
                            textDirection:
                                getTextDirection(contentController.text),
                            onChanged: (value) {
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'متن پست را ویرایش کنید...',
                              counterText:
                                  '${contentController.text.length}/300',
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[700]
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('لغو'),
              ),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        final content = contentController.text.trim();
                        if (content.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('متن پست نمی‌تواند خالی باشد'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          final updateData = {
                            'content': content,
                            'updated_at': DateTime.now().toIso8601String(),
                          };

                          await supabase
                              .from('posts')
                              .update(updateData)
                              .eq('id', post.id);

                          if (onSuccess != null) {
                            onSuccess();
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('پست با موفقیت ویرایش شد'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() {
                              isLoading = false;
                            });
                            UserFriendlyErrorUtils.showErrorSnackBar(
                                context, e);
                          }
                        }
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('ذخیره تغییرات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
