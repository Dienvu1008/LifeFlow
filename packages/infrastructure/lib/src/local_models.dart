// P06 T4 (ADR-0083; D4 after spike S-17): the models kept on this device.
//   list      pinned per platform: name, size, license (read in the model's
//             own files), SHA-256 (from the host's LFS record). Windows: Qwen
//             3.5 2 B (the default), 4 B, 0.8 B. Android: 0.8 B only, marked
//             slow and not recommended (the owner's call after S-17)
//   download  over HTTPS only, into `<file>.part`; a stopped one resumes with
//             a range request; the whole file's size and SHA-256 are checked
//             before it is kept, else it is deleted
//   own file  "Use a model file": a GGUF file (checked by its magic), copied
//             into the folder and hashed; one of the list is known by hash
//   index     `models.json` in the folder: what is installed and which one
//             the assistant uses. Device data, not a profile's: never synced
//             nor exported
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const _qwenLicense = 'Apache-2.0';

/// The pinned list (D4). Sizes and hashes: Hugging Face's LFS records of
/// `unsloth/Qwen3.5-*-GGUF` (2026-11-04); license: Apache-2.0 in the GGUF
/// repositories and in `Qwen/Qwen3.5-*` (its LICENSE file).
const localModelCatalog = <LocalModelInfo>[
  LocalModelInfo(
    id: 'qwen3.5-2b-q4km',
    name: 'Qwen 3.5 2B',
    fileName: 'Qwen3.5-2B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-Q4_K_M.gguf',
    sizeBytes: 1280835840,
    sha256: 'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
    license: _qwenLicense,
    licenseUrl: 'https://huggingface.co/Qwen/Qwen3.5-2B/blob/main/LICENSE',
    platforms: {LocalPlatform.windows},
    recommendedOn: {LocalPlatform.windows},
    memoryGb: 1.4,
  ),
  LocalModelInfo(
    id: 'qwen3.5-4b-q4km',
    name: 'Qwen 3.5 4B',
    fileName: 'Qwen3.5-4B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/Qwen3.5-4B-Q4_K_M.gguf',
    sizeBytes: 2740937888,
    sha256: '00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4',
    license: _qwenLicense,
    licenseUrl: 'https://huggingface.co/Qwen/Qwen3.5-4B/blob/main/LICENSE',
    platforms: {LocalPlatform.windows},
    memoryGb: 2.8,
  ),
  LocalModelInfo(
    id: 'qwen3.5-0.8b-q4km',
    name: 'Qwen 3.5 0.8B',
    fileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/6ab461498e2023f6e3c1baea90a8f0fe38ab64d0/Qwen3.5-0.8B-Q4_K_M.gguf',
    sizeBytes: 532517120,
    sha256: 'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517',
    license: _qwenLicense,
    licenseUrl: 'https://huggingface.co/Qwen/Qwen3.5-0.8B/blob/main/LICENSE',
    platforms: {LocalPlatform.windows, LocalPlatform.android},
    slowOn: {LocalPlatform.android},
    memoryGb: 0.8,
  ),
];

/// The first bytes of every GGUF file.
const _ggufMagic = [0x47, 0x47, 0x55, 0x46]; // "GGUF"

bool _loopback(Uri u) => u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1';

class FileLocalModelService implements LocalModelService {
  FileLocalModelService(this.folder,
      {required this.platform, http.Client? client, List<LocalModelInfo> list = localModelCatalog})
      : _client = client ?? http.Client(),
        _list = list;

  /// The app's own folder for models (not a profile's).
  final Directory folder;
  final LocalPlatform platform;
  final http.Client _client;
  final List<LocalModelInfo> _list;
  final _busy = <String>{};

  File get _index => File('${folder.path}${Platform.pathSeparator}models.json');
  String _path(String file) => '${folder.path}${Platform.pathSeparator}$file';

  Future<Map<String, Object?>> _read() async {
    if (!await _index.exists()) return {'selected': null, 'models': <Object?>[]};
    try {
      return (jsonDecode(await _index.readAsString()) as Map).cast<String, Object?>();
    } on FormatException {
      return {'selected': null, 'models': <Object?>[]};
    }
  }

  Future<void> _write(Map<String, Object?> index) async {
    await folder.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(jsonEncode(index), flush: true);
    await tmp.rename(_index.path);
  }

  InstalledModel _model(Map m) => InstalledModel(
        id: m['id'] as String,
        name: m['name'] as String,
        path: _path(m['file'] as String),
        sizeBytes: m['sizeBytes'] as int,
        sha256: m['sha256'] as String,
        license: m['license'] as String?,
        fromFile: m['fromFile'] == true,
      );

  Future<InstalledModel> _keep(Map<String, Object?> entry) async {
    final index = await _read();
    final models = [
      for (final m in (index['models'] as List).cast<Map>())
        if (m['id'] != entry['id']) m,
      entry,
    ];
    await _write({...index, 'models': models});
    return _model(entry);
  }

  @override
  List<LocalModelInfo> catalog() => [for (final m in _list) if (m.platforms.contains(platform)) m];

  @override
  Future<List<InstalledModel>> installed() async => [
        for (final m in ((await _read())['models'] as List).cast<Map>())
          if (File(_path(m['file'] as String)).existsSync()) _model(m),
      ];

  @override
  Future<InstalledModel> download(String id,
      {void Function(int received, int total)? onProgress, AiCancel? cancel}) async {
    final info = catalog().where((m) => m.id == id).firstOrNull;
    if (info == null) throw LocalModelFailure(LocalModelFailureKind.unknownModel, id);
    final uri = Uri.parse(info.url);
    if (uri.scheme != 'https' && !_loopback(uri)) throw LocalModelFailure(LocalModelFailureKind.insecureUrl, info.url);
    if (!_busy.add(id)) throw LocalModelFailure(LocalModelFailureKind.busy, id);
    try {
      await folder.create(recursive: true);
      final part = File(_path('${info.fileName}.part'));
      var have = await part.exists() ? await part.length() : 0;
      if (have > info.sizeBytes) {
        await part.delete();
        have = 0;
      }
      if (have < info.sizeBytes) {
        final req = http.Request('GET', uri);
        if (have > 0) req.headers['range'] = 'bytes=$have-';
        final http.StreamedResponse res;
        try {
          res = await _client.send(req);
        } on Object catch (e) {
          throw LocalModelFailure(LocalModelFailureKind.network, '$e');
        }
        if (res.statusCode == 200) {
          have = 0; // the server sends the whole file
        } else if (res.statusCode != 206 || !(res.headers['content-range'] ?? '').startsWith('bytes $have-')) {
          await res.stream.drain<void>();
          throw LocalModelFailure(LocalModelFailureKind.network, 'HTTP ${res.statusCode}');
        }
        final out = await part.open(mode: have == 0 ? FileMode.write : FileMode.append);
        try {
          await for (final chunk in res.stream) {
            if (cancel?.isCancelled ?? false) {
              throw const LocalModelFailure(LocalModelFailureKind.cancelled);
            }
            have += chunk.length;
            if (have > info.sizeBytes) break;
            await out.writeFrom(chunk);
            onProgress?.call(have, info.sizeBytes);
          }
        } on LocalModelFailure {
          rethrow;
        } on Object catch (e) {
          throw LocalModelFailure(LocalModelFailureKind.network, '$e');
        } finally {
          await out.close();
        }
      }
      // The whole file, checked: its size and its hash.
      final size = await part.length();
      final digest = size == info.sizeBytes ? (await sha256.bind(part.openRead()).first).toString() : '';
      if (digest != info.sha256) {
        await part.delete();
        throw LocalModelFailure(LocalModelFailureKind.hashMismatch, 'size $size');
      }
      await part.rename(_path(info.fileName));
      return await _keep({
        'id': info.id,
        'name': info.name,
        'file': info.fileName,
        'sizeBytes': info.sizeBytes,
        'sha256': info.sha256,
        'license': info.license,
        'fromFile': false,
      });
    } finally {
      _busy.remove(id);
    }
  }

  @override
  Future<InstalledModel> importFile(String path, {AiCancel? cancel}) async {
    final src = File(path);
    final head = <int>[];
    try {
      await for (final b in src.openRead(0, 4)) {
        head.addAll(b);
      }
    } on FileSystemException catch (e) {
      throw LocalModelFailure(LocalModelFailureKind.notGguf, e.message);
    }
    if (head.length < 4 || [for (var i = 0; i < 4; i++) head[i] == _ggufMagic[i]].contains(false)) {
      throw const LocalModelFailure(LocalModelFailureKind.notGguf);
    }
    await folder.create(recursive: true);
    final tmp = File(_path('import-${DateTime.now().microsecondsSinceEpoch}.part'));
    final out = await tmp.open(mode: FileMode.write);
    final hashOut = _DigestSink();
    final hash = sha256.startChunkedConversion(hashOut);
    var size = 0;
    try {
      await for (final chunk in src.openRead()) {
        if (cancel?.isCancelled ?? false) throw const LocalModelFailure(LocalModelFailureKind.cancelled);
        hash.add(chunk);
        size += chunk.length;
        await out.writeFrom(chunk);
      }
    } on Object {
      await out.close();
      await tmp.delete();
      rethrow;
    }
    await out.close();
    hash.close();
    final digest = hashOut.value.toString();
    // One of the list, by its hash: known name and license.
    final known = _list.where((m) => m.sha256 == digest && m.sizeBytes == size).firstOrNull;
    final name = src.uri.pathSegments.last;
    final file = known?.fileName ?? 'own-${digest.substring(0, 16)}.gguf';
    final dest = File(_path(file));
    if (await dest.exists()) await dest.delete();
    await tmp.rename(dest.path);
    return _keep({
      'id': known?.id ?? 'file-${digest.substring(0, 16)}',
      'name': known?.name ?? name,
      'file': file,
      'sizeBytes': size,
      'sha256': digest,
      'license': known?.license,
      'fromFile': known == null,
    });
  }

  @override
  Future<void> delete(String id) async {
    final index = await _read();
    final models = (index['models'] as List).cast<Map>();
    for (final m in models.where((m) => m['id'] == id)) {
      final f = File(_path(m['file'] as String));
      if (await f.exists()) await f.delete();
    }
    await _write({
      'selected': index['selected'] == id ? null : index['selected'],
      'models': [for (final m in models) if (m['id'] != id) m],
    });
  }

  @override
  Future<InstalledModel?> selected() async {
    final id = (await _read())['selected'];
    return (await installed()).where((m) => m.id == id).firstOrNull;
  }

  @override
  Future<void> select(String? id) async {
    if (id != null && !(await installed()).any((m) => m.id == id)) {
      throw LocalModelFailure(LocalModelFailureKind.unknownModel, id);
    }
    await _write({...await _read(), 'selected': id});
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
