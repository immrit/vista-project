import 'package:flutter/material.dart';

import '../utils/verification_badge_utils.dart';

class VerificationBadgeIcon extends StatelessWidget {
  final bool isVerified;
  final dynamic verificationType;
  final String? role;
  final double size;

  const VerificationBadgeIcon({
    super.key,
    required this.isVerified,
    required this.verificationType,
    this.role,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedType = resolveVerificationBadgeType(
      isVerified: isVerified,
      verificationType: verificationType,
      role: role,
    );

    if (resolvedType == ResolvedVerificationBadgeType.none) {
      return const SizedBox.shrink();
    }

    return Icon(
      Icons.verified,
      size: size,
      color: verificationBadgeColor(context, resolvedType),
    );
  }
}
