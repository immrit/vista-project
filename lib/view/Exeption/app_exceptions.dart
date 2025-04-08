class AppException implements Exception {
  final String userFriendlyMessage;
  final String technicalMessage;

  AppException({
    required this.userFriendlyMessage,
    required this.technicalMessage,
  });

  @override
  String toString() => technicalMessage;
}
