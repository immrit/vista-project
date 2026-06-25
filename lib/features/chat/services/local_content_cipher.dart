import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// At-rest encryption for sensitive local message fields (SEC-10).
///
/// Isar 3.1 community has no built-in DB encryption, so message content sits in
/// plaintext on disk. This cipher transparently encrypts the `content` field
/// (and any other sensitive text) before it is written to Isar, and decrypts on
/// read inside `MessageEntity.toModel()`.
///
/// Design constraints that shaped this:
///   * `toModel()`/`fromModel()` are SYNCHRONOUS (load-bearing for the chat
///     stream's entity-snapshot cache), so the cipher must be sync. The
///     `encrypt` package (pointycastle-backed AES-GCM) is synchronous; the
///     `cryptography` package used for E2E is async, hence a separate cipher.
///   * Backward compatible + non-destructive: encrypted values carry the
///     `LC1:` prefix. Reads without the prefix are treated as legacy plaintext
///     and returned unchanged, so existing rows keep working and are migrated
///     lazily when they are next rewritten. Existing rows are never rewritten
///     by this change alone.
///   * Local search is server-side (`/chat/.../search`) and chat sort is by
///     `createdAt`, so encrypting `content` breaks neither.
///
/// AES-256-GCM, fresh 12-byte IV per value (authenticated; tamper → fail).
/// Stored layout: `"LC1:" + base64( iv(12) | ciphertext+gcmTag )`.
///
/// Key lifecycle: a 32-byte key is generated once and persisted in
/// flutter_secure_storage. [init] MUST be awaited before any Isar read/write so
/// the synchronous [encryptField]/[decryptField] always have the key. It is
/// wired into the Isar database manager's async open path. If the key is ever
/// lost (e.g. secure storage cleared on reinstall), encrypted local rows become
/// unreadable but are non-critical: messages re-sync from the server.
class LocalContentCipher {
  LocalContentCipher._();
  static final LocalContentCipher instance = LocalContentCipher._();

  static const String _prefix = 'LC1:';
  static const String _storageKey = 'local_content_aes_key_v1';
  static const int _ivLength = 12;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
  );
  final Random _rng = Random.secure();

  enc.Encrypter? _encrypter;
  bool _initialized = false;

  bool get isReady => _initialized && _encrypter != null;

  /// Load or create the local AES key. Idempotent and safe to await repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    try {
      var keyB64 = await _storage.read(key: _storageKey);
      if (keyB64 == null || keyB64.isEmpty) {
        final keyBytes = _randomBytes(32);
        keyB64 = base64Encode(keyBytes);
        await _storage.write(key: _storageKey, value: keyB64);
      }
      final key = enc.Key(base64Decode(keyB64));
      _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      _initialized = true;
    } catch (_) {
      // Fail open for availability: cipher stays not-ready, callers store/read
      // plaintext (legacy path). Correctness preserved; at-rest encryption
      // simply inactive until init succeeds.
      _initialized = false;
      _encrypter = null;
    }
  }

  /// Encrypt a plaintext field for storage. Returns an `LC1:`-prefixed token,
  /// or the input unchanged if the cipher isn't ready (fail-open).
  String encryptField(String plain) {
    final encrypter = _encrypter;
    if (encrypter == null || plain.isEmpty) return plain;
    try {
      final iv = enc.IV(_randomBytes(_ivLength));
      final encrypted = encrypter.encrypt(plain, iv: iv); // sync (AES-GCM)
      final buffer = BytesBuilder()
        ..add(iv.bytes)
        ..add(encrypted.bytes);
      return _prefix + base64Encode(buffer.toBytes());
    } catch (_) {
      return plain; // never lose the message to a crypto error
    }
  }

  /// Decrypt a stored field. Non-prefixed values are legacy plaintext and
  /// returned as-is. Returns the original token if decryption fails (e.g. lost
  /// key) so the UI degrades gracefully and the server copy can re-sync.
  String decryptField(String stored) {
    if (!stored.startsWith(_prefix)) return stored; // legacy plaintext
    final encrypter = _encrypter;
    if (encrypter == null) return stored;
    try {
      final bytes = base64Decode(stored.substring(_prefix.length));
      final iv = enc.IV(Uint8List.fromList(bytes.sublist(0, _ivLength)));
      final cipherBytes = bytes.sublist(_ivLength);
      return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      return stored;
    }
  }

  Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }
}
