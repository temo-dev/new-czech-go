import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around FlutterSecureStorage.
/// Use for tokens, refresh keys, and other sensitive data.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}

abstract final class SecureStorageKeys {
  static const onboardingComplete = 'onboarding_complete';
}
