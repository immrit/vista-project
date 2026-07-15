import 'package:Vista/features/chat/services/e2e_encryption_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = E2EEncryptionService();
  final secret = SecretKey(List<int>.generate(32, (index) => index));
  const binding = 'vista-e2ee-v2|conversation|sender|message|content';

  test('v2 envelope is bound to its message context', () async {
    final encrypted = await service.encryptMessage(
      'classified',
      secret,
      binding: binding,
    );

    expect(encrypted, startsWith('VE2E2:'));
    expect(
      await service.decryptMessage(encrypted, secret, binding: binding),
      'classified',
    );
    await expectLater(
      service.decryptMessage(encrypted, secret, binding: '$binding-moved'),
      throwsA(isA<E2EDecryptException>()),
    );
  });

  test('v1 envelope remains readable during rollout', () async {
    final encrypted = await service.encryptMessage('legacy-v1', secret);

    expect(encrypted, startsWith('VE2E1:'));
    expect(await service.decryptMessage(encrypted, secret), 'legacy-v1');
  });

  test('legacy e2ee:v1 ChaCha envelope remains readable', () async {
    final cipher = Chacha20.poly1305Aead();
    final box = await cipher.encrypt(
      utf8.encode('legacy chacha payload'),
      secretKey: secret,
    );
    final bytes = Uint8List(
        box.nonce.length + box.cipherText.length + box.mac.bytes.length)
      ..setAll(0, box.nonce)
      ..setAll(box.nonce.length, box.cipherText)
      ..setAll(box.nonce.length + box.cipherText.length, box.mac.bytes);
    final envelope = 'e2ee:v1:${base64Encode(bytes)}';

    expect(
      await service.decryptMessage(envelope, secret),
      'legacy chacha payload',
    );
  });

  test('secret-chat decrypt never accepts plaintext fallback', () async {
    await expectLater(
      service.decryptMessage('plaintext', secret),
      throwsA(isA<E2EDecryptException>()),
    );
  });
}
