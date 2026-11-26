// P06b W6: the Archive and the Trash, faked. Calls are recorded in [calls].
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

class FakeShelf implements ShelfService, ShelfQueries {
  FakeShelf(this.calls);
  final List<String> calls;
  final archivedList = <ShelfEntry>[];
  final trashedList = <ShelfEntry>[];
  CommandResult? failure;

  CommandResult _ok(String id) => failure ?? CommandOk(id, const Version(2), const []);

  @override
  Future<List<ShelfEntry>> archived() async => [...archivedList];
  @override
  Future<List<ShelfEntry>> trashed() async => [...trashedList];

  @override
  Future<CommandResult> archive(ShelfKind kind, String id) async {
    calls.add('shelf.archive:${kind.name}:$id');
    return _ok(id);
  }

  @override
  Future<CommandResult> unarchive(ShelfKind kind, String id) async {
    calls.add('shelf.unarchive:${kind.name}:$id');
    archivedList.removeWhere((e) => e.id == id);
    return _ok(id);
  }

  @override
  Future<CommandResult> restore(ShelfKind kind, String id) async {
    calls.add('shelf.restore:${kind.name}:$id');
    trashedList.removeWhere((e) => e.id == id);
    return _ok(id);
  }

  @override
  Future<CommandResult> purge(ShelfKind kind, String id) async {
    calls.add('shelf.purge:${kind.name}:$id');
    trashedList.removeWhere((e) => e.id == id);
    return _ok(id);
  }

  @override
  Future<int> emptyTrash() async {
    calls.add('shelf.empty');
    final n = trashedList.length;
    trashedList.clear();
    return n;
  }

  @override
  Future<int> purgeOlderThan(int days, {Instant? now}) async {
    calls.add('shelf.expire:$days');
    return 0;
  }
}
