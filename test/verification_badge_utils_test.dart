import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/utils/verification_badge_utils.dart';

void main() {
  group('parseVerificationBadgeType', () {
    test('maps blue/gold/black tick variants', () {
      expect(
        parseVerificationBadgeType('blueTick'),
        ResolvedVerificationBadgeType.blueTick,
      );
      expect(
        parseVerificationBadgeType('goldTick'),
        ResolvedVerificationBadgeType.goldTick,
      );
      expect(
        parseVerificationBadgeType('blackTick'),
        ResolvedVerificationBadgeType.blackTick,
      );
      expect(
        parseVerificationBadgeType('blue'),
        ResolvedVerificationBadgeType.blueTick,
      );
      expect(
        parseVerificationBadgeType('gold'),
        ResolvedVerificationBadgeType.goldTick,
      );
      expect(
        parseVerificationBadgeType('black'),
        ResolvedVerificationBadgeType.blackTick,
      );
    });

    test('is case-insensitive and supports enum-style strings', () {
      expect(
        parseVerificationBadgeType('GoLdTiCk'),
        ResolvedVerificationBadgeType.goldTick,
      );
      expect(
        parseVerificationBadgeType('VerificationType.blueTick'),
        ResolvedVerificationBadgeType.blueTick,
      );
      expect(
        parseVerificationBadgeType('StoryVerificationType.black'),
        ResolvedVerificationBadgeType.blackTick,
      );
    });

    test('returns none for unknown/empty values', () {
      expect(
        parseVerificationBadgeType(''),
        ResolvedVerificationBadgeType.none,
      );
      expect(
        parseVerificationBadgeType('unknown'),
        ResolvedVerificationBadgeType.none,
      );
      expect(
        parseVerificationBadgeType(null),
        ResolvedVerificationBadgeType.none,
      );
    });
  });

  group('resolveVerificationBadgeType', () {
    test('returns none when user is not verified, even with valid type', () {
      expect(
        resolveVerificationBadgeType(
          isVerified: false,
          verificationType: 'black',
          role: 'premium',
        ),
        ResolvedVerificationBadgeType.none,
      );
    });

    test('returns parsed type when user is verified and type is valid', () {
      expect(
        resolveVerificationBadgeType(
          isVerified: true,
          verificationType: 'blackTick',
          role: 'premium',
        ),
        ResolvedVerificationBadgeType.blackTick,
      );
    });

    test('returns none for unknown type', () {
      expect(
        resolveVerificationBadgeType(
          isVerified: true,
          verificationType: 'invalid_type',
          role: 'premium',
        ),
        ResolvedVerificationBadgeType.none,
      );
    });
  });

  group('verificationBadgeColor', () {
    testWidgets('black tick is black in light theme', (tester) async {
      Color? color;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              color = verificationBadgeColor(
                context,
                ResolvedVerificationBadgeType.blackTick,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(color, Colors.black);
    });

    testWidgets('black tick is white in dark theme', (tester) async {
      Color? color;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              color = verificationBadgeColor(
                context,
                ResolvedVerificationBadgeType.blackTick,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(color, Colors.white);
    });
  });
}
