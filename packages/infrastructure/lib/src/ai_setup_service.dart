// P06 T7 (ADR-0087): the assistant's settings of one profile, kept in the
// device's encrypted registry (like the other device settings), and the
// cloud model's choice. Keys stay in secure storage (AiKeyStore).
import 'dart:convert';

import 'package:application/application.dart';

import 'ai_assistant_service.dart' show aiAssistantSettingsJson, aiAssistantSettingsOf;

class DeviceAiSetup implements AiSetupService {
  DeviceAiSetup({
    required this.profileId,
    required this.read,
    required this.write,
    required this.keys,
    required this.ledger,
    required this.catalog,
    required this.models,
    required this.platform,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String profileId;

  /// The registry's settings (ProfileDirectory.readSetting / writeSetting).
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final AiKeyStore keys;
  final AiUsageLedger ledger;
  final CloudModelCatalog catalog;
  @override
  final LocalModelService models;
  @override
  final LocalPlatform platform;
  final DateTime Function() _now;

  String get _settingsKey => 'ai.$profileId.settings';
  String get _cloudKey => 'ai.$profileId.cloud';

  @override
  Future<AiAssistantSettings> settings() async => aiAssistantSettingsOf(await read(_settingsKey));

  @override
  Future<void> setSettings(AiAssistantSettings s) => write(_settingsKey, aiAssistantSettingsJson(s));

  @override
  Future<CloudAiConfig?> cloud() async {
    final raw = await read(_cloudKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final p = CloudProvider.values.where((p) => p.name == j['provider']).firstOrNull;
      final model = j['model'];
      if (p == null || model is! String || model.trim().isEmpty) return null;
      final cap = j['cap'];
      return CloudAiConfig(
        provider: p,
        model: model.trim(),
        baseUrl: j['baseUrl'] is String && (j['baseUrl'] as String).trim().isNotEmpty ? (j['baseUrl'] as String).trim() : null,
        monthlyTokenCap: cap is int && cap > 0 ? cap : null,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> setCloud(CloudAiConfig? c) => write(
      _cloudKey,
      c == null
          ? ''
          : jsonEncode({
              'provider': c.provider.name,
              'model': c.model.trim(),
              if (c.baseUrl != null) 'baseUrl': c.baseUrl!.trim(),
              if (c.monthlyTokenCap != null) 'cap': c.monthlyTokenCap,
            }));

  @override
  Future<bool> hasKey(CloudProvider provider) async => (await keys.read(provider))?.trim().isNotEmpty ?? false;

  @override
  Future<void> setKey(CloudProvider provider, String? key) async {
    if (key == null || key.trim().isEmpty) return keys.delete(provider);
    return keys.write(provider, key.trim());
  }

  @override
  Future<List<String>> cloudModels(CloudProvider provider, {String? baseUrl}) => catalog.models(provider, baseUrl: baseUrl);

  @override
  Future<int> tokensThisMonth() => ledger.usedInMonthOf(_now());
}
