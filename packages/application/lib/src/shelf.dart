// P06b W6 (ADR-0094): the Archive and the Trash of lists, tasks, events and
// documents. An archived item is put away, not deleted: it leaves the
// screens (and, by a setting, the Calendar and the Timeline) and comes back
// with Unarchive. A trashed item can be restored, or deleted for good by the
// person, by "Empty trash", or by the trash's retention (a setting).
import 'package:foundation/foundation.dart';

import 'command.dart';

/// The kinds that can be archived and trashed.
enum ShelfKind { list, task, event, document }

/// One thing in the Archive or the Trash, as listed. What went with it (a
/// list's tasks and events, a task's subtasks, a document's subdocuments)
/// is not listed on its own: it comes back, or goes, with it.
class ShelfEntry {
  const ShelfEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.at,
    this.contents = 0,
    this.place,
  });
  final ShelfKind kind;
  final String id;
  final String title;

  /// When it was archived, or put in the trash.
  final DateTime at;

  /// How many things went with it.
  final int contents;

  /// Where it was: the list's name, for a task or an event in a list.
  final String? place;
}

abstract interface class ShelfQueries {
  /// What is archived in the shown space, the newest first.
  Future<List<ShelfEntry>> archived();

  /// What is in the trash of the shown space (not what was deleted for
  /// good), the newest first.
  Future<List<ShelfEntry>> trashed();
}

abstract interface class ShelfService {
  /// Puts away [id] and what is in it.
  Future<CommandResult> archive(ShelfKind kind, String id);

  /// Brings back [id] and what went away with it.
  Future<CommandResult> unarchive(ShelfKind kind, String id);

  /// Takes [id] out of the trash, with what went to the trash with it.
  Future<CommandResult> restore(ShelfKind kind, String id);

  /// Deletes [id] (in the trash) for good, with what went with it: what it
  /// held is gone from this device and, by sync, from the person's others.
  Future<CommandResult> purge(ShelfKind kind, String id);

  /// Deletes for good everything in the trash; how many were.
  Future<int> emptyTrash();

  /// Deletes for good what has been in the trash [days] days or more (zero
  /// or less: nothing); how many were.
  Future<int> purgeOlderThan(int days, {Instant? now});
}

/// The days a trashed item is kept before it is deleted for good, when the
/// person has not chosen.
const defaultTrashRetentionDays = 30;

/// The retention the person can choose, in days; 0 keeps the trash until it
/// is emptied.
const trashRetentionChoices = [0, 7, 14, 30, 60, 90, 180, 365];
