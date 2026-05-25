import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class E2EEncryptionService {
  final _algorithm = X25519(); // Elliptic Curve Diffie-Hellman
  final _cipher = AesGcm.with256bits();
  final _storage = const FlutterSecureStorage();

  // Singleton instance
  static final E2EEncryptionService _instance = E2EEncryptionService._internal();
  factory E2EEncryptionService() => _instance;
  E2EEncryptionService._internal();

  /// تولید جفت کلید (عمومی و خصوصی) برای دیوایس فعلی و ذخیره آن‌ها
  Future<SimpleKeyPair> generateAndSaveKeyPair(String userId) async {
    final keyPair = await _algorithm.newKeyPair();
    
    // استخراج بایت‌های کلید خصوصی
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    
    // ذخیره در فضای امن
    await _storage.write(key: 'e2e_priv_$userId', value: base64Encode(privateKeyBytes));
    await _storage.write(key: 'e2e_pub_$userId', value: base64Encode(publicKey.bytes));
    
    return keyPair;
  }

  /// بازیابی جفت کلید ذخیره شده
  Future<SimpleKeyPair?> getSavedKeyPair(String userId) async {
    final privB64 = await _storage.read(key: 'e2e_priv_$userId');
    final pubB64 = await _storage.read(key: 'e2e_pub_$userId');
    
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

  /// رمزنگاری پیام متنی با استفاده از کلید مشترک
  Future<String> encryptMessage(
      String plainText, SecretKey sharedSecret) async {
    final clearTextBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: sharedSecret,
    );

    // ساختار: [nonce_length (1 byte)] + [nonce] + [mac_length (1 byte)] + [mac] + [cipher_text]
    final buffer = BytesBuilder();
    buffer.addByte(secretBox.nonce.length);
    buffer.add(secretBox.nonce);
    buffer.addByte(secretBox.mac.bytes.length);
    buffer.add(secretBox.mac.bytes);
    buffer.add(secretBox.cipherText);

    return base64Encode(buffer.toBytes());
  }

  /// رمزگشایی پیام متنی با استفاده از کلید مشترک
  Future<String> decryptMessage(
      String encryptedBase64, SecretKey sharedSecret) async {
    try {
      final bytes = base64Decode(encryptedBase64);
      var offset = 0;

      final nonceLength = bytes[offset++];
      final nonce = bytes.sublist(offset, offset + nonceLength);
      offset += nonceLength;

      final macLength = bytes[offset++];
      final macBytes = bytes.sublist(offset, offset + macLength);
      offset += macLength;

      final cipherText = bytes.sublist(offset);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return utf8.decode(clearTextBytes);
    } catch (e) {
      return '[پیام غیرقابل رمزگشایی]';
    }
  }
}
