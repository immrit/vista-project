// lib/features/auth/domain/auth_exceptions.dart

class NetworkAuthException implements Exception {
  final String message;
  const NetworkAuthException([this.message = 'اتصال به اینترنت برقرار نیست.']);

  @override
  String toString() => message;
}

class UnauthorizedAuthException implements Exception {
  final String message;
  const UnauthorizedAuthException([this.message = 'نشست شما منقضی شده است.']);

  @override
  String toString() => message;
}
