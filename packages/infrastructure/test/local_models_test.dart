// P06 T4 (ADR-0083; D4): the models of this device, against a local HTTP
// server.
//   list      per platform: Windows 2 B (default), 4 B, 0.8 B; Android only
//             0.8 B, marked slow; every entry pinned (HTTPS, size, hash,
//             license)
//   download  checked by size and SHA-256 before it is kept; progress; a
//             stopped download resumes with a range request; a server that
//             ignores the range starts again; a wrong file is deleted; only
//             HTTPS (a loopback address for tests)
//   own file  only GGUF; copied and hashed; a file of the list is known by
//             its hash
//   index     choose, delete (the choice goes with it), survive a restart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:crypto/crypto.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

class _Server {
  _Server(this.bytes);
  final Uint8List bytes;
  late HttpServer http;
  final ranges = <String?>[];
  bool honorRange = true;

  /// Stop answering after this many bytes of a response (a dropped line).
  int? cutAfter;

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((req) async {
      final range = req.headers.value('range');
      ranges.add(range);
      var start = 0;
      if (range != null && honorRange) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        req.response.statusCode = 206;
        req.response.headers.set('content-range', 'bytes $start-${bytes.length - 1}/${bytes.length}');
      }
      final body = bytes.sublist(start);
      req.response.contentLength = body.length;
      if (cutAfter != null && cutAfter! < body.length) {
        final s = await req.response.detachSocket(writeHeaders: true);
        s.add(body.sublist(0, cutAfter));
        await s.flush();
        s.destroy();
        return;
      }
      req.response.add(body);
      await req.response.close();
    });
  }

  String get url => 'http://127.0.0.1:${http.port}/model.gguf';
}

void main() {
  late Directory dir;
  late Uint8List bytes;
  late _Server server;
  late FileLocalModelService svc;

  LocalModelInfo info({String? sha, String? url, int? size}) => LocalModelInfo(
        id: 'tiny',
        name: 'Tiny',
        fileName: 'tiny.gguf',
        url: url ?? server.url,
        sizeBytes: size ?? bytes.length,
        sha256: sha ?? sha256.convert(bytes).toString(),
        license: 'Apache-2.0',
        licenseUrl: 'https://example.org/LICENSE',
        platforms: const {LocalPlatform.windows},
      );

  FileLocalModelService service(List<LocalModelInfo> list) =>
      FileLocalModelService(Directory('${dir.path}/models'), platform: LocalPlatform.windows, list: list);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lifeflow_models_');
    final r = Random(7);
    bytes = Uint8List.fromList([0x47, 0x47, 0x55, 0x46, for (var i = 0; i < 300000; i++) r.nextInt(256)]);
    server = _Server(bytes);
    await server.start();
    svc = service([info()]);
  });
  tearDown(() async {
    await server.http.close(force: true);
    dir.deleteSync(recursive: true);
  });

  group('the list', () {
    test('Windows: 2B (the default), 4B, 0.8B; Android: only 0.8B, marked slow', () {
      List<LocalModelInfo> on(LocalPlatform p) => FileLocalModelService(dir, platform: p).catalog();
      final win = on(LocalPlatform.windows);
      expect([for (final m in win) m.id], ['qwen3.5-2b-q4km', 'qwen3.5-4b-q4km', 'qwen3.5-0.8b-q4km']);
      expect([for (final m in win) if (m.recommendedOn.contains(LocalPlatform.windows)) m.id], ['qwen3.5-2b-q4km']);
      expect(win.any((m) => m.slowOn.contains(LocalPlatform.windows)), isFalse);
      final android = on(LocalPlatform.android);
      expect([for (final m in android) m.id], ['qwen3.5-0.8b-q4km']);
      expect(android.single.slowOn, contains(LocalPlatform.android));
      expect(android.single.recommendedOn, isEmpty);
    });

    test('every entry is pinned: HTTPS at a fixed revision, a size, a SHA-256, a license read in its files', () {
      for (final m in localModelCatalog) {
        final u = Uri.parse(m.url);
        expect(u.scheme, 'https', reason: m.id);
        expect(u.path, matches(RegExp(r'/resolve/[0-9a-f]{40}/')), reason: '${m.id}: a commit, not a branch');
        expect(u.pathSegments.last, m.fileName, reason: m.id);
        expect(m.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: m.id);
        expect(m.sizeBytes, greaterThan(100 << 20), reason: m.id);
        expect(m.license, 'Apache-2.0', reason: m.id);
        expect(Uri.parse(m.licenseUrl).scheme, 'https', reason: m.id);
      }
      expect({for (final m in localModelCatalog) m.id}, hasLength(localModelCatalog.length));
    });
  });

  group('download', () {
    test('kept only after its size and SHA-256 are checked; progress to the end', () async {
      final seen = <int>[];
      final m = await svc.download('tiny', onProgress: (got, total) {
        expect(total, bytes.length);
        seen.add(got);
      });
      expect(await File(m.path).readAsBytes(), bytes);
      expect(m.sha256, sha256.convert(bytes).toString());
      expect(seen.last, bytes.length);
      expect((await svc.installed()).single.id, 'tiny');
      expect(File('${m.path}.part').existsSync(), isFalse);
    });

    test('a stopped download resumes with a range request', () async {
      final cancel = AiCancel();
      await expectLater(
          svc.download('tiny', cancel: cancel, onProgress: (got, _) {
            if (got > 100000) cancel.cancel();
          }),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.cancelled)));
      final part = File('${dir.path}/models/tiny.gguf.part');
      final kept = part.lengthSync();
      expect(kept, inExclusiveRange(100000, bytes.length));
      expect(await svc.installed(), isEmpty);

      final m = await svc.download('tiny');
      expect(server.ranges.last, 'bytes=$kept-');
      expect(await File(m.path).readAsBytes(), bytes);
    });

    test('a dropped line keeps what came; the next try resumes', () async {
      server.cutAfter = 120000;
      await expectLater(svc.download('tiny'), throwsA(isA<LocalModelFailure>()));
      server.cutAfter = null;
      final m = await svc.download('tiny');
      expect(server.ranges.last, startsWith('bytes='));
      expect(await File(m.path).readAsBytes(), bytes);
    });

    test('a server that ignores the range sends the whole file: it starts again', () async {
      final cancel = AiCancel();
      await expectLater(
          svc.download('tiny', cancel: cancel, onProgress: (got, _) {
            if (got > 50000) cancel.cancel();
          }),
          throwsA(isA<LocalModelFailure>()));
      server.honorRange = false;
      final m = await svc.download('tiny');
      expect(await File(m.path).readAsBytes(), bytes);
    });

    test('a part longer than the model (left by another version) starts again', () async {
      Directory('${dir.path}/models').createSync(recursive: true);
      File('${dir.path}/models/tiny.gguf.part').writeAsBytesSync(List.filled(bytes.length + 5, 1));
      final m = await svc.download('tiny');
      expect(server.ranges.last, isNull, reason: 'the whole file was asked for');
      expect(await File(m.path).readAsBytes(), bytes);
    });

    test('a file that is not the pinned one is deleted, not kept', () async {
      final wrong = service([info(sha: 'a' * 64)]);
      await expectLater(wrong.download('tiny'),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.hashMismatch)));
      expect(await wrong.installed(), isEmpty);
      expect(Directory('${dir.path}/models').listSync().whereType<File>().where((f) => f.path.endsWith('.gguf')), isEmpty);
      expect(File('${dir.path}/models/tiny.gguf.part').existsSync(), isFalse);

      final short = service([info(size: bytes.length + 10)]);
      await expectLater(short.download('tiny'),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.hashMismatch)));
    });

    test('only HTTPS (and loopback for tests); only a model of the list', () async {
      final plain = service([info(url: 'http://example.org/model.gguf')]);
      await expectLater(plain.download('tiny'),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.insecureUrl)));
      await expectLater(svc.download('nope'),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.unknownModel)));
      expect(server.ranges, isEmpty, reason: 'nothing was asked');
    });

    test('one download of a model at a time', () async {
      final a = svc.download('tiny');
      await expectLater(svc.download('tiny'),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.busy)));
      await a;
    });
  });

  group('the person\'s own file', () {
    test('only GGUF; copied into the folder and hashed', () async {
      final own = File('${dir.path}/Mine 7B.gguf')..writeAsBytesSync(bytes);
      final m = await service(const []).importFile(own.path);
      expect(m.fromFile, isTrue);
      expect(m.name, 'Mine 7B.gguf');
      expect(m.license, isNull, reason: 'unknown: the person\'s own file');
      expect(m.sha256, sha256.convert(bytes).toString());
      expect(File(m.path).parent.path, Directory('${dir.path}/models').path);
      expect(await File(m.path).readAsBytes(), bytes);

      final text = File('${dir.path}/notes.gguf')..writeAsStringSync('not a model');
      await expectLater(service(const []).importFile(text.path),
          throwsA(isA<LocalModelFailure>().having((e) => e.kind, 'kind', LocalModelFailureKind.notGguf)));
      await expectLater(service(const []).importFile('${dir.path}/missing.gguf'), throwsA(isA<LocalModelFailure>()));
    });

    test('a file of the list is known by its hash: its name and license', () async {
      final own = File('${dir.path}/downloaded-elsewhere.gguf')..writeAsBytesSync(bytes);
      final m = await svc.importFile(own.path);
      expect((m.id, m.name, m.license, m.fromFile), ('tiny', 'Tiny', 'Apache-2.0', false));
    });
  });

  group('the index', () {
    test('choose, delete (the choice goes with it), and it survives a restart', () async {
      final m = await svc.download('tiny');
      expect(await svc.selected(), isNull);
      await svc.select('tiny');
      expect((await service([info()]).selected())?.id, 'tiny', reason: 'a new service reads the same folder');
      await expectLater(svc.select('nope'), throwsA(isA<LocalModelFailure>()));
      await svc.delete('tiny');
      expect(File(m.path).existsSync(), isFalse);
      expect(await svc.installed(), isEmpty);
      expect(await svc.selected(), isNull);
      await svc.download('tiny');
      expect(await svc.selected(), isNull, reason: 'downloaded again, not chosen again by itself');
    });

    test('a file removed by hand is not listed; a broken index is an empty one', () async {
      final m = await svc.download('tiny');
      File(m.path).deleteSync();
      expect(await svc.installed(), isEmpty);
      File('${dir.path}/models/models.json').writeAsStringSync('{broken');
      expect(await svc.installed(), isEmpty);
      expect(await svc.selected(), isNull);
    });
  });
}
