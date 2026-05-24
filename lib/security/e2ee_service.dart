import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'secure_kv_store.dart';
import 'logging_utility.dart';

class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  static const String _privateKeyStoreKey = 'e2ee_private_key';
  static const String _publicKeyStoreKey = 'e2ee_public_key';

  final X25519 _keyExchange = X25519();
  final _cipher = Chacha20.poly1305Aead();

  SimpleKeyPair? _keyPair;

  /// مقداردهی اولیه و تولید کلیدها در صورت نیاز
  Future<void> initialize() async {
    try {
      final privKeyStr = await SecureKeyValueStore.read(_privateKeyStoreKey);
      final pubKeyStr = await SecureKeyValueStore.read(_publicKeyStoreKey);

      if (privKeyStr != null && pubKeyStr != null) {
        final privBytes = base64Decode(privKeyStr);
        final pubBytes = base64Decode(pubKeyStr);

        _keyPair = SimpleKeyPairData(
          privBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
        logInfo('✅ E2EE Keys loaded from secure storage.');
      } else {
        await _generateAndStoreKeys();
      }
    } catch (e) {
      logError('❌ E2EE Initialization failed: $e');
      await _generateAndStoreKeys();
    }
  }

  /// تولید جفت‌کلید جدید و ذخیره‌سازی امن
  Future<void> _generateAndStoreKeys() async {
    _keyPair = await _keyExchange.newKeyPair();
    final privBytes = await _keyPair!.extractPrivateKeyBytes();
    final pubKey = await _keyPair!.extractPublicKey();
    final pubBytes = pubKey.bytes;

    await SecureKeyValueStore.write(
        _privateKeyStoreKey, base64Encode(privBytes));
    await SecureKeyValueStore.write(_publicKeyStoreKey, base64Encode(pubBytes));

    logInfo('✅ New E2EE KeyPair generated and securely stored.');

    // TODO: Send pubBytes to Backend API to register public key for current user
  }

  /// دریافت کلید عمومی کاربر جاری به صورت Base64
  Future<String?> getMyPublicKeyBase64() async {
    if (_keyPair == null) await initialize();
    if (_keyPair == null) return null;
    final pub = await _keyPair!.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// محاسبه کلید مشترک بین من و کاربر مقابل
  Future<SecretKey> _computeSharedSecret(
      String recipientPublicKeyBase64) async {
    if (_keyPair == null) await initialize();

    final recipientBytes = base64Decode(recipientPublicKeyBase64);
    final recipientPubKey =
        SimplePublicKey(recipientBytes, type: KeyPairType.x25519);

    return await _keyExchange.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: recipientPubKey,
    );
  }

  /// رمزنگاری متن خام پیام
  Future<String> encryptMessage(
      String plaintext, String recipientPublicKeyBase64) async {
    try {
      final sharedSecret = await _computeSharedSecret(recipientPublicKeyBase64);

      final secretBox = await _cipher.encrypt(
        utf8.encode(plaintext),
        secretKey: sharedSecret,
      );

      final combined = Uint8List(secretBox.nonce.length +
          secretBox.cipherText.length +
          secretBox.mac.bytes.length);
      combined.setAll(0, secretBox.nonce);
      combined.setAll(secretBox.nonce.length, secretBox.cipherText);
      combined.setAll(secretBox.nonce.length + secretBox.cipherText.length,
          secretBox.mac.bytes);

      return 'e2ee:v1:${base64Encode(combined)}';
    } catch (e) {
      logError('Encryption failed: $e');
      rethrow;
    }
  }

  /// رمزگشایی پیام رمزگذاری شده
  Future<String> decryptMessage(
      String encryptedPayload, String senderPublicKeyBase64) async {
    try {
      if (!encryptedPayload.startsWith('e2ee:v1:')) {
        return encryptedPayload; // پیام عادی است
      }

      final sharedSecret = await _computeSharedSecret(senderPublicKeyBase64);
      final payloadBytes =
          base64Decode(encryptedPayload.substring(8)); // حذف 'e2ee:v1:'

      // XChaCha20Poly1305: nonce is 24 bytes (or 12 for standard ChaCha20), mac is 16 bytes.
      // cryptography's default ChaCha20Poly1305 uses 12-byte nonce.
      final nonceLength = 12;
      final macLength = 16;

      if (payloadBytes.length < nonceLength + macLength) {
        throw Exception('Payload too short');
      }

      final nonce = payloadBytes.sublist(0, nonceLength);
      final cipherText =
          payloadBytes.sublist(nonceLength, payloadBytes.length - macLength);
      final macBytes = payloadBytes.sublist(payloadBytes.length - macLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final cleartextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return utf8.decode(cleartextBytes);
    } catch (e) {
      logError('Decryption failed: $e');
      return '🔒 [پیام رمزگشایی نشد]';
    }
  }
}
