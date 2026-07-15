import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Vista/security/secure_kv_store.dart';

/// End-to-end encryption service for secret chats.
///
/// Crypto design (v1 envelope):
///   1. X25519 ECDH → raw shared secret (root key material).
///   2. Per-message AES key = HKDF-SHA256(ikm: rootSecret, salt: randomSalt,
///      info: _kHkdfInfo). A fresh 16-byte salt per message means every message
///      uses a distinct AES key → AES-GCM nonce reuse across messages is
///      impossible by construction (fixes the static-key/nonce-collision risk).
///   3. AES-256-GCM authenticated encryption.
///
/// Envelope layout (base64, prefixed with [_kEnvelopeV1] so detection is
/// explicit — no fragile "looks-encrypted" heuristics):
///   "VE2E1:" + base64( salt(16) | nonceLen(1) | nonce | macLen(1) | mac | ct )
///
/// Legacy messages (pre-v1, no prefix) used the raw shared secret directly as
/// the AES key. [decryptMessage] still reads them: MAC verification is the
/// oracle — if it fails the bytes were never ciphertext, so we return them
/// as-is instead of guessing by length.
///
/// NOTE — forward secrecy: this provides confidentiality + integrity + a
/// distinct key per message, but NOT forward secrecy / post-compromise
/// security. The root secret is long-lived, so leaking it exposes all
/// messages. True FS needs a Double-Ratchet-style design, which is
/// incompatible with the current "store ciphertext, re-derive on every stream
/// emit" architecture (a forward-deleting ratchet cannot re-decrypt history
/// after restart). Tracked separately as an architecture change.
class E2EEncryptionService {
  final _algorithm = X25519(); // Elliptic Curve Diffie-Hellman
  final _cipher = AesGcm.with256bits();
  final _legacyV1Cipher = Chacha20.poly1305Aead();

  // Explicit Android options. On flutter_secure_storage v10 the defaults are
  // already AES/GCM/NoPadding for data + RSA-OAEP-SHA256 for key wrapping
  // (EncryptedSharedPreferences is deprecated and ignored), so this mainly
  // documents intent and pins us to the strong default ciphers.
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
  );

  /// Envelope version tag for v1 (HKDF per-message key) ciphertext.
  static const String _kEnvelopeV1 = 'VE2E1:';
  static const String _kEnvelopeV2 = 'VE2E2:';
  static const String _kLegacyEnvelopeV1 = 'e2ee:v1:';

  /// HKDF context string — binds derived keys to this app/protocol version.
  static const String _kHkdfInfo = 'vista-e2e-msg-v1';

  static const int _kSaltLength = 16;

  // Singleton instance
  static final E2EEncryptionService _instance =
      E2EEncryptionService._internal();
  factory E2EEncryptionService() => _instance;
  E2EEncryptionService._internal();

  final Random _rng = Random.secure();

  /// تولید جفت کلید (عمومی و خصوصی) برای دیوایس فعلی و ذخیره آن‌ها
  Future<SimpleKeyPair> generateAndSaveKeyPair(String userId) async {
    final keyPair = await _algorithm.newKeyPair();

    // استخراج بایت‌های کلید خصوصی
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    // ذخیره در فضای امن
    await _storage.write(
        key: 'e2e_priv_$userId', value: base64Encode(privateKeyBytes));
    await _storage.write(
        key: 'e2e_pub_$userId', value: base64Encode(publicKey.bytes));

    return keyPair;
  }

  /// بازیابی جفت کلید ذخیره شده
  Future<SimpleKeyPair?> getSavedKeyPair(String userId) async {
    var privB64 = await _storage.read(key: 'e2e_priv_$userId');
    var pubB64 = await _storage.read(key: 'e2e_pub_$userId');

    // Repository sends historically used E2EEService, whose X25519 pair lived
    // under global legacy keys. Reuse and copy that pair instead of silently
    // rotating identity and making every existing conversation undecryptable.
    if (privB64 == null || pubB64 == null) {
      final legacyPriv = await SecureKeyValueStore.read('e2ee_private_key');
      final legacyPub = await SecureKeyValueStore.read('e2ee_public_key');
      if (legacyPriv != null && legacyPub != null) {
        privB64 = legacyPriv;
        pubB64 = legacyPub;
        try {
          await _storage.write(key: 'e2e_priv_$userId', value: legacyPriv);
          await _storage.write(key: 'e2e_pub_$userId', value: legacyPub);
        } catch (_) {
          // The legacy secure-store pair is still usable for this session.
          // A later startup can retry the non-destructive copy.
        }
      }
    }

    if (privB64 == null || pubB64 == null) return null;

    try {
      final privBytes = base64Decode(privB64);
      final pubBytes = base64Decode(pubB64);

      return SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    } catch (e) {
      return null;
    }
  }

  /// استخراج کلید عمومی به صورت بایت برای ارسال به سرور/مخاطب
  Future<List<int>> getPublicKeyBytes(SimpleKeyPair keyPair) async {
    final pubKey = await keyPair.extractPublicKey();
    return pubKey.bytes;
  }

  /// ساخت کلید مشترک (Shared Secret) با استفاده از کلید خصوصی خودمان و کلید عمومی مخاطب
  Future<SecretKey> computeSharedSecret({
    required SimpleKeyPair myKeyPair,
    required List<int> peerPublicKeyBytes,
  }) async {
    final peerPublicKey = SimplePublicKey(
      peerPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    return await _algorithm.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPublicKey,
    );
  }

  /// Derive a fresh per-message AES-256 key from the root shared secret.
  Future<SecretKey> _deriveMessageKey(
    SecretKey rootSecret,
    List<int> salt,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: rootSecret,
      nonce: salt, // HKDF salt
      info: utf8.encode(_kHkdfInfo),
    );
  }

  List<int> _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// رمزنگاری پیام متنی (v1 envelope: HKDF per-message key + AES-256-GCM)
  Future<String> encryptMessage(
    String plainText,
    SecretKey sharedSecret, {
    String? binding,
  }) async {
    final salt = _randomBytes(_kSaltLength);
    final messageKey = await _deriveMessageKey(sharedSecret, salt);

    final clearTextBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: messageKey,
      aad: binding == null ? const <int>[] : utf8.encode(binding),
    );

    // ساختار: [salt(16)] + [nonce_length (1)] + [nonce] + [mac_length (1)] + [mac] + [cipher_text]
    final buffer = BytesBuilder();
    buffer.add(salt);
    buffer.addByte(secretBox.nonce.length);
    buffer.add(secretBox.nonce);
    buffer.addByte(secretBox.mac.bytes.length);
    buffer.add(secretBox.mac.bytes);
    buffer.add(secretBox.cipherText);

    final prefix = binding == null ? _kEnvelopeV1 : _kEnvelopeV2;
    return prefix + base64Encode(buffer.toBytes());
  }

  /// رمزگشایی پیام متنی.
  ///
  /// Throws [E2EDecryptException] when bytes ARE a v1 envelope but fail MAC
  /// verification (tampering or wrong key) — callers can surface a tamper
  /// warning. For legacy/plaintext, returns best-effort (see class docs).
  Future<String> decryptMessage(
    String encrypted,
    SecretKey sharedSecret, {
    String? binding,
  }) async {
    if (encrypted.startsWith(_kLegacyEnvelopeV1)) {
      return _decryptLegacyV1(
          encrypted.substring(_kLegacyEnvelopeV1.length), sharedSecret);
    }
    if (encrypted.startsWith(_kEnvelopeV2)) {
      if (binding == null || binding.isEmpty) {
        throw const E2EDecryptException('v2 binding is required');
      }
      return _decryptEnvelope(
        encrypted.substring(_kEnvelopeV2.length),
        sharedSecret,
        aad: utf8.encode(binding),
      );
    }
    if (encrypted.startsWith(_kEnvelopeV1)) {
      return _decryptEnvelope(
          encrypted.substring(_kEnvelopeV1.length), sharedSecret);
    }
    return _decryptLegacy(encrypted, sharedSecret);
  }

  Future<String> _decryptLegacyV1(String b64, SecretKey sharedSecret) async {
    try {
      final bytes = base64Decode(b64);
      const nonceLength = 12;
      const macLength = 16;
      if (bytes.length <= nonceLength + macLength) {
        throw const FormatException('legacy v1 payload too short');
      }
      final nonce = bytes.sublist(0, nonceLength);
      final cipherText = bytes.sublist(nonceLength, bytes.length - macLength);
      final macBytes = bytes.sublist(bytes.length - macLength);
      final clearText = await _legacyV1Cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: sharedSecret,
      );
      return utf8.decode(clearText);
    } catch (_) {
      throw const E2EDecryptException('legacy v1 decrypt failed');
    }
  }

  Future<String> _decryptEnvelope(
    String b64,
    SecretKey sharedSecret, {
    List<int> aad = const <int>[],
  }) async {
    final Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      throw const E2EDecryptException('malformed v1 envelope (base64)');
    }
    try {
      var offset = 0;
      final salt = bytes.sublist(offset, offset + _kSaltLength);
      offset += _kSaltLength;

      final nonceLength = bytes[offset++];
      final nonce = bytes.sublist(offset, offset + nonceLength);
      offset += nonceLength;

      final macLength = bytes[offset++];
      final macBytes = bytes.sublist(offset, offset + macLength);
      offset += macLength;

      final cipherText = bytes.sublist(offset);

      final messageKey = await _deriveMessageKey(sharedSecret, salt);
      final clearTextBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: messageKey,
        aad: aad,
      );
      return utf8.decode(clearTextBytes);
    } on SecretBoxAuthenticationError {
      // MAC failed on a real v1 envelope → tampering or wrong key. Surface it.
      throw const E2EDecryptException('authentication failed (tampered?)');
    } catch (_) {
      throw const E2EDecryptException('v1 decrypt failed');
    }
  }

  /// Legacy unprefixed AES-GCM path. Failure stays fail-closed; callers decide
  /// whether the conversation is E2EE before invoking this service.
  Future<String> _decryptLegacy(
      String encrypted, SecretKey sharedSecret) async {
    try {
      final bytes = base64Decode(encrypted);
      var offset = 0;

      final nonceLength = bytes[offset++];
      final nonce = bytes.sublist(offset, offset + nonceLength);
      offset += nonceLength;

      final macLength = bytes[offset++];
      final macBytes = bytes.sublist(offset, offset + macLength);
      offset += macLength;

      final cipherText = bytes.sublist(offset);

      final clearTextBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: sharedSecret,
      );
      return utf8.decode(clearTextBytes);
    } catch (_) {
      // Not legacy ciphertext (MAC mismatch / not base64) → treat as plaintext.
      throw const E2EDecryptException('legacy decrypt failed');
    }
  }

  /// Whether [content] is a v1-encrypted envelope. Replaces the old
  /// length/space heuristic with an exact prefix check.
  bool isEncryptedEnvelope(String content) =>
      content.startsWith(_kEnvelopeV1) ||
      content.startsWith(_kEnvelopeV2) ||
      content.startsWith(_kLegacyEnvelopeV1);

  static String messageBinding({
    required String conversationId,
    required String senderId,
    required String messageId,
    String field = 'content',
  }) =>
      'vista-e2ee-v2|$conversationId|$senderId|$messageId|$field';

  /// Safety number (fingerprint) for out-of-band verification — defends against
  /// MITM key substitution. Both peers compute the SAME number by hashing the
  /// two public keys in a canonical (sorted) order. Render it for the user to
  /// compare with their contact (like Signal's safety numbers).
  Future<String> computeSafetyNumber(
    List<int> myPublicKey,
    List<int> peerPublicKey,
  ) async {
    // Canonical ordering so both sides agree regardless of who is "me".
    final a = Uint8List.fromList(myPublicKey);
    final b = Uint8List.fromList(peerPublicKey);
    final first = _compareBytes(a, b) <= 0 ? a : b;
    final second = identical(first, a) ? b : a;

    final digest = await Sha256().hash([...first, ...second]);
    return _formatSafetyNumber(digest.bytes);
  }

  int _compareBytes(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final d = a[i] - b[i];
      if (d != 0) return d;
    }
    return a.length - b.length;
  }

  /// Render the first 30 digits of the fingerprint as 6 groups of 5, the same
  /// readable grouping Signal uses.
  String _formatSafetyNumber(List<int> hash) {
    final sb = StringBuffer();
    for (final byte in hash) {
      sb.write(byte.toString().padLeft(3, '0'));
    }
    final digits = sb.toString().substring(0, 30);
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 5) {
      groups.add(digits.substring(i, i + 5));
    }
    return groups.join(' ');
  }
}

/// Raised when a v1 envelope fails authenticated decryption — distinct from a
/// plaintext/legacy message so callers can warn about possible tampering.
class E2EDecryptException implements Exception {
  final String message;
  const E2EDecryptException(this.message);
  @override
  String toString() => 'E2EDecryptException: $message';
}
