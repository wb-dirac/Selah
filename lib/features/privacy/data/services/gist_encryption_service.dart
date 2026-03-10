import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GistEncryptionService {
  const GistEncryptionService();

  Future<SecretKey> deriveKey(String passphrase, List<int> salt) async {
    final argon2id = Argon2id(
      memory: 65536,
      iterations: 3,
      parallelism: 1,
      hashLength: 32,
    );
    return argon2id.deriveKey(
      secretKey: SecretKeyData(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  Future<String> encrypt(String plaintext, String passphrase) async {
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));

    final key = await deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();

    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    // Format: salt(16 bytes) || iv(12 bytes) || ciphertext || tag(16 bytes)
    final combined = <int>[
      ...salt,
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    return base64.encode(combined);
  }

  Future<String> decrypt(String ciphertext, String passphrase) async {
    final bytes = base64.decode(ciphertext);

    // Minimum: salt(16) + iv(12) + tag(16) = 44 bytes; ciphertext can be 0
    if (bytes.length < 44) {
      throw Exception('Invalid ciphertext: too short (${bytes.length} bytes)');
    }

    final salt = bytes.sublist(0, 16);
    final nonce = bytes.sublist(16, 28);
    final macBytes = bytes.sublist(bytes.length - 16);
    final ciphertextBytes = bytes.sublist(28, bytes.length - 16);

    final key = await deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();

    final secretBox = SecretBox(
      ciphertextBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await algorithm.decrypt(secretBox, secretKey: key);
    return utf8.decode(decrypted);
  }
}

final gistEncryptionServiceProvider = Provider<GistEncryptionService>((ref) {
  return const GistEncryptionService();
});
