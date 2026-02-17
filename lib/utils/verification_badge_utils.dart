import 'package:flutter/material.dart';

const Color kVerifiedGold = Color(0xFFFFD700);

enum ResolvedVerificationBadgeType {
  none,
  blueTick,
  goldTick,
  blackTick,
}

ResolvedVerificationBadgeType parseVerificationBadgeType(dynamic raw) {
  if (raw == null) return ResolvedVerificationBadgeType.none;

  var value = raw.toString().trim();
  if (value.isEmpty) return ResolvedVerificationBadgeType.none;

  if (value.contains('.')) {
    value = value.split('.').last;
  }

  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  switch (normalized) {
    case 'blue':
    case 'bluetick':
      return ResolvedVerificationBadgeType.blueTick;
    case 'gold':
    case 'goldtick':
      return ResolvedVerificationBadgeType.goldTick;
    case 'black':
    case 'blacktick':
      return ResolvedVerificationBadgeType.blackTick;
    default:
      return ResolvedVerificationBadgeType.none;
  }
}

ResolvedVerificationBadgeType resolveVerificationBadgeType({
  required bool isVerified,
  dynamic verificationType,
  String? role,
}) {
  if (!isVerified) return ResolvedVerificationBadgeType.none;

  final parsedType = parseVerificationBadgeType(verificationType);
  return parsedType;
}

Color verificationBadgeColor(
  BuildContext context,
  ResolvedVerificationBadgeType type,
) {
  switch (type) {
    case ResolvedVerificationBadgeType.blueTick:
      return Colors.blue;
    case ResolvedVerificationBadgeType.goldTick:
      return kVerifiedGold;
    case ResolvedVerificationBadgeType.blackTick:
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return isDark ? Colors.white : Colors.black;
    case ResolvedVerificationBadgeType.none:
      return Colors.transparent;
  }
}
