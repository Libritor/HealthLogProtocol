import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for raw wearable data files.
///
// TODO: Replace with production KMS, user-controlled keys, or
// wallet-derived encryption before any production deployment.
class EncryptionService {
  static const _keyStorageKey = 'healthlog_encryption_key';
  static const _keyLength = 32; // AES-256
  static const _ivLength = 12; // GCM recommended IV

  final FlutterSecureStorage _secureStorage;

  EncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<enc.Key> _getOrCreateKey() async {
    final stored = await _secureStorage.read(key: _keyStorageKey);
    if (stored != null) {
      return enc.Key.fromBase64(stored);
    }
    final key = enc.Key.fromSecureRandom(_keyLength);
    await _secureStorage.write(key: _keyStorageKey, value: key.base64);
    return key;
  }

  /// Encrypt a file. Returns the path to the encrypted output.
  Future<EncryptedFileResult> encryptFile(File rawFile) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final plainBytes = await rawFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final outPath = '${rawFile.path}.enc';
    final outFile = File(outPath);

    // Store IV (12 bytes) prepended to ciphertext
    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);
    await outFile.writeAsBytes(combined);

    return EncryptedFileResult(
      encryptedFile: outFile,
      originalPath: rawFile.path,
    );
  }

  /// Decrypt a file previously encrypted with [encryptFile].
  Future<File> decryptFile(File encryptedFile, {String? outputPath}) async {
    final key = await _getOrCreateKey();
    final combined = await encryptedFile.readAsBytes();

    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, _ivLength)));
    final cipherBytes = combined.sublist(_ivLength);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(cipherBytes)),
      iv: iv,
    );

    final outPath = outputPath ??
        encryptedFile.path.replaceAll('.enc', '.dec');
    final outFile = File(outPath);
    await outFile.writeAsBytes(decrypted);
    return outFile;
  }
}

class EncryptedFileResult {
  final File encryptedFile;
  final String originalPath;
  const EncryptedFileResult({
    required this.encryptedFile,
    required this.originalPath,
  });
}
