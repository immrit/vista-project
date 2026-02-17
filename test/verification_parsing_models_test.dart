import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/model/CommentModel.dart' as comment_model;
import 'package:Vista/model/ProfileModel.dart' as profile_model;
import 'package:Vista/model/notificationModel.dart' as notification_model;
import 'package:Vista/model/publicPostModel.dart';

void main() {
  group('ProfileModel parsing', () {
    test('supports mixed verification_type formats', () {
      final profile = profile_model.ProfileModel.fromMap({
        'id': 'u1',
        'username': 'alice',
        'is_verified': true,
        'verification_type': 'GoLdTiCk',
      });

      expect(profile.verificationType, profile_model.VerificationType.goldTick);
    });

    test('does not fallback to premium role when user is not verified', () {
      final profile = profile_model.ProfileModel.fromMap({
        'id': 'u2',
        'username': 'bob',
        'is_verified': false,
        'verification_type': '',
        'role': 'premium',
      });

      expect(profile.verificationType, profile_model.VerificationType.none);
    });
  });

  group('PublicPostModel parsing', () {
    test('parses short verification values from profiles', () {
      final post = PublicPostModel.fromMap({
        'id': 'p1',
        'user_id': 'u1',
        'full_name': 'Alice',
        'content': 'hello',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'profiles': {
          'username': 'alice',
          'avatar_url': '',
          'is_verified': true,
          'verification_type': 'black',
          'role': 'member',
        },
      });

      expect(post.verificationType, profile_model.VerificationType.blackTick);
    });
  });

  group('CommentModel parsing', () {
    test('parses enum-style verification strings', () {
      final comment = comment_model.CommentModel.fromMap({
        'id': 'c1',
        'post_id': 'p1',
        'user_id': 'u1',
        'content': 'nice',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'owner_id': 'owner1',
        'profiles': {
          'username': 'alice',
          'avatar_url': '',
          'is_verified': true,
          'verification_type': 'VerificationType.blueTick',
          'role': 'member',
        },
      });

      expect(comment.verificationType, comment_model.VerificationType.blueTick);
    });

    test('does not fallback to premium when verification_type is unknown', () {
      final comment = comment_model.CommentModel.fromMap({
        'id': 'c2',
        'post_id': 'p1',
        'user_id': 'u2',
        'content': 'hi',
        'created_at': DateTime(2026, 1, 2).toIso8601String(),
        'owner_id': 'owner1',
        'profiles': {
          'username': 'bob',
          'avatar_url': '',
          'is_verified': false,
          'verification_type': 'unknown_type',
          'role': 'premium',
        },
      });

      expect(comment.verificationType, comment_model.VerificationType.none);
    });
  });

  group('NotificationModel parsing', () {
    test('fromMap supports short values blue/gold/black', () {
      final notification = notification_model.NotificationModel.fromMap({
        'id': 'n1',
        'sender_id': 'u1',
        'recipient_id': 'u2',
        'content': 'test',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'type': 'like',
        'sender': {
          'username': 'alice',
          'full_name': 'Alice',
          'avatar_url': '',
          'is_verified': true,
          'verification_type': 'blue',
        },
      });

      expect(
        notification.verificationType,
        notification_model.VerificationType.blueTick,
      );
    });

    test('fromPayloadJson supports tick-form values', () {
      final notification =
          notification_model.NotificationModel.fromPayloadJson({
        'id': 'n2',
        'sender_id': 'u1',
        'recipient_id': 'u2',
        'content': 'test',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'type': 'comment',
        'username': 'alice',
        'full_name': 'Alice',
        'is_verified': true,
        'verification_type': 'blackTick',
      });

      expect(
        notification.verificationType,
        notification_model.VerificationType.blackTick,
      );
    });

    test('fromPayloadJson does not fallback to premium for unknown type', () {
      final notification =
          notification_model.NotificationModel.fromPayloadJson({
        'id': 'n3',
        'sender_id': 'u1',
        'recipient_id': 'u2',
        'content': 'test',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'type': 'follow',
        'username': 'premium_user',
        'full_name': 'Premium User',
        'is_verified': false,
        'verification_type': 'invalid',
        'role': 'premium',
      });

      expect(
        notification.verificationType,
        notification_model.VerificationType.none,
      );
    });
  });
}
