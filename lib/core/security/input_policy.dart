class InputPolicyResult {
  final bool isValid;
  final String reasonCode;
  final String message;

  const InputPolicyResult._(
    this.isValid,
    this.reasonCode,
    this.message,
  );

  const InputPolicyResult.valid() : this._(true, 'ok', '');

  const InputPolicyResult.invalid(String reasonCode, String message)
      : this._(false, reasonCode, message);
}

const Set<String> kDefaultReservedUsernames = {
  'admin',
  'administrator',
  'support',
  'official',
  'security',
  'root',
  'system',
  'mod',
  'moderator',
  'owner',
  'help',
  'contact',
  'about',
  'api',
  'www',
  'mail',
  'postmaster',
  'abuse',
  'null',
  'undefined',
};

String normalizeDigits(String input) {
  const farsiDigits =
      '\u06F0\u06F1\u06F2\u06F3\u06F4\u06F5\u06F6\u06F7\u06F8\u06F9';
  const arabicDigits =
      '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
  var result = input;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(farsiDigits[i], '$i');
    result = result.replaceAll(arabicDigits[i], '$i');
  }
  return result;
}

String? normalizePhone09(String input) {
  var s = normalizeDigits(input).trim();
  if (s.isEmpty) return null;

  s = s.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  if (s.startsWith('+98')) {
    s = '0${s.substring(3)}';
  } else if (s.startsWith('0098')) {
    s = '0${s.substring(4)}';
  } else if (s.startsWith('98') && s.length == 12) {
    s = '0${s.substring(2)}';
  }

  if (!RegExp(r'^09\d{9}$').hasMatch(s)) return null;
  return s;
}

InputPolicyResult validateUsername(
  String input, {
  Set<String> reservedUsernames = kDefaultReservedUsernames,
}) {
  final username = normalizeDigits(input).trim();

  if (username.isEmpty) {
    return const InputPolicyResult.invalid(
      'username_required',
      'نام کاربری نمی تواند خالی باشد',
    );
  }

  if (username.length < 5 || username.length > 30) {
    return const InputPolicyResult.invalid(
      'username_length',
      'نام کاربری باید بین 5 تا 30 کاراکتر باشد',
    );
  }

  if (RegExp(r'[A-Z]').hasMatch(username)) {
    return const InputPolicyResult.invalid(
      'username_lowercase_only',
      'نام کاربری باید فقط با حروف کوچک انگلیسی باشد',
    );
  }

  if (!RegExp(r'^[a-z][a-z0-9._]{4,29}$').hasMatch(username)) {
    return const InputPolicyResult.invalid(
      'username_format',
      'نام کاربری فقط می تواند شامل حروف کوچک، عدد، نقطه و زیرخط باشد',
    );
  }

  if (username.contains('..')) {
    return const InputPolicyResult.invalid(
      'username_double_dot',
      'نام کاربری نمی تواند شامل دو نقطه پیاپی باشد',
    );
  }

  if (username.endsWith('.') || username.endsWith('_')) {
    return const InputPolicyResult.invalid(
      'username_suffix',
      'نام کاربری نباید با نقطه یا زیرخط تمام شود',
    );
  }

  if (reservedUsernames.contains(username)) {
    return const InputPolicyResult.invalid(
      'username_reserved',
      'این نام کاربری رزرو شده است',
    );
  }

  return const InputPolicyResult.valid();
}

InputPolicyResult validatePasswordBalanced(
  String password, {
  String? username,
  String? phone,
}) {
  final value = normalizeDigits(password);

  if (value.isEmpty) {
    return const InputPolicyResult.invalid(
      'password_required',
      'رمز عبور نمی تواند خالی باشد',
    );
  }

  if (value.length < 8) {
    return const InputPolicyResult.invalid(
      'password_length',
      'رمز عبور باید حداقل 8 کاراکتر باشد',
    );
  }

  if (RegExp(r'[\s]').hasMatch(value)) {
    return const InputPolicyResult.invalid(
      'password_whitespace',
      'رمز عبور نباید فاصله داشته باشد',
    );
  }

  if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
    return const InputPolicyResult.invalid(
      'password_control_char',
      'رمز عبور شامل کاراکتر نامعتبر است',
    );
  }

  var categories = 0;
  if (RegExp(r'[a-z]').hasMatch(value)) categories++;
  if (RegExp(r'[A-Z]').hasMatch(value)) categories++;
  if (RegExp(r'\d').hasMatch(value)) categories++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) categories++;

  if (categories < 3) {
    return const InputPolicyResult.invalid(
      'password_category',
      'رمز عبور باید حداقل 3 دسته از حروف کوچک، بزرگ، عدد و نماد را داشته باشد',
    );
  }

  final weakPasswords = {
    'password',
    'password123',
    'qwerty123',
    '12345678',
    '11111111',
    '00000000',
  };
  if (weakPasswords.contains(value.toLowerCase())) {
    return const InputPolicyResult.invalid(
      'password_weak_common',
      'رمز عبور انتخاب شده ضعیف است',
    );
  }

  final usernamePart = (username ?? '').trim().toLowerCase();
  if (usernamePart.length >= 3 &&
      value.toLowerCase().contains(usernamePart.toLowerCase())) {
    return const InputPolicyResult.invalid(
      'password_contains_username',
      'رمز عبور نباید شامل نام کاربری باشد',
    );
  }

  final phoneNormalized = phone == null ? null : normalizePhone09(phone);
  if (phoneNormalized != null && phoneNormalized.length >= 4) {
    final last4 = phoneNormalized.substring(phoneNormalized.length - 4);
    if (value.contains(last4)) {
      return const InputPolicyResult.invalid(
        'password_contains_phone',
        'رمز عبور نباید شامل بخش قابل حدس از شماره موبایل باشد',
      );
    }
  }

  return const InputPolicyResult.valid();
}

Map<String, dynamic> sanitizeProfilePayload(
  Map<String, dynamic> rawPayload, {
  Set<String> criticalKeys = const {
    'username',
    'email',
    'full_name',
    'phone_number',
  },
}) {
  final sanitized = <String, dynamic>{};

  for (final entry in rawPayload.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) continue;

    if (value is String) {
      var text = normalizeDigits(value).trim();

      if (key == 'username') {
        text = text.toLowerCase();
        final usernameValidation = validateUsername(text);
        if (!usernameValidation.isValid) {
          continue;
        }
      }

      if (key == 'phone_number') {
        final normalized = normalizePhone09(text);
        if (normalized == null) continue;
        sanitized[key] = normalized;
        continue;
      }

      if (key == 'email' && text.isNotEmpty) {
        final lower = text.toLowerCase();
        if (!RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[A-Za-z]{2,}$').hasMatch(lower) &&
            criticalKeys.contains(key)) {
          continue;
        }
        sanitized[key] = lower;
        continue;
      }

      if (text.isEmpty && criticalKeys.contains(key)) {
        continue;
      }

      sanitized[key] = text;
      continue;
    }

    sanitized[key] = value;
  }

  return sanitized;
}
