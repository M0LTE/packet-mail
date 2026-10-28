import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Connection passwords, kept out of the database, keyed by connection id.
abstract interface class PasswordStore {
  Future<String?> read(int connectionId);
  Future<void> write(int connectionId, String password);
  Future<void> delete(int connectionId);
}

/// The phone's keychain or keystore.
class SecurePasswordStore implements PasswordStore {
  const SecurePasswordStore();

  static const _storage = FlutterSecureStorage();

  static String _key(int connectionId) => 'connection.$connectionId.password';

  @override
  Future<String?> read(int connectionId) => _storage.read(key: _key(connectionId));

  @override
  Future<void> write(int connectionId, String password) => _storage.write(key: _key(connectionId), value: password);

  @override
  Future<void> delete(int connectionId) => _storage.delete(key: _key(connectionId));
}

/// For tests.
class MemoryPasswordStore implements PasswordStore {
  final passwords = <int, String>{};

  /// When set, reads or writes throw this, as a locked keychain might.
  Exception? readFailure;
  Exception? writeFailure;

  @override
  Future<String?> read(int connectionId) async {
    if (readFailure case final e?) throw e;
    return passwords[connectionId];
  }

  @override
  Future<void> write(int connectionId, String password) async {
    if (writeFailure case final e?) throw e;
    passwords[connectionId] = password;
  }

  @override
  Future<void> delete(int connectionId) async => passwords.remove(connectionId);
}
