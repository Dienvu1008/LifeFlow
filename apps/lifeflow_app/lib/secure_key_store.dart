import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:infrastructure/infrastructure.dart';

/// The database key in platform secure storage (Android Keystore-backed;
/// Windows Credential Manager). Never the DB, files or logs (LF-INV-SEC-001,
/// SR-02). One key for the local store (single-file layout, see T6b notes).
class SecureDatabaseKeyStore implements DatabaseKeyStore {
  const SecureDatabaseKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _name = 'lifeflow.db.key.v1';

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);
}
