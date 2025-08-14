import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Simple end-to-end encryption helper based on X25519 + XChaCha20-Poly1305.
///
/// Envelope format stored in `messages.content` when encrypted:
///   e2ee:v1:xc20p:<senderPubKey_b64url>:<nonce_b64url>:<ciphertext_b64url>
///
/// - Key agreement: X25519
/// - KDF: HKDF-SHA256 with salt = conversationId and info = 'vista-e2ee-v1'
/// - AEAD: XChaCha20-Poly1305
class E2EEService {
  E2EEService._();
  static final E2EEService instance = E2EEService._();

  static const String _prefix = 'e2ee:v1:xc20p:';
  static const String _storageKeyPriv = 'e2ee_x25519_private';
  static const String _storageKeyPub = 'e2ee_x25519_public';
  static const String _pinnedPeerPrefix = 'e2ee_peer_pub_';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Random _random = Random.secure();

  final X25519 _x25519 = X25519();
  final Cipher _aead = Xchacha20.poly1305Aead();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Caches to accelerate decryption
  final Map<String, String> _publicKeyCache =
      <String, String>{}; // userId -> pubB64
  final Map<String, SecretKey> _conversationKeyCache =
      <String, SecretKey>{}; // conversationId -> symmetric key

  bool _isInitialized = false;

  /// Call once on app start.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    // Using pure-dart cryptography backend for maximum compatibility
    _isInitialized = true;
  }

  /// Ensure local identity keypair exists and return it.
  Future<SimpleKeyPair> _getOrCreateIdentityKeyPair() async {
    // We persist a 32-byte seed for X25519 and reconstruct the keypair from it
    final List<int>? seed = await _readPrivateKeyBytes();
    if (seed != null) {
      return _x25519.newKeyPairFromSeed(seed);
    }
    final newSeed = _randomBytes(32);
    final keyPair = await _x25519.newKeyPairFromSeed(newSeed);
    final pub = (await keyPair.extractPublicKey()).bytes;
    await _storePrivateKeyBytes(newSeed);
    await _storePublicKeyBytes(pub);
    return keyPair;
  }

  /// Publish the user's public key into profiles.e2ee_public_key if missing or outdated.
  /// If the column doesn't exist on the backend, this will no-op gracefully.
  Future<void> publishOwnPublicKeyIfNeeded() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final keyPair = await _getOrCreateIdentityKeyPair();
    final pub = await keyPair.extractPublicKey();
    final pubB64 = base64UrlEncode(pub.bytes);

    try {
      final existing = await supabase
          .from('profiles')
          .select('e2ee_public_key')
          .eq('id', user.id)
          .maybeSingle();

      final current = existing?['e2ee_public_key'] as String?;
      if (current != pubB64) {
        await supabase
            .from('profiles')
            .update({'e2ee_public_key': pubB64}).eq('id', user.id);
      }
    } catch (_) {
      // Column might not exist yet. Ignore; encryption will be skipped until available.
    }
  }

  /// Encrypts plaintext for a specific conversation and recipient.
  /// Returns the envelope string or original plaintext if recipient key is not available.
  Future<String> maybeEncryptForRecipient({
    required String plaintext,
    required String conversationId,
    required String recipientUserId,
  }) async {
    if (plaintext.isEmpty) return plaintext;
    if (plaintext.startsWith(_prefix)) return plaintext; // already encrypted

    // Fetch recipient public key from profiles
    String? recipientPubB64;
    try {
      final resp = await supabase
          .from('profiles')
          .select('e2ee_public_key')
          .eq('id', recipientUserId)
          .maybeSingle();
      recipientPubB64 = resp?['e2ee_public_key'] as String?;
    } catch (_) {
      recipientPubB64 = null;
    }

    if (recipientPubB64 == null || recipientPubB64.isEmpty) {
      // No recipient key published: cannot encrypt. Return plaintext.
      return plaintext;
    }

    final recipientPub = SimplePublicKey(
      base64Url.decode(recipientPubB64),
      type: KeyPairType.x25519,
    );
    final myKeyPair = await _getOrCreateIdentityKeyPair();
    final myPub = await myKeyPair.extractPublicKey();

    final secret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: recipientPub,
    );
    final encKey = await _deriveSymmetricKey(secret, conversationId);

    final nonce = _randomBytes(24);
    final box = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: encKey,
      nonce: nonce,
    );

    final envelope = StringBuffer(_prefix)
      ..write(base64UrlEncode(myPub.bytes))
      ..write(':')
      ..write(base64UrlEncode(nonce))
      ..write(':')
      ..write(base64UrlEncode(box.cipherText + box.mac.bytes));
    return envelope.toString();
  }

  /// Pre-compute and cache the symmetric key for a conversation.
  Future<void> prepareConversationKey({
    required String conversationId,
    required String otherUserId,
  }) async {
    try {
      await ensureInitialized();
      if (_conversationKeyCache.containsKey(conversationId)) return;
      final otherPubB64 = await _getOrFetchUserPublicKeyB64(otherUserId);
      if (otherPubB64 == null || otherPubB64.isEmpty) return;
      final otherPub = SimplePublicKey(
        base64Url.decode(otherPubB64),
        type: KeyPairType.x25519,
      );
      final myKeyPair = await _getOrCreateIdentityKeyPair();
      final secret = await _x25519.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: otherPub,
      );
      final convKey = await _deriveSymmetricKey(secret, conversationId);
      _conversationKeyCache[conversationId] = convKey;
      await _pinPeerKeyIfFirstTime(senderId: otherUserId, pubB64: otherPubB64);
    } catch (_) {}
  }

  /// Decrypt fast using precomputed conversation key if available; otherwise fallback.
  Future<String> maybeDecryptFast({
    required String content,
    required String conversationId,
    required String otherUserId,
  }) async {
    if (content.isEmpty || !content.startsWith(_prefix)) return content;
    final parts = content.split(':');
    if (parts.length < 6) return content;
    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':');
    try {
      final convKey = _conversationKeyCache[conversationId];
      if (convKey != null) {
        final nonce = base64Url.decode(nonceB64);
        final raw = base64Url.decode(cipherB64);
        if (raw.length < 16) return content;
        final cipherText = raw.sublist(0, raw.length - 16);
        final mac = Mac(raw.sublist(raw.length - 16));
        final clear = await _aead.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: mac),
          secretKey: convKey,
        );
        return utf8.decode(clear);
      }
    } catch (_) {}
    // Fallback if no cached key
    return maybeDecryptWithOtherUser(
      content: content,
      conversationId: conversationId,
      otherUserId: otherUserId,
    );
  }

  /// Decrypts an envelope string if encrypted, otherwise returns the input.
  Future<String> maybeDecrypt({
    required String content,
    required String conversationId,
  }) async {
    if (content.isEmpty || !content.startsWith(_prefix)) return content;
    final parts = content.split(':');
    // Expected: [e2ee, v1, xc20p, senderPub, nonce, ciphertext]
    if (parts.length < 6) return content;
    final senderPubB64 = parts[3];
    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':'); // in case ':' appears later

    try {
      final senderPub = SimplePublicKey(
        base64Url.decode(senderPubB64),
        type: KeyPairType.x25519,
      );
      final nonce = base64Url.decode(nonceB64);
      final raw = base64Url.decode(cipherB64);
      if (raw.length < 16) return content; // too short for Poly1305 MAC
      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));

      final myKeyPair = await _getOrCreateIdentityKeyPair();

      // Optional: TOFU pinning check
      await _pinPeerKeyIfFirstTime(
          senderId: _inferSenderIdFromContext(), pubB64: senderPubB64);
      final pinned = await _readPinnedPeerKey(_inferSenderIdFromContext());
      if (pinned != null && pinned != senderPubB64) {
        // Key changed; refuse to decrypt to avoid MITM silently.
        return 'پیام رمزنگاری‌شده (عدم تطابق کلید)';
      }

      final secret = await _x25519.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: senderPub,
      );
      final decKey = await _deriveSymmetricKey(secret, conversationId);
      final clear = await _aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: decKey,
      );
      return utf8.decode(clear);
    } catch (_) {
      return 'پیام رمزنگاری‌شده (خطا در رمزگشایی)';
    }
  }

  /// Decrypt helper for reply previews.
  Future<String?> maybeDecryptNullable({
    required String? content,
    required String conversationId,
  }) async {
    if (content == null) return null;
    return maybeDecrypt(content: content, conversationId: conversationId);
  }

  /// Decrypt using the other user's public key first (works for both incoming and outgoing),
  /// and if it fails, fall back to the sender's public key from the envelope.
  Future<String> maybeDecryptWithOtherUser({
    required String content,
    required String conversationId,
    required String otherUserId,
  }) async {
    if (content.isEmpty || !content.startsWith(_prefix)) return content;
    final parts = content.split(':');
    if (parts.length < 6) return content;
    final envelopeSenderPubB64 = parts[3];
    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':');

    try {
      final nonce = base64Url.decode(nonceB64);
      final raw = base64Url.decode(cipherB64);
      if (raw.length < 16) return content;
      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));
      final myKeyPair = await _getOrCreateIdentityKeyPair();

      // Try remote = other user's public key
      final otherPubB64 = await _fetchUserPublicKeyB64(otherUserId);
      if (otherPubB64 != null && otherPubB64.isNotEmpty) {
        try {
          final remotePub = SimplePublicKey(
            base64Url.decode(otherPubB64),
            type: KeyPairType.x25519,
          );
          final secret = await _x25519.sharedSecretKey(
            keyPair: myKeyPair,
            remotePublicKey: remotePub,
          );
          final decKey = await _deriveSymmetricKey(secret, conversationId);
          final clear = await _aead.decrypt(
            SecretBox(cipherText, nonce: nonce, mac: mac),
            secretKey: decKey,
          );
          return utf8.decode(clear);
        } catch (_) {
          // try fallback below
        }
      }

      // Fallback: use sender public key from envelope
      final senderPub = SimplePublicKey(
        base64Url.decode(envelopeSenderPubB64),
        type: KeyPairType.x25519,
      );
      final secret2 = await _x25519.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: senderPub,
      );
      final decKey2 = await _deriveSymmetricKey(secret2, conversationId);
      final clear2 = await _aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: decKey2,
      );
      return utf8.decode(clear2);
    } catch (_) {
      return 'پیام رمزنگاری‌شده (خطا در رمزگشایی)';
    }
  }

  Future<String?> maybeDecryptWithOtherUserNullable({
    required String? content,
    required String conversationId,
    required String otherUserId,
  }) async {
    if (content == null) return null;
    return maybeDecryptWithOtherUser(
      content: content,
      conversationId: conversationId,
      otherUserId: otherUserId,
    );
  }

  // --- storage helpers ---

  Future<List<int>?> _readPrivateKeyBytes() async {
    try {
      if (kIsWeb) {
        final box = await _getSettingsBox();
        final b64 = box.get(_storageKeyPriv) as String?;
        if (b64 == null) return null;
        return base64Url.decode(b64);
      } else {
        final b64 = await _secure.read(key: _storageKeyPriv);
        if (b64 == null) return null;
        return base64Url.decode(b64);
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _storePrivateKeyBytes(List<int> bytes) async {
    final b64 = base64UrlEncode(bytes);
    if (kIsWeb) {
      final box = await _getSettingsBox();
      await box.put(_storageKeyPriv, b64);
    } else {
      await _secure.write(key: _storageKeyPriv, value: b64);
    }
  }

  Future<void> _storePublicKeyBytes(List<int> bytes) async {
    final b64 = base64UrlEncode(bytes);
    if (kIsWeb) {
      final box = await _getSettingsBox();
      await box.put(_storageKeyPub, b64);
    } else {
      await _secure.write(key: _storageKeyPub, value: b64);
    }
  }

  Future<Box> _getSettingsBox() async {
    if (Hive.isBoxOpen('settings')) {
      return Hive.box('settings');
    }
    return await Hive.openBox('settings');
  }

  Future<SecretKey> _deriveSymmetricKey(
      SecretKey shared, String saltStr) async {
    final sharedBytes = await shared.extractBytes();
    final salt = utf8.encode(saltStr);
    final info = utf8.encode('vista-e2ee-v1');
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: salt,
      info: info,
    );
    return key;
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  // --- peer key pinning (TOFU placeholder) ---
  Future<void> _pinPeerKeyIfFirstTime(
      {required String senderId, required String pubB64}) async {
    if (senderId.isEmpty) return;
    final existing = await _readPinnedPeerKey(senderId);
    if (existing == null) {
      await _writePinnedPeerKey(senderId, pubB64);
    }
  }

  Future<String?> _readPinnedPeerKey(String senderId) async {
    final key = '$_pinnedPeerPrefix$senderId';
    if (kIsWeb) {
      final box = await _getSettingsBox();
      return box.get(key) as String?;
    } else {
      return await _secure.read(key: key);
    }
  }

  Future<void> _writePinnedPeerKey(String senderId, String pubB64) async {
    final key = '$_pinnedPeerPrefix$senderId';
    if (kIsWeb) {
      final box = await _getSettingsBox();
      await box.put(key, pubB64);
    } else {
      await _secure.write(key: key, value: pubB64);
    }
  }

  // We don't have senderId in all contexts. This placeholder returns empty
  // to keep logic simple in this first integration.
  String _inferSenderIdFromContext() {
    final user = Supabase.instance.client.auth.currentUser;
    // Returning empty will skip pin checks; a later pass can plumb senderId here.
    return user?.id ?? '';
  }

  Future<String?> _fetchUserPublicKeyB64(String userId) async {
    try {
      final cached = _publicKeyCache[userId];
      if (cached != null) return cached;
      final resp = await Supabase.instance.client
          .from('profiles')
          .select('e2ee_public_key')
          .eq('id', userId)
          .maybeSingle();
      final value = resp?['e2ee_public_key'] as String?;
      if (value != null) {
        _publicKeyCache[userId] = value;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getOrFetchUserPublicKeyB64(String userId) async {
    final cached = _publicKeyCache[userId];
    if (cached != null) return cached;
    return _fetchUserPublicKeyB64(userId);
  }
}
