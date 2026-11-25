// P06 T5 (ADR-0085; LF-INV-SEC-001): the person's API keys in the
// platform's secure storage (Android Keystore; Windows DPAPI, bound to the
// Windows user), one slot per profile and provider: another profile on the
// same device never uses them. Never the store, an export, a sync or a log.
import 'package:application/application.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAiKeyStore implements AiKeyStore {
  const SecureAiKeyStore(this.profileId, [this._storage = const FlutterSecureStorage()]);
  final String profileId;
  final FlutterSecureStorage _storage;

  String _name(CloudProvider p) => 'ai.key.$profileId.${p.name}';

  @override
  Future<String?> read(CloudProvider provider) => _storage.read(key: _name(provider));

  @override
  Future<void> write(CloudProvider provider, String key) => _storage.write(key: _name(provider), value: key.trim());

  @override
  Future<void> delete(CloudProvider provider) => _storage.delete(key: _name(provider));
}
