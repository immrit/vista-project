class AppException implements Exception {
  final String userFriendlyMessage;
  final String? technicalMessage;

  AppException({
    required this.userFriendlyMessage,
    this.technicalMessage,
  });

  @override
  String toString() =>
      'AppException: $userFriendlyMessage (${technicalMessage ?? ""})';
}
