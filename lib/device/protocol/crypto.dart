import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

class SessionKeys {
  final Uint8List decryptionKey;
  final Uint8List encryptionKey;
  final Uint8List decryptionNonce;
  final Uint8List encryptionNonce;

  SessionKeys({
    required this.decryptionKey,
    required this.encryptionKey,
    required this.decryptionNonce,
    required this.encryptionNonce,
  });
}

class Crypto {
  // Compute HMAC-SHA256
  static Uint8List hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  // Derive the session keys from authKey, phoneNonce, and watchNonce
  static SessionKeys deriveKeys(
    Uint8List authKey,
    Uint8List phoneNonce,
    Uint8List watchNonce,
  ) {
    // initial_key = phone_nonce + watch_nonce
    final initialKey = Uint8List(phoneNonce.length + watchNonce.length);
    initialKey.setRange(0, phoneNonce.length, phoneNonce);
    initialKey.setRange(phoneNonce.length, initialKey.length, watchNonce);

    // hmac_key = HMAC-SHA256(key=initial_key, message=auth_key)
    final hmacKey = hmacSha256(initialKey, authKey);

    // HKDF-like key expansion loop matching the Java Mac.doFinal reset behavior
    final miwearAuthBytes = Uint8List.fromList('miwear-auth'.codeUnits);
    final output = BytesBuilder();

    List<int> tmp = [];
    int b = 1;

    while (output.length < 64) {
      final msg = BytesBuilder()
        ..add(tmp)
        ..add(miwearAuthBytes)
        ..addByte(b);
      tmp = hmacSha256(hmacKey, msg.takeBytes());
      output.add(tmp);

      b += 1;
    }

    final step2hmac = output.takeBytes();

    return SessionKeys(
      decryptionKey: step2hmac.sublist(0, 16),
      encryptionKey: step2hmac.sublist(16, 32),
      decryptionNonce: step2hmac.sublist(32, 36),
      encryptionNonce: step2hmac.sublist(36, 40),
    );
  }

  // AES-CTR Encrypt (Standard Command Channel 1)
  // We initialize the CTR counter with the KEY itself.
  static Uint8List encrypt(Uint8List plaintext, Uint8List key) {
    final keyObj = enc.Key(key);
    final ivObj = enc.IV(key);
    final encrypter = enc.Encrypter(
      enc.AES(keyObj, mode: enc.AESMode.ctr, padding: null),
    );
    return Uint8List.fromList(
      encrypter.encryptBytes(plaintext, iv: ivObj).bytes,
    );
  }

  // AES-CTR Decrypt (Standard Command Channel 1)
  // We initialize the CTR counter with the KEY itself.
  static Uint8List decrypt(Uint8List ciphertext, Uint8List key) {
    final keyObj = enc.Key(key);
    final ivObj = enc.IV(key);
    final encrypter = enc.Encrypter(
      enc.AES(keyObj, mode: enc.AESMode.ctr, padding: null),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: ivObj),
    );
  }

  // AES-CTR Decrypt for Data payloads (Channel 2)
  // Extracts the first 16 bytes as the IV, and decrypts the remaining payload.
  static Uint8List decryptData(Uint8List ciphertext, Uint8List key) {
    if (ciphertext.length < 16) {
      throw ArgumentError('Ciphertext is too short (must be at least 16 bytes for IV)');
    }
    final iv = ciphertext.sublist(0, 16);
    final encryptedData = ciphertext.sublist(16);

    final keyObj = enc.Key(key);
    final ivObj = enc.IV(iv);
    final encrypter = enc.Encrypter(
      enc.AES(keyObj, mode: enc.AESMode.ctr, padding: null),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(enc.Encrypted(encryptedData), iv: ivObj),
    );
  }

  // AES-CCM Encrypt
  static Uint8List encryptCcm(
    Uint8List plaintext,
    Uint8List key,
    Uint8List nonce, {
    int macSizeBits = 32,
  }) {
    final aesEngine = pc.AESEngine();
    final ccm = pc.CCMBlockCipher(aesEngine);
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      macSizeBits,
      nonce,
      Uint8List(0),
    );
    ccm.init(true, params);

    final out = Uint8List(ccm.getOutputSize(plaintext.length));
    final outBytes = ccm.processBytes(plaintext, 0, plaintext.length, out, 0);
    ccm.doFinal(out, outBytes);
    return out;
  }

  // AES-CCM Decrypt
  static Uint8List decryptCcm(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List nonce, {
    int macSizeBits = 32,
  }) {
    final aesEngine = pc.AESEngine();
    final ccm = pc.CCMBlockCipher(aesEngine);
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      macSizeBits,
      nonce,
      Uint8List(0),
    );
    ccm.init(false, params);

    final out = Uint8List(ccm.getOutputSize(ciphertext.length));
    final outBytes = ccm.processBytes(ciphertext, 0, ciphertext.length, out, 0);
    ccm.doFinal(out, outBytes);
    return out;
  }
}
