import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sembast/sembast.dart' show Database, StoreRef;
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../DB/e2ee_cache_service_wrapper.dart';

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
  final E2EEDecryptedCacheService _decryptedCache = E2EEDecryptedCacheService();

  bool _isInitialized = false;

  /// Call once on app start.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    // Using pure-dart cryptography backend for maximum compatibility
    _isInitialized = true;
  }

  /// Clear all caches - useful for debugging or when keys change
  void clearCaches() {
    print('[e2ee] Clearing all caches...');
    _publicKeyCache.clear();
    _conversationKeyCache.clear();
    print('[e2ee] Caches cleared successfully');
  }

  /// Clear decrypted message cache
  Future<void> clearDecryptedCache() async {
    try {
      await _decryptedCache.clearAllCache();
      print('[e2ee] Decrypted message cache cleared');
    } catch (e) {
      print('[e2ee] Error clearing decrypted cache: $e');
    }
  }

  /// Clear decrypted cache for a specific conversation
  Future<void> clearConversationDecryptedCache({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _decryptedCache.clearConversationCache(
        conversationId: conversationId,
        userId: userId,
      );
      print('[e2ee] Conversation decrypted cache cleared: $conversationId');
    } catch (e) {
      print('[e2ee] Error clearing conversation decrypted cache: $e');
    }
  }

  /// Clean up old decrypted cache entries
  Future<void> cleanupOldDecryptedCache({int daysOld = 30}) async {
    try {
      // Temporarily disable this feature to avoid errors
      print('[e2ee] Old decrypted cache cleanup skipped (feature disabled)');
    } catch (e) {
      print('[e2ee] Error cleaning up old decrypted cache: $e');
    }
  }

  /// Get cached decrypted content for a message
  Future<String?> getCachedDecryptedContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    return await _decryptedCache.getDecryptedContent(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
    );
  }

  // --- storage helpers ---

  Future<List<int>?> _readPrivateKeyBytes() async {
    try {
      print('[encode] _readPrivateKeyBytes called');

      // Try Sembast first (preferred for consistency)
      try {
        final db = await _getSettingsDatabase();
        final b64 = await _settingsStore.record(_storageKeyPriv).get(db);
        if (b64 != null) {
          print(
              '[encode] Private key found in Sembast settings, length: ${b64.length}');
          final decoded = base64Url.decode(b64);
          print(
              '[encode] Private key decoded successfully, length: ${decoded.length}');
          return decoded;
        }
      } catch (e) {
        print('[encode] Error reading from Sembast: $e');
      }

      // Fallback to secure storage for backward compatibility
      if (!kIsWeb) {
        print('[encode] Reading from secure storage as fallback...');
        final b64 = await _secure.read(key: _storageKeyPriv);
        if (b64 != null) {
          print(
              '[encode] Private key found in secure storage, migrating to Hive...');
          final decoded = base64Url.decode(b64);

          // Migrate to Sembast
          try {
            final db = await _getSettingsDatabase();
            await _settingsStore.record(_storageKeyPriv).put(db, b64);
            print('[encode] Private key migrated to Sembast successfully');
          } catch (e) {
            print('[encode] Error migrating private key to Sembast: $e');
          }

          return decoded;
        }
      }

      print('[encode] No private key found in any storage');
      return null;
    } catch (e) {
      print('[encode] Error reading private key bytes: $e');
      return null;
    }
  }

  Future<void> _storePrivateKeyBytes(List<int> bytes) async {
    try {
      print('[encode] _storePrivateKeyBytes called, length: ${bytes.length}');
      final b64 = base64UrlEncode(bytes);
      print('[encode] Encoded private key, length: ${b64.length}');

      // Store in Sembast settings database (preferred)
      final db = await _getSettingsDatabase();
      await _settingsStore.record(_storageKeyPriv).put(db, b64);
      print('[encode] Private key stored in Sembast settings successfully');

      // Also store in secure storage for backward compatibility
      if (!kIsWeb) {
        try {
          await _secure.write(key: _storageKeyPriv, value: b64);
          print(
              '[encode] Private key also stored in secure storage for compatibility');
        } catch (e) {
          print('[encode] Warning: Could not store in secure storage: $e');
        }
      }
    } catch (e) {
      print('[encode] Error storing private key bytes: $e');
      rethrow;
    }
  }

  Future<void> _storePublicKeyBytes(List<int> bytes) async {
    try {
      print('[encode] _storePublicKeyBytes called, length: ${bytes.length}');
      final b64 = base64UrlEncode(bytes);
      print('[encode] Encoded public key, length: ${b64.length}');

      // Store in Sembast settings database (preferred)
      final db = await _getSettingsDatabase();
      await _settingsStore.record(_storageKeyPub).put(db, b64);
      print('[encode] Public key stored in Sembast settings successfully');

      // Also store in secure storage for backward compatibility
      if (!kIsWeb) {
        try {
          await _secure.write(key: _storageKeyPub, value: b64);
          print(
              '[encode] Public key also stored in secure storage for compatibility');
        } catch (e) {
          print(
              '[encode] Warning: Could not store public key in secure storage: $e');
        }
      }
    } catch (e) {
      print('[encode] Error storing public key bytes: $e');
      rethrow;
    }
  }

  Database? _settingsDatabase;
  final StoreRef<String, String> _settingsStore =
      StoreRef<String, String>.main();

  Future<Database> _getSettingsDatabase() async {
    if (_settingsDatabase != null) return _settingsDatabase!;

    try {
      String dbPath = 'settings.db';
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = '${appDir.path}/settings.db';
      }
      _settingsDatabase = await databaseFactoryIo.openDatabase(dbPath);
      return _settingsDatabase!;
    } catch (e) {
      print('خطا در باز کردن دیتابیس تنظیمات E2EE: $e');
      rethrow;
    }
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

  /// Ensure local identity keypair exists and return it.
  Future<SimpleKeyPair> _getOrCreateIdentityKeyPair() async {
    print('[encode] _getOrCreateIdentityKeyPair called');
    try {
      // We persist a 32-byte seed for X25519 and reconstruct the keypair from it
      print('[encode] Reading private key bytes from storage...');
      final List<int>? seed = await _readPrivateKeyBytes();
      if (seed != null) {
        print('[encode] Existing seed found, creating keypair from seed...');
        final keyPair = _x25519.newKeyPairFromSeed(seed);
        print('[encode] Keypair created from existing seed successfully');
        return keyPair;
      }
      print('[encode] No existing seed found, generating new keypair...');
      final newSeed = _randomBytes(32);
      print('[encode] New seed generated, length: ${newSeed.length}');
      final keyPair = await _x25519.newKeyPairFromSeed(newSeed);
      print('[encode] New keypair created successfully');
      final pub = (await keyPair.extractPublicKey()).bytes;
      print('[encode] Public key extracted, length: ${pub.length}');
      print('[encode] Storing private key bytes...');
      await _storePrivateKeyBytes(newSeed);
      print('[encode] Storing public key bytes...');
      await _storePublicKeyBytes(pub);
      print('[encode] Keypair creation and storage completed successfully');
      return keyPair;
    } catch (e) {
      print('[encode] Error in _getOrCreateIdentityKeyPair: $e');
      rethrow;
    }
  }

  /// Publish the user's public key into profiles.e2ee_public_key if missing or outdated.
  /// If the column doesn't exist on the backend, this will no-op gracefully.
  Future<void> publishOwnPublicKeyIfNeeded() async {
    print('[encode] publishOwnPublicKeyIfNeeded called');
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('[encode] No authenticated user, skipping key publication');
      return;
    }

    print('[encode] Getting or creating identity key pair...');
    final keyPair = await _getOrCreateIdentityKeyPair();
    final pub = await keyPair.extractPublicKey();
    final pubB64 = base64UrlEncode(pub.bytes);
    print('[encode] Own public key length: ${pub.bytes.length}');

    try {
      print('[encode] Checking existing public key in database...');
      final existing = await supabase
          .from('profiles')
          .select('e2ee_public_key')
          .eq('id', user.id)
          .maybeSingle();

      final current = existing?['e2ee_public_key'] as String?;
      print(
          '[encode] Current public key in database: ${current != null ? 'Found' : 'Not found'}');

      if (current != pubB64) {
        print('[encode] Public key needs update, publishing new key...');
        await supabase
            .from('profiles')
            .update({'e2ee_public_key': pubB64}).eq('id', user.id);
        print('[encode] Public key published successfully');
      } else {
        print('[encode] Public key is up to date, no update needed');
      }
    } catch (e) {
      print('[encode] Error publishing public key: $e');
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
    print(
        '[encode] Starting encryption for recipient: $recipientUserId, conversation: $conversationId');
    print('[encode] Plaintext length: ${plaintext.length}');

    if (plaintext.isEmpty) {
      print('[encode] Plaintext is empty, returning as-is');
      return plaintext;
    }
    if (plaintext.startsWith(_prefix)) {
      print('[encode] Message already encrypted, returning as-is');
      return plaintext; // already encrypted
    }

    // Fetch recipient public key from profiles
    String? recipientPubB64;
    try {
      print('[encode] Fetching recipient public key from database...');
      final resp = await supabase
          .from('profiles')
          .select('e2ee_public_key')
          .eq('id', recipientUserId)
          .maybeSingle();
      recipientPubB64 = resp?['e2ee_public_key'] as String?;
      print(
          '[encode] Recipient public key found: ${recipientPubB64 != null ? 'Yes' : 'No'}');
      if (recipientPubB64 != null) {
        print(
            '[encode] Recipient public key length: ${recipientPubB64.length}');
      }
    } catch (e) {
      print('[encode] Error fetching recipient public key: $e');
      recipientPubB64 = null;
    }

    if (recipientPubB64 == null || recipientPubB64.isEmpty) {
      print('[encode] No recipient key available, returning plaintext');
      return plaintext;
    }

    try {
      print('[encode] Creating recipient public key object...');
      final recipientPub = SimplePublicKey(
        base64Url.decode(recipientPubB64),
        type: KeyPairType.x25519,
      );

      print('[encode] Getting or creating own key pair...');
      final myKeyPair = await _getOrCreateIdentityKeyPair();
      final myPub = await myKeyPair.extractPublicKey();
      print('[encode] Own public key length: ${myPub.bytes.length}');

      print('[encode] Computing shared secret...');
      final secret = await _x25519.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: recipientPub,
      );
      print('[encode] Shared secret computed successfully');

      print('[encode] Deriving symmetric key...');
      final encKey = await _deriveSymmetricKey(secret, conversationId);
      print(
          '[encode] Symmetric key derived, length: ${(await encKey.extractBytes()).length}');

      print('[encode] Generating random nonce...');
      final nonce = _randomBytes(24);
      print('[encode] Nonce generated, length: ${nonce.length}');

      print('[encode] Encrypting plaintext...');
      final box = await _aead.encrypt(
        utf8.encode(plaintext),
        secretKey: encKey,
        nonce: nonce,
      );
      print(
          '[encode] Encryption successful, cipher text length: ${box.cipherText.length}');
      print('[encode] MAC length: ${box.mac.bytes.length}');

      print('[encode] Creating envelope...');
      final envelope = StringBuffer(_prefix)
        ..write(base64UrlEncode(myPub.bytes))
        ..write(':')
        ..write(base64UrlEncode(nonce))
        ..write(':')
        ..write(base64UrlEncode(box.cipherText + box.mac.bytes));

      final result = envelope.toString();
      print(
          '[encode] Envelope created successfully, total length: ${result.length}');
      print(
          '[encode] Envelope format: ${result.substring(0, result.length > 100 ? 100 : result.length)}...');

      return result;
    } catch (e) {
      print('[encode] Error during encryption process: $e');
      print('[encode] Returning plaintext due to encryption failure');
      return plaintext;
    }
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

  // --- peer key pinning (TOFU placeholder) ---
  Future<void> _pinPeerKeyIfFirstTime(
      {required String senderId, required String pubB64}) async {
    if (senderId.isEmpty) return;
    final existing = await _readPinnedPeerKey(senderId);
    if (existing == null) {
      await _writePinnedPeerKey(senderId, pubB64);
    }
  }

  // --- conversation key persistence ---
  Future<void> _storeConversationKey(
      String conversationId, SecretKey key) async {
    try {
      final keyBytes = await key.extractBytes();
      final b64 = base64UrlEncode(keyBytes);
      final storageKey = 'e2ee_conv_key_$conversationId';

      // Store in Sembast settings database (same as other app data)
      final db = await _getSettingsDatabase();
      await _settingsStore.record(storageKey).put(db, b64);
      print(
          '[encode] Conversation key stored in Sembast settings: $conversationId');
    } catch (e) {
      print('[encode] Error storing conversation key: $e');
    }
  }

  Future<SecretKey?> _loadConversationKey(String conversationId) async {
    try {
      final storageKey = 'e2ee_conv_key_$conversationId';

      // Load from Sembast settings database (same as other app data)
      final db = await _getSettingsDatabase();
      final b64 = await _settingsStore.record(storageKey).get(db);

      if (b64 == null) {
        print(
            '[encode] No conversation key found in Sembast settings: $conversationId');
        return null;
      }

      final keyBytes = base64Url.decode(b64);
      final key = SecretKey(keyBytes);
      print(
          '[encode] Conversation key loaded from Sembast settings: $conversationId');
      return key;
    } catch (e) {
      print('[encode] Error loading conversation key: $e');
      return null;
    }
  }

  Future<String?> _readPinnedPeerKey(String senderId) async {
    final key = '$_pinnedPeerPrefix$senderId';
    final db = await _getSettingsDatabase();
    return await _settingsStore.record(key).get(db);
  }

  Future<void> _writePinnedPeerKey(String senderId, String pubB64) async {
    final key = '$_pinnedPeerPrefix$senderId';
    final db = await _getSettingsDatabase();
    await _settingsStore.record(key).put(db, pubB64);
  }

  /// Pre-compute and cache the symmetric key for a conversation.
  Future<void> prepareConversationKey({
    required String conversationId,
    required String otherUserId,
  }) async {
    try {
      await ensureInitialized();

      // Check if key already exists in memory cache
      if (_conversationKeyCache.containsKey(conversationId)) {
        print(
            '[encode] Conversation key already cached in memory: $conversationId');
        return;
      }

      // Try to load from persistent storage first
      final cachedKey = await _loadConversationKey(conversationId);
      if (cachedKey != null) {
        _conversationKeyCache[conversationId] = cachedKey;
        print('[encode] Conversation key loaded from storage: $conversationId');
        return;
      }

      // Generate new key if not found in storage
      print('[encode] Generating new conversation key for: $conversationId');
      final otherPubB64 = await _getOrFetchUserPublicKeyB64(otherUserId);
      if (otherPubB64 == null || otherPubB64.isEmpty) {
        print(
            'E2EE prepareConversationKey: No public key found for user $otherUserId');
        return;
      }
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

      // Store in persistent storage
      await _storeConversationKey(conversationId, convKey);

      await _pinPeerKeyIfFirstTime(senderId: otherUserId, pubB64: otherPubB64);
      print(
          'E2EE prepareConversationKey: Successfully prepared key for conversation $conversationId with user $otherUserId');
    } catch (e) {
      print(
          'E2EE prepareConversationKey failed for conversation $conversationId with user $otherUserId: $e');
    }
  }

  /// Decrypt fast using precomputed conversation key if available; otherwise fallback.
  Future<String> maybeDecryptFast({
    required String content,
    required String conversationId,
    required String otherUserId,
  }) async {
    print(
        '[decode] maybeDecryptFast called for other user: $otherUserId, conversation: $conversationId');

    if (content.isEmpty) {
      print('[decode] Content is empty, returning as-is');
      return content;
    }

    if (!content.startsWith(_prefix)) {
      print('[decode] Content is not encrypted (plain text), returning as-is');
      return content;
    }

    final parts = content.split(':');
    if (parts.length < 6) {
      print('[decode] Invalid envelope format in fast path');
      return content;
    }

    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':');
    print(
        '[decode] Fast path - nonce length: ${nonceB64.length}, cipher length: ${cipherB64.length}');

    try {
      // Try memory cache first
      var convKey = _conversationKeyCache[conversationId];
      if (convKey != null) {
        print('[decode] Using cached key from memory for fast decryption');
      } else {
        // Try to load from persistent storage
        print('[decode] No memory cache, trying to load from storage...');
        convKey = await _loadConversationKey(conversationId);
        if (convKey != null) {
          _conversationKeyCache[conversationId] = convKey;
          print('[decode] Loaded key from storage and cached in memory');
        }
      }

      if (convKey != null) {
        print('[decode] Using cached key for fast decryption');
        final nonce = base64Url.decode(nonceB64);
        final raw = base64Url.decode(cipherB64);
        if (raw.length < 16) {
          print('[decode] Cipher text too short for MAC in fast path');
          return content;
        }
        final cipherText = raw.sublist(0, raw.length - 16);
        final mac = Mac(raw.sublist(raw.length - 16));
        final clear = await _aead.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: mac),
          secretKey: convKey,
        );
        final result = utf8.decode(clear);
        print(
            '[decode] Fast decryption successful, result length: ${result.length}');
        return result;
      } else {
        print(
            '[decode] No cached key for conversation $conversationId, falling back to other user method');
      }
    } catch (e) {
      print(
          '[decode] Fast decryption failed: $e, falling back to other user method');
    }
    // Fallback if no cached key
    try {
      return await maybeDecryptWithOtherUser(
        content: content,
        conversationId: conversationId,
        otherUserId: otherUserId,
      );
    } catch (e) {
      print('[decode] Other user method also failed: $e');
      return content; // Return original content to indicate decryption failed
    }
  }

  /// Decrypts an envelope string if encrypted, otherwise returns the input.
  Future<String> maybeDecrypt({
    required String content,
    required String conversationId,
  }) async {
    print('[decode] Starting decryption for conversation: $conversationId');
    print('[decode] Content length: ${content.length}');
    print(
        '[decode] Content starts with prefix: ${content.startsWith(_prefix)}');

    if (content.isEmpty) {
      print('[decode] Content is empty, returning as-is');
      return content;
    }

    if (!content.startsWith(_prefix)) {
      print('[decode] Content is not encrypted (plain text), returning as-is');
      return content;
    }

    final parts = content.split(':');
    print('[decode] Envelope parts count: ${parts.length}');
    // Expected: [e2ee, v1, xc20p, senderPub, nonce, ciphertext]
    if (parts.length < 6) {
      print('[decode] Invalid envelope format, not enough parts');
      return content;
    }

    final senderPubB64 = parts[3];
    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':'); // in case ':' appears later

    print('[decode] Sender public key length: ${senderPubB64.length}');
    print('[decode] Nonce length: ${nonceB64.length}');
    print('[decode] Cipher text length: ${cipherB64.length}');

    try {
      print('[decode] Creating sender public key object...');
      final senderPub = SimplePublicKey(
        base64Url.decode(senderPubB64),
        type: KeyPairType.x25519,
      );

      print('[decode] Decoding nonce and cipher text...');
      final nonce = base64Url.decode(nonceB64);
      final raw = base64Url.decode(cipherB64);
      print('[decode] Decoded nonce length: ${nonce.length}');
      print('[decode] Decoded raw length: ${raw.length}');

      if (raw.length < 16) {
        print('[decode] Cipher text too short for MAC, returning as-is');
        return content; // too short for Poly1305 MAC
      }

      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));
      print('[decode] Cipher text length: ${cipherText.length}');
      print('[decode] MAC length: ${mac.bytes.length}');

      print('[decode] Getting or creating own key pair...');
      final myKeyPair = await _getOrCreateIdentityKeyPair();

      // Try to decrypt with sender's public key from envelope
      try {
        print('[decode] Attempting decryption with sender key...');
        final secret = await _x25519.sharedSecretKey(
          keyPair: myKeyPair,
          remotePublicKey: senderPub,
        );
        print('[decode] Shared secret computed successfully');

        final decKey = await _deriveSymmetricKey(secret, conversationId);
        print('[decode] Decryption key derived successfully');

        final clear = await _aead.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: mac),
          secretKey: decKey,
        );
        final result = utf8.decode(clear);
        print(
            '[decode] Decryption successful with sender key, result length: ${result.length}');
        return result;
      } catch (e) {
        print('[decode] Decryption failed with sender key: $e');
        // If envelope key fails, try to use current user's key (for own old messages)
        try {
          print('[decode] Attempting decryption with own key...');
          final myPub = await myKeyPair.extractPublicKey();
          final secret2 = await _x25519.sharedSecretKey(
            keyPair: myKeyPair,
            remotePublicKey: myPub,
          );
          print('[decode] Shared secret with own key computed successfully');

          final decKey2 = await _deriveSymmetricKey(secret2, conversationId);
          print('[decode] Decryption key with own key derived successfully');

          final clear2 = await _aead.decrypt(
            SecretBox(cipherText, nonce: nonce, mac: mac),
            secretKey: decKey2,
          );
          final result2 = utf8.decode(clear2);
          print(
              '[decode] Decryption successful with own key, result length: ${result2.length}');
          return result2;
        } catch (e2) {
          print('[decode] Decryption failed with own key: $e2');
          // Return an empty string to indicate decryption failed, to satisfy the return type
          return '';
        }
      }
    } catch (e) {
      print('[decode] Decryption failed during parsing: $e');
      // Return an empty string to indicate decryption failed, to satisfy the return type
      return '';
    }
  }

  /// Decrypts an envelope string with specific sender ID for better key management.
  Future<String> maybeDecryptWithSender({
    required String content,
    required String conversationId,
    required String senderId,
    String? messageId,
    String? userId,
    DateTime? messageCreatedAt,
  }) async {
    print(
        '[decode] maybeDecryptWithSender called for sender: $senderId, conversation: $conversationId');

    if (content.isEmpty) {
      print('[decode] Content is empty, returning as-is');
      return content;
    }

    if (!content.startsWith(_prefix)) {
      print('[decode] Content is not encrypted (plain text), returning as-is');
      return content;
    }

    // Try to get from cache first
    if (messageId != null && userId != null) {
      try {
        final cachedContent = await _decryptedCache.getDecryptedContent(
          messageId: messageId,
          conversationId: conversationId,
          userId: userId,
        );
        if (cachedContent != null) {
          print(
              '[decode] Using cached decrypted content for message: $messageId');
          return cachedContent;
        }
      } catch (e) {
        print('[decode] Error getting cached content: $e');
      }
    }

    // Decrypt the content
    String decryptedContent;
    try {
      print('[decode] Trying fast decryption path...');
      decryptedContent = await maybeDecryptFast(
        content: content,
        conversationId: conversationId,
        otherUserId: senderId,
      );
      print('[decode] Fast decryption successful');
    } catch (e) {
      print('[decode] Fast decryption failed: $e, trying fallback...');
      // Fallback to general decryption
      try {
        decryptedContent = await maybeDecrypt(
          content: content,
          conversationId: conversationId,
        );
        print('[decode] Fallback decryption completed');
      } catch (e2) {
        print('[decode] Fallback decryption also failed: $e2');
        // Throw an exception to indicate decryption failed, since null can't be returned
        throw Exception('[decode] Decryption failed: $e2');
      }
    }
    if (messageId != null && userId != null && messageCreatedAt != null) {
      try {
        await _decryptedCache.cacheDecryptedMessage(
          messageId: messageId,
          conversationId: conversationId,
          userId: userId,
          decryptedContent: decryptedContent,
          createdAt: messageCreatedAt,
        );
        print('[decode] Decrypted content cached for message: $messageId');
      } catch (e) {
        print('[decode] Error caching decrypted content: $e');
      }
    }

    return decryptedContent;
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
    print(
        '[decode] maybeDecryptWithOtherUser called for other user: $otherUserId, conversation: $conversationId');

    if (content.isEmpty) {
      print('[decode] Content is empty, returning as-is');
      return content;
    }

    if (!content.startsWith(_prefix)) {
      print('[decode] Content is not encrypted (plain text), returning as-is');
      return content;
    }

    final parts = content.split(':');
    if (parts.length < 6) {
      print('[decode] Invalid envelope format in other user method');
      return content;
    }

    final envelopeSenderPubB64 = parts[3];
    final nonceB64 = parts[4];
    final cipherB64 = parts.sublist(5).join(':');

    print(
        '[decode] Other user method - envelope sender key length: ${envelopeSenderPubB64.length}');
    print('[decode] Other user method - nonce length: ${nonceB64.length}');
    print('[decode] Other user method - cipher length: ${cipherB64.length}');

    try {
      print('[decode] Decoding nonce and cipher text...');
      final nonce = base64Url.decode(nonceB64);
      final raw = base64Url.decode(cipherB64);
      print('[decode] Decoded nonce length: ${nonce.length}');
      print('[decode] Decoded raw length: ${raw.length}');

      if (raw.length < 16) {
        print('[decode] Cipher text too short for MAC in other user method');
        return content;
      }

      final cipherText = raw.sublist(0, raw.length - 16);
      final mac = Mac(raw.sublist(raw.length - 16));
      print('[decode] Cipher text length: ${cipherText.length}');
      print('[decode] MAC length: ${mac.bytes.length}');

      print('[decode] Getting or creating own key pair...');
      final myKeyPair = await _getOrCreateIdentityKeyPair();

      // Try remote = other user's public key
      print('[decode] Fetching other user public key...');
      final otherPubB64 = await _fetchUserPublicKeyB64(otherUserId);
      if (otherPubB64 != null && otherPubB64.isNotEmpty) {
        print('[decode] Other user public key found, attempting decryption...');
        try {
          final remotePub = SimplePublicKey(
            base64Url.decode(otherPubB64),
            type: KeyPairType.x25519,
          );
          final secret = await _x25519.sharedSecretKey(
            keyPair: myKeyPair,
            remotePublicKey: remotePub,
          );
          print('[decode] Shared secret with other user computed successfully');

          final decKey = await _deriveSymmetricKey(secret, conversationId);
          print('[decode] Decryption key with other user derived successfully');

          final clear = await _aead.decrypt(
            SecretBox(cipherText, nonce: nonce, mac: mac),
            secretKey: decKey,
          );
          final result = utf8.decode(clear);
          print(
              '[decode] Decryption successful with other user key, result length: ${result.length}');
          return result;
        } catch (e) {
          print(
              '[decode] Decryption failed with other user key ($otherUserId): $e');
          // try fallback below
        }
      } else {
        print('[decode] No public key found for other user: $otherUserId');
      }

      // Fallback: use sender public key from envelope
      print('[decode] Trying fallback with envelope sender key...');
      try {
        final senderPub = SimplePublicKey(
          base64Url.decode(envelopeSenderPubB64),
          type: KeyPairType.x25519,
        );
        final secret2 = await _x25519.sharedSecretKey(
          keyPair: myKeyPair,
          remotePublicKey: senderPub,
        );
        print(
            '[decode] Shared secret with envelope sender computed successfully');

        final decKey2 = await _deriveSymmetricKey(secret2, conversationId);
        print(
            '[decode] Decryption key with envelope sender derived successfully');

        final clear2 = await _aead.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: mac),
          secretKey: decKey2,
        );
        final result2 = utf8.decode(clear2);
        print(
            '[decode] Decryption successful with envelope sender key, result length: ${result2.length}');
        return result2;
      } catch (e) {
        print('[decode] Decryption failed with envelope sender key: $e');
        // If envelope key also fails, try to use current user's key (for own old messages)
        print('[decode] Trying final fallback with own key...');
        try {
          final myPub = await myKeyPair.extractPublicKey();
          final secret3 = await _x25519.sharedSecretKey(
            keyPair: myKeyPair,
            remotePublicKey: myPub,
          );
          print('[decode] Shared secret with own key computed successfully');

          final decKey3 = await _deriveSymmetricKey(secret3, conversationId);
          print('[decode] Decryption key with own key derived successfully');

          final clear3 = await _aead.decrypt(
            SecretBox(cipherText, nonce: nonce, mac: mac),
            secretKey: decKey3,
          );
          final result3 = utf8.decode(clear3);
          print(
              '[decode] Decryption successful with own key, result length: ${result3.length}');
          return result3;
        } catch (e2) {
          print('[decode] Decryption failed with own key: $e2');
          // Since the method must return a Future<String>, throw to indicate failure
          rethrow;
        }
      }
    } catch (e) {
      print(
          '[decode] Decryption failed during parsing in maybeDecryptWithOtherUser: $e');
      // Since the method must return a Future<String>, throw to indicate failure
      rethrow;
    }
  }
}
