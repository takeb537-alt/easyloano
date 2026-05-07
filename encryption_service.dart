// ============================================
// EasyLoan - EncryptionService
// AES-256 encryption for sensitive data
// Uses dart-define for key injection
// ============================================

import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Keys injected via --dart-define at build time
  // NEVER hardcode keys here
  static const String _keyFromEnv =
      String.fromEnvironment('ENCRYPTION_KEY', defaultValue: '');
  static const String _ivFromEnv =
      String.fromEnvironment('ENCRYPTION_IV', defaultValue: '');

  late final enc.Key _key;
  late final enc.IV _iv;
  late final enc.Encrypter _encrypter;

  bool _initialized = false;

  void _initialize() {
    if (_initialized) return;

    // Use env key or fallback (for dev only - never in prod!)
    final keyStr = _keyFromEnv.isNotEmpty
        ? _keyFromEnv.padRight(32, '0').substring(0, 32)
        : 'EasyLoanDefaultKey12345678901234'; // Dev only!

    final ivStr = _ivFromEnv.isNotEmpty
        ? _ivFromEnv.padRight(16, '0').substring(0, 16)
        : 'EasyLoanIV123456'; // Dev only!

    _key = enc.Key.fromUtf8(keyStr);
    _iv = enc.IV.fromUtf8(ivStr);
    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    _initialized = true;
  }

  /// Encrypt a string using AES-256-CBC
  String encrypt(String plainText) {
    _initialize();
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypt an AES-256-CBC encrypted string
  String decrypt(String encryptedText) {
    _initialize();
    final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }

  /// Create SHA-256 hash for uniqueness checks (one-way)
  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a partial mask of Aadhaar for display
  String maskAadhaar(String aadhaar) {
    if (aadhaar.length < 4) return '****';
    return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
  }

  /// Create a partial mask of PAN for display
  String maskPAN(String pan) {
    if (pan.length < 4) return '***';
    return '${pan.substring(0, 2)}XXXXXXX${pan.substring(pan.length - 1)}';
  }
}