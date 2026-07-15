import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'e2e_encryption_service.dart';

/// Group End-to-End Encryption Service implementing Sender Keys.
///
/// Architecture (SEC-11):
/// 1. Sender Key Generation: Each member generates a random 32-byte AES key (Sender Key)
///    for the group.
/// 2. Key Distribution: The Sender Key is encrypted pairwise for every other group member
///    using the existing X25519 `E2EEncryptionService`.
/// 3. Message Encryption: Messages sent to the group are encrypted using the user's
///    Sender Key, utilizing the same HKDF-based per-message key derivation to prevent
///    nonce collision, ensuring high volume security.
///
/// Envelope layout for Group Messages:
/// `"VE2E_GROUP_V1:" + base64( salt(16) | nonceLen(1) | nonce | macLen(1) | mac | ct )`
class GroupE2EService {
  static final GroupE2EService _instance = GroupE2EService._internal();
  factory GroupE2EService() => _instance;
  GroupE2EService._internal();

  final _cipher = AesGcm.with256bits();
  final Random _rng = Random.secure();
  static const int _kSaltLength = 16;
  static const String _kGroupEnvelopeV1 = 'VE2E_GROUP_V1:';
  static const String _kGroupHkdfInfo = 'vista-e2e-group-v1';

  List<int> _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// Derive a fresh per-message AES-256 key from the root Sender Key.
  Future<SecretKey> _deriveMessageKey(
    SecretKey senderKey,
    List<int> salt,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: senderKey,
      nonce: salt,
      info: utf8.encode(_kGroupHkdfInfo),
    );
  }

  /// Generate a random 32-byte Sender Key for a group.
  String generateSenderKey() {
    final bytes = _randomBytes(32);
    return base64Encode(bytes);
  }

  /// Encrypt a Sender Key for distribution to a specific participant
  /// using the X25519 E2E channel.
  Future<String> encryptSenderKeyForParticipant({
    required String senderKeyB64,
    required SimpleKeyPair myKeyPair,
    required List<int> peerPublicKeyBytes,
  }) async {
    final sharedSecret = await E2EEncryptionService().computeSharedSecret(
      myKeyPair: myKeyPair,
      peerPublicKeyBytes: peerPublicKeyBytes,
    );
    return await E2EEncryptionService().encryptMessage(senderKeyB64, sharedSecret);
  }

  /// Decrypt a received Sender Key from a specific participant
  /// using the X25519 E2E channel.
  Future<String> decryptSenderKeyFromParticipant({
    required String encryptedSenderKey,
    required SimpleKeyPair myKeyPair,
    required List<int> peerPublicKeyBytes,
  }) async {
    final sharedSecret = await E2EEncryptionService().computeSharedSecret(
      myKeyPair: myKeyPair,
      peerPublicKeyBytes: peerPublicKeyBytes,
    );
    return await E2EEncryptionService().decryptMessage(encryptedSenderKey, sharedSecret);
  }

  /// Encrypt a message using a Sender Key.
  Future<String> encryptGroupMessage(String plainText, String senderKeyB64) async {
    final senderKeyBytes = base64Decode(senderKeyB64);
    final senderKey = SecretKey(senderKeyBytes);

    final salt = _randomBytes(_kSaltLength);
    final messageKey = await _deriveMessageKey(senderKey, salt);

    final clearTextBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: messageKey,
    );

    final nonce = secretBox.nonce;
    final mac = secretBox.mac.bytes;
    final ct = secretBox.cipherText;

    final buffer = BytesBuilder()
      ..add(salt)
      ..addByte(nonce.length)
      ..add(nonce)
      ..addByte(mac.length)
      ..add(mac)
      ..add(ct);

    return _kGroupEnvelopeV1 + base64Encode(buffer.toBytes());
  }

  /// Decrypt a message using a Sender Key.
  Future<String> decryptGroupMessage(String cipherText, String senderKeyB64) async {
    if (!cipherText.startsWith(_kGroupEnvelopeV1)) {
      // Not a v1 group encrypted message. Return as is.
      return cipherText;
    }

    try {
      final b64 = cipherText.substring(_kGroupEnvelopeV1.length);
      final raw = base64Decode(b64);

      var offset = 0;

      final salt = raw.sublist(offset, offset + _kSaltLength);
      offset += _kSaltLength;

      final nonceLen = raw[offset];
      offset += 1;
      final nonce = raw.sublist(offset, offset + nonceLen);
      offset += nonceLen;

      final macLen = raw[offset];
      offset += 1;
      final mac = raw.sublist(offset, offset + macLen);
      offset += macLen;

      final ct = raw.sublist(offset);

      final senderKeyBytes = base64Decode(senderKeyB64);
      final senderKey = SecretKey(senderKeyBytes);
      final messageKey = await _deriveMessageKey(senderKey, salt);

      final secretBox = SecretBox(
        ct,
        nonce: nonce,
        mac: Mac(mac),
      );

      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: messageKey,
      );

      return utf8.decode(clearTextBytes);
    } catch (_) {
      // MAC failure / truncation on a v1 envelope means tampering or a wrong
      // key. Never hand ciphertext to the UI as if it were the message body —
      // surface an explicit tamper marker instead (mirrors E2EEService).
      throw const GroupE2ETamperException();
    }
  }
}

/// Thrown when a v1 group envelope fails authentication (tamper/wrong key).
class GroupE2ETamperException implements Exception {
  const GroupE2ETamperException();

  @override
  String toString() => 'GroupE2ETamperException: MAC verification failed';
}
