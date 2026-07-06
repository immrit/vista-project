import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../services/backend_upload_service.dart';
import '../../../../features/auth/providers/auth_controller.dart';
import '../../../../utils/user_friendly_error_utils.dart';
import 'package:Vista/core/theme/app_theme.dart';

class VerificationRequestPage extends ConsumerStatefulWidget {
  const VerificationRequestPage({super.key});

  @override
  ConsumerState<VerificationRequestPage> createState() =>
      _VerificationRequestPageState();
}

class _VerificationRequestPageState
    extends ConsumerState<VerificationRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // The identity document is uploaded to our storage and only its resulting
  // URL is submitted — the user no longer has to paste a cloud link by hand.
  String? _documentUrl;
  String? _documentName;
  bool _uploadingDoc = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() => _uploadingDoc = true);
      final userId = await TokenStorage.getUserId() ?? 'unknown';
      final ext = picked.path.split('.').last;
      final objectKey =
          'verification/$userId/${const Uuid().v4()}.$ext';
      final result = await BackendUploadService.uploadFile(
        file: File(picked.path),
        objectKey: objectKey,
        contentType: 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _documentUrl = result.url;
        _documentName = picked.name;
        _uploadingDoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDoc = false);
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documentUrl == null || _documentUrl!.isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(
          context, 'لطفاً تصویر مدرک هویتی را بارگذاری کنید');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ProfileRepository();
      await repo.requestVerification(
        category: _categoryController.text,
        documentUrl: _documentUrl!,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('درخواست با موفقیت ثبت شد و در صف بررسی قرار گرفت.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.lightSurfaceVariant,
      appBar: AppBar(
        title: const Text('درخواست تیک آبی'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified,
                      size: 64,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'با دریافت تیک آبی (تایید هویت)، حساب شما رسمی شده و امکانات بیشتری در اختیارتان قرار می‌گیرد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'دسته‌بندی (مثلا: هنرمند، شرکت، شخص عمومی)',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'لطفا دسته‌بندی را وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: (_uploadingDoc || _isLoading) ? null : _pickDocument,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _documentUrl != null
                          ? AppColors.primaryDark
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _documentUrl != null
                            ? Icons.check_circle
                            : Icons.upload_file_outlined,
                        color: _documentUrl != null
                            ? AppColors.primaryDark
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _uploadingDoc
                              ? 'در حال بارگذاری...'
                              : (_documentName ??
                                  'بارگذاری تصویر مدرک هویتی'),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_uploadingDoc)
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'توضیحات تکمیلی (اختیاری)',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'ثبت درخواست',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
