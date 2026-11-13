// P03 UX U2 (ADR-0046): lists, colours and order for the Overview (U3), as
// the UI sees them. `foundation` types only (FF-ARCH-04).
//
// Containers: the lists; the top-level items in no list (tasks and events);
// the top-level items of a list; the subtasks of a task. Items show by
// [orderKey], then id. An event is in a list or in none, never under a task
// (U-D1). Colours are indexes into the theme's 12-colour palette (U-D4).
import 'command.dart';
import 'planning.dart';

class TaskListView {
  const TaskListView({required this.id, required this.title, this.colorIndex, required this.orderKey});
  final String id;
  final String title;

  /// 0..11, or null for no colour.
  final int? colorIndex;
  final String orderKey;
}

/// An event as the Overview shows it.
class OverviewEventView {
  const OverviewEventView({
    required this.id,
    required this.title,
    this.listId,
    this.colorIndex,
    required this.orderKey,
    this.isCancelled = false,
    this.schedule,
  });
  final String id;
  final String title;

  /// A live list, or null (in no list).
  final String? listId;
  final int? colorIndex;
  final String orderKey;
  final bool isCancelled;

  /// Its start, end and repeat (an event always has a start).
  final TaskScheduleInput? schedule;
}

/// Where a task or an event is dropped: at the top level of a list (or of
/// no list), or under a task (tasks only). [afterId] is the item it lands
/// right after in that place; null = first.
class ItemPlace {
  const ItemPlace.loose({this.afterId})
      : listId = null,
        parentId = null;
  const ItemPlace.inList(String this.listId, {this.afterId}) : parentId = null;
  const ItemPlace.under(String this.parentId, {this.afterId}) : listId = null;

  final String? listId;
  final String? parentId;
  final String? afterId;
}

/// Read side: the ACTIVE profile's lists and events (trash excluded).
abstract interface class OverviewQueries {
  /// The live lists, in order.
  Stream<List<TaskListView>> watchLists();

  /// The live events with their list, colour and order key, in order.
  Stream<List<OverviewEventView>> watchEvents();
}

/// Write side: one command per change, through the gateway (ADR-0011). A
/// drop is one command and rewrites one row (R-DATA-LOSS).
abstract interface class OverviewService {
  Future<CommandResult> createList(String title, {int? colorIndex});
  Future<CommandResult> renameList(String listId, String title);
  Future<CommandResult> setListColor(String listId, int? colorIndex);

  /// [afterId] = the list it lands after; null = first.
  Future<CommandResult> moveList(String listId, {String? afterId});

  /// The list, its tasks (with their subtasks) and its events go to the
  /// trash together; [restoreList] brings back the same set.
  Future<CommandResult> trashList(String listId);
  Future<CommandResult> restoreList(String listId);

  /// Refused: a cycle, more than 4 levels (the moved subtasks count), an
  /// unknown list or parent, a position that is out of date.
  Future<CommandResult> moveTask(String taskId, ItemPlace place);

  /// Refused under a task (U-D1).
  Future<CommandResult> moveEvent(String eventId, ItemPlace place);
  Future<CommandResult> setTaskColor(String taskId, int? colorIndex);
  Future<CommandResult> setEventColor(String eventId, int? colorIndex);
}
