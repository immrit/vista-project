import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../provider/provider.dart';

Future<bool> showOtpDialog(
    BuildContext context, WidgetRef ref, String phoneNumber) async {
  final TextEditingController otpController = TextEditingController();
  bool isVerifying = false;
  String? error;
  int countdown = 60;
  Timer? timer;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'OTP Dialog',
    pageBuilder: (context, anim1, anim2) => const SizedBox(),
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, anim1, anim2, child) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          // Initialize timer if not already running
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (countdown > 0) {
              setDialogState(() => countdown--);
            } else {
              t.cancel();
            }
          });

          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: anim1,
              child: AlertDialog(
                backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Column(
                  children: [
                    const Icon(Icons.sms_outlined,
                        size: 48, color: Color(0xFF4A80F0)),
                    const SizedBox(height: 16),
                    Text(
                      'تأیید شماره تلفن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'کد ۵ رقمی ارسال شده به $phoneNumber را وارد کنید',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: error != null
                              ? Colors.red
                              : const Color(0xFF4A80F0).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    /*
                    if ((debugCode ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dev OTP: $debugCode',
                        style: const TextStyle(
                          color: Color(0xFF4A80F0),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    */
                    const SizedBox(height: 24),
                    if (countdown > 0)
                      Text(
                        'ارسال مجدد کد در $countdown ثانیه',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          // Resend logic
                          setDialogState(() {
                            countdown = 60;
                            error = null;
                            // Restart timer if it was cancelled
                            timer?.cancel();
                            timer =
                                Timer.periodic(const Duration(seconds: 1), (t) {
                              if (countdown > 0) {
                                setDialogState(() => countdown--);
                              } else {
                                t.cancel();
                              }
                            });
                          });
                          try {
                            await ref
                                .read(authControllerProvider.notifier)
                                .sendOtp(phoneNumber);
                            setDialogState(() {});
                          } catch (e) {
                            setDialogState(() => error = 'خطا در ارسال مجدد');
                          }
                        },
                        child: const Text('ارسال مجدد کد',
                            style: TextStyle(color: Color(0xFF4A80F0))),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.pop(context, false);
                    },
                    child: Text('انصراف',
                        style: TextStyle(
                            color:
                                isDarkMode ? Colors.white54 : Colors.black45)),
                  ),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            if (otpController.text.length < 5) return;
                            setDialogState(() {
                              isVerifying = true;
                              error = null;
                            });
                            try {
                              final success = await ref
                                  .read(authControllerProvider.notifier)
                                  .verifyOtp(
                                      phone: phoneNumber,
                                      token: otpController.text);
                              if (!context.mounted) return;
                              if (success) {
                                timer?.cancel();
                                Navigator.pop(context, true);
                              } else {
                                setDialogState(() {
                                  isVerifying = false;
                                  error = 'کد وارد شده اشتباه است';
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                isVerifying = false;
                                error = 'خطا در تایید کد';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('تأیید'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  timer?.cancel();
  return result ?? false;
}
