import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:infrastructure/infrastructure.dart';

/// One named key in platform secure storage (Android: Keystore-backed;
/// Windows: flutter_secure_storage_windows 4.x keeps a DPAPI-protected file,
/// `flutter_secure_storage.dat`, bound to the current Windows user). Never the
/// DB, plain files or logs (LF-INV-SEC-001, SR-02).
/// Since SR-03 every profile store and the registry have their own key
/// (see ProfileDirectory for the names).
class SecureDatabaseKeyStore implements DatabaseKeyStore {
  const SecureDatabaseKeyStore(this.name,
      [this._storage = const FlutterSecureStorage()]);

  final String name;
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: name);

  @override
  Future<void> write(String key) => _storage.write(key: name, value: key);
}

/// Key slots for [ProfileDirectory.open].
DatabaseKeyStore secureKeyStoreFor(String name) => SecureDatabaseKeyStore(name);
