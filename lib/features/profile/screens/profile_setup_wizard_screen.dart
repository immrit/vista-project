import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/input_policy.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../provider/locale_provider.dart';
import '../../../utils/birth_date_picker.dart';
import '../../../utils/directional_navigation.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfileSetupWizardScreen extends ConsumerStatefulWidget {
  const ProfileSetupWizardScreen({super.key});

  @override
  ConsumerState<ProfileSetupWizardScreen> createState() =>
      _ProfileSetupWizardScreenState();
}

class _ProfileSetupWizardScreenState
    extends ConsumerState<ProfileSetupWizardScreen> {
  final _pageController = PageController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  int _step = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;
  String? _phoneNumber;
  String? _error;
  DateTime? _birthDate;
  String? _gender;
  String? _maritalStatus;

  static const _stepCount = 3;

  /// locale فعلی اپ — تقویم و نمایش تاریخ بر اساس این تعیین می‌شود.
  Locale get _effectiveLocale => ref.read(localeProvider);

  @override
  void initState() {
    super.initState();
    _loadInitialProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProfile() async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw 'نشست ورود معتبر نیست';
      }

      final user = await AuthRepository().me(accessToken);
      await TokenStorage.saveUserId(user.id);
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();

      final cachedProfile =
          await ProfileCacheService().getCachedProfile(user.id);
      Map<String, dynamic>? profile = cachedProfile?.toMap();
      if (profile == null) {
        try {
          profile = await ProfileRepository().fetchProfile(user.id);
        } catch (_) {
          profile = null;
        }
      }

      final parsedBirthDate =
          parseBirthDate(profile?['birth_date']?.toString());

      if (!mounted) return;
      setState(() {
        _userId = user.id;
        _phoneNumber = user.phoneNumber ?? profile?['phone_number']?.toString();
        _usernameController.text = user.username ?? '';
        _fullNameController.text = user.fullName;
        _emailController.text =
            user.email ?? profile?['email']?.toString() ?? '';
        _birthDate = parsedBirthDate;
        _gender = profile?['gender']?.toString();
        _maritalStatus = profile?['marital_status']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBackNavigation() {
    if (_step > 0) {
      _goToStep(_step - 1);
      return;
    }
    _showSnack('برای ورود به ویستا، تکمیل ثبت نام الزامی است');
  }

  void _goToStep(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step == 0 && !_validateIdentity()) return;
    if (_step == 1 && !_validateBirthDate()) return;
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
    } else {
      _completeProfile();
    }
  }

  bool _validateIdentity() {
    final username = normalizeDigits(_usernameController.text).trim();
    final usernameValidation = validateUsername(username);
    if (!usernameValidation.isValid) {
      _setError(usernameValidation.message);
      return false;
    }

    final fullName = normalizeDigits(_fullNameController.text).trim();
    if (fullName.length < 2) {
      _setError('نام کامل را وارد کنید');
      return false;
    }

    _usernameController.text = username.toLowerCase();
    _fullNameController.text = fullName;
    _setError(null);
    return true;
  }

  bool _validateBirthDate() {
    final birthDate = _birthDate;
    if (birthDate == null) {
      _setError('تاریخ تولد را انتخاب کنید');
      return false;
    }
    final now = DateTime.now();
    final age = now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
    if (age < 13) {
      _setError('حداقل سن مجاز برای ثبت نام ۱۳ سال است');
      return false;
    }
    if (_gender == null || _gender!.isEmpty) {
      _setError('جنسیت را انتخاب کنید');
      return false;
    }
    _setError(null);
    return true;
  }

  Future<void> _pickBirthDate() async {
    final locale = _effectiveLocale;
    final picked = await pickBirthDate(
      context,
      locale: locale,
      initialDate: _birthDate,
      helpText: 'تاریخ تولد',
      confirmText: 'تایید',
      cancelText: 'انصراف',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _error = null;
    });
  }

  Future<void> _completeProfile() async {
    if (!_validateIdentity() || !_validateBirthDate()) return;

    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _setError('شناسه کاربر پیدا نشد. دوباره وارد شوید');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final payload = <String, dynamic>{
      'username': _usernameController.text.trim().toLowerCase(),
      'full_name': _fullNameController.text.trim(),
      'birth_date': formatBirthDateForStorage(_birthDate!),
      if (_gender != null) 'gender': _gender,
      if (_maritalStatus != null) 'marital_status': _maritalStatus,
      'show_email': false,
      'show_birth_date': false,
      'show_gender': false,
      'show_marital_status': false,
      if (email.isNotEmpty) 'email': email,
    };

    try {
      final updated = await ProfileRepository().updateProfile(userId, payload);
      final refreshed =
          await ref.read(authControllerProvider.notifier).refreshCurrentUser();

      final isComplete = updated['profile_completed'] == true ||
          refreshed?.profileCompleted == true;

      if (!mounted) return;
      if (isComplete) {
        _showSnack('ثبت نام شما کامل شد');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        final missing = _missingFields(updated);
        setState(() {
          _isSaving = false;
          _error = missing.isEmpty
              ? 'ثبت نام هنوز کامل نشده است'
              : 'موارد ناقص: ${missing.join('، ')}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  List<String> _missingFields(Map<String, dynamic> profile) {
    final missing = <String>[];
    final username = profile['username']?.toString().trim() ?? '';
    final fullName = profile['full_name']?.toString().trim() ?? '';
    final birthDate = profile['birth_date']?.toString().trim() ?? '';
    final gender = profile['gender']?.toString().trim() ?? '';
    final phoneVerified = profile['phone_verified_at'] != null;
    final emailVerified = profile['email_verified_at'] != null;

    if (!validateUsername(username).isValid) missing.add('نام کاربری');
    if (fullName.isEmpty) missing.add('نام کامل');
    if (birthDate.isEmpty) missing.add('تاریخ تولد');
    if (gender.isEmpty) missing.add('جنسیت');
    if (!phoneVerified && !emailVerified) {
      missing.add('تایید شماره موبایل یا ایمیل');
    }
    return missing;
  }

  void _setError(String? message) {
    setState(() => _error = message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection:
          isLocaleRtl(context) ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBackNavigation();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: _step > 0
                ? IconButton(
                    tooltip: 'مرحله قبل',
                    onPressed: _isSaving ? null : () => _goToStep(_step - 1),
                    icon: Icon(directionalBackIcon(context)),
                  )
                : null,
            title: const Text('تکمیل ثبت نام'),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _userId == null
                    ? _buildFatalError(theme)
                    : Column(
                        children: [
                          _buildProgress(theme),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildIdentityStep(theme),
                                _buildBirthDateStep(theme),
                                _buildReviewStep(theme),
                              ],
                            ),
                          ),
                          _buildFooter(theme),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildFatalError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'خطا در بررسی نشست',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/auth',
                (_) => false,
              ),
              child: const Text('ورود دوباره'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Row(
        children: List.generate(_stepCount, (index) {
          final active = index <= _step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 5,
              margin: EdgeInsets.only(left: index == _stepCount - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPagePadding({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildIdentityStep(ThemeData theme) {
    return _buildPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined,
              size: 46, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'اول خودت را معرفی کن',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'نام کاربری و نام کامل برای ساخت پروفایل الزامی هستند.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _usernameController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'نام کاربری',
              hintText: 'vista_user',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fullNameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            decoration: const InputDecoration(
              labelText: 'نام کامل',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDateStep(ThemeData theme) {
    final locale = _effectiveLocale;
    final isPersian = isPersianLocale(locale);
    final birthDateLabel = _birthDate == null
        ? (isPersian ? 'انتخاب تاریخ تولد' : 'Select Date of Birth')
        : formatBirthDateForDisplay(_birthDate!, locale);

    return _buildPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cake_outlined, size: 46, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'مشخصات فردی',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'تاریخ تولد و جنسیت برای کامل شدن ثبت نام الزامی است.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(birthDateLabel),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'جنسیت (اجباری)',
              prefixIcon: Icon(Icons.person),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('مرد')),
              DropdownMenuItem(value: 'female', child: Text('زن')),
              DropdownMenuItem(
                  value: 'prefer_not_to_say', child: Text('ترجیح میدهم نگویم')),
            ],
            onChanged: (val) {
              setState(() {
                _gender = val;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _maritalStatus,
            decoration: const InputDecoration(
              labelText: 'وضعیت تاهل (اختیاری)',
              prefixIcon: Icon(Icons.favorite_outline),
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('مجرد')),
              DropdownMenuItem(value: 'married', child: Text('متاهل')),
              DropdownMenuItem(
                  value: 'prefer_not_to_say', child: Text('ترجیح میدهم نگویم')),
            ],
            onChanged: (val) {
              setState(() {
                _maritalStatus = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    return _buildPagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 46, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'بررسی نهایی',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'شماره موبایل شما تایید شده است. ایمیل اختیاری است و بعدا هم می توانید اضافه کنید.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryRow(label: 'نام کاربری', value: _usernameController.text),
          _SummaryRow(label: 'نام کامل', value: _fullNameController.text),
          _SummaryRow(
            label: 'تاریخ تولد',
            value: _birthDate == null
                ? '-'
                : formatBirthDateForDisplay(_birthDate!, _effectiveLocale),
          ),
          _SummaryRow(
              label: 'جنسیت',
              value: _gender == 'male'
                  ? 'مرد'
                  : _gender == 'female'
                      ? 'زن'
                      : _gender == 'prefer_not_to_say'
                          ? 'ترجیح میدهم نگویم'
                          : '-'),
          _SummaryRow(
              label: 'وضعیت تاهل',
              value: _maritalStatus == 'single'
                  ? 'مجرد'
                  : _maritalStatus == 'married'
                      ? 'متاهل'
                      : _maritalStatus == 'prefer_not_to_say'
                          ? 'ترجیح میدهم نگویم'
                          : '-'),
          if ((_phoneNumber ?? '').isNotEmpty)
            _SummaryRow(label: 'شماره موبایل', value: _phoneNumber!),
          const SizedBox(height: 18),
          TextField(
            controller: _emailController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'ایمیل اختیاری',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: _isSaving ? null : _next,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_step == _stepCount - 1 ? 'تکمیل ثبت نام' : 'ادامه'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
