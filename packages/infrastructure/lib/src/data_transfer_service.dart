// P01 T7/T7b: export / restore for the UI (UC-20a, ADR-0025).
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'account_service.dart' show profileViewOf;
import 'app_database.dart';
import 'app_service_impl.dart' show WorkspaceOwnerAuthorization;
import 'command_gateway.dart';
import 'local_store.dart' show StoreUnavailable;
import 'profile_directory.dart';
import 'profile_export.dart';
import 'profile_restore.dart';
import 'profile_store.dart';

class DriftDataTransferService implements DataTransferService {
  /// [db] is the ACTIVE profile's store; [gateway] its command gateway.
  DriftDataTransferService(this.db, this.directory,
      {CommandGateway? gateway, DateTime Function()? clock})
      : gateway = gateway ?? DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)),
        _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final ProfileDirectory directory;
  final CommandGateway gateway;
  final DateTime Function() _clock;
  static const _handler = ProfileRestoreHandler();
  final _uuid = const Uuid();

  @override
  Future<ExportFile> exportActiveProfile() async {
    final profile = await ProfileStore(db).getActiveProfile();
    final now = _clock();
    final text = await ProfileExport.build(db, now: now);
    final taskCount = (await db.select(db.tasks).get()).length;
    return ExportFile(
      suggestedName: 'lifeflow-${_slug(profile?.displayName ?? '')}-${_date(now)}.lifeflow.json',
      contents: text,
      taskCount: taskCount,
    );
  }

  /// Where a validated file belongs. The active profile when the file is its
  /// data (same profile, or the same account exported on another device);
  /// another profile on this device when that one matches; otherwise new.
  Future<({_Target kind, ParsedExport data, ProfileEntry? other})> _target(
      ParsedExport file) async {
    final ownRow = await db.select(db.profiles).getSingleOrNull();
    final aligned = ownRow == null ? null : alignToProfile(file, ownRow);
    if (aligned != null) return (kind: _Target.active, data: aligned, other: null);
    final all = await directory.list();
    final sameId = all.where((e) => e.id == file.profileId).firstOrNull;
    final account = file.accountId;
    final sameAccount = account == null
        ? null
        : all
            .where((e) => e.accountId == account && e.provider == file.accountProvider)
            .firstOrNull;
    final other = sameId ?? sameAccount;
    if (other != null) return (kind: _Target.other, data: file, other: other);
    return (kind: _Target.newProfile, data: file, other: null);
  }

  ParsedExport _parse(String text) =>
      ProfileExport.parse(text, currentSchemaVersion: db.schemaVersion);

  @override
  Future<RestorePreview> inspect(String text) async {
    final ParsedExport file;
    try {
      file = _parse(text);
    } on ExportRejected catch (e) {
      return RestoreRejected(e.kind, e.message);
    }
    final t = await _target(file);
    switch (t.kind) {
      case _Target.newProfile:
        return RestoreAsNewProfile(
            displayName: file.displayName, taskCount: file.taskCount);
      case _Target.other:
        return RestoreOtherProfile(
            displayName: t.other!.displayName.trim().isNotEmpty
                ? t.other!.displayName
                : (t.other!.isBound ? 'Account profile' : 'Guest'),
            locked: t.other!.isLocked);
      case _Target.active:
        final diff = RestorePlanner.diff(
            await RecordSet.ofDatabase(db), RecordSet.ofExport(t.data));
        return diff.isIdentical ? const RestoreIdentical() : RestoreDifferent(diff);
    }
  }

  @override
  Future<RestoreOutcome> restore(String text, {RestoreChoice? choice}) async {
    final ParsedExport file;
    try {
      file = _parse(text);
    } on ExportRejected catch (e) {
      return RestoreRejected(e.kind, e.message);
    }
    final t = await _target(file);
    final parsed = t.data;
    switch (t.kind) {
      case _Target.newProfile:
        return _restoreAsNew(parsed);
      case _Target.other:
        return const RestoreRejected(RestoreRejection.notApplicable,
            'This file belongs to another profile on this device. Open that '
            'profile, then restore the file there.');
      case _Target.active:
        if (choice == null) {
          return const RestoreRejected(RestoreRejection.notApplicable,
              'Choose how to restore this file into the profile.');
        }
        // Preview the plan first: a hierarchy conflict is answered by the
        // user, not by a failed command. The handler checks again in the
        // transaction.
        final plan = RestorePlanner.plan(
            await RecordSet.ofDatabase(db), RecordSet.ofExport(parsed), choice,
            now: _clock().toUtc(), actor: '');
        if (plan.conflictTitles.isNotEmpty) {
          return RestoreHierarchyConflict(plan.conflictTitles);
        }
        if (plan.changes.isEmpty) {
          return RestoredInto(
              added: 0, updated: 0, removed: 0, undoAvailable: await canUndoRestore());
        }
        return _run(restoreCommandType, {
          'op': 'restore',
          'text': text,
          'mode': choice.mode.name,
          'takeNewer': choice.takeNewer,
          'addMissing': choice.addMissing,
          'keepDeviceParents': choice.keepDeviceParents,
        }, undo: false);
    }
  }

  @override
  Future<bool> canUndoRestore() async =>
      (await (db.select(db.restoreSnapshots)..limit(1)).get()).isNotEmpty;

  @override
  Future<RestoreOutcome> undoLastRestore() async {
    if (!await canUndoRestore()) {
      return const RestoreRejected(
          RestoreRejection.notApplicable, 'There is no restore to undo.');
    }
    return _run(undoRestoreCommandType, {'op': 'undo'}, undo: true);
  }

  Future<RestoreOutcome> _run(String type, Map<String, Object?> payload,
      {required bool undo}) async {
    final profile = await ProfileStore(db).getActiveProfile();
    if (profile == null) {
      return const RestoreRejected(RestoreRejection.notApplicable, 'No profile is open.');
    }
    final id = profile.profileId.value;
    final row = await (db.select(db.profiles)..where((p) => p.id.equals(id))).getSingle();
    final CommandResult r;
    try {
      r = await gateway.execute(
        Command(
          operationId: _uuid.v7(),
          actor: ActorRef(ActorKind.owner, id),
          workspaceId: profile.activeWorkspaceId.value,
          type: type,
          payload: {...payload, 'id': id},
          expectedVersion: Version(row.version),
          issuedAt: Instant.now(),
        ),
        _handler,
      );
    } catch (_) {
      return const RestoreRejected(RestoreRejection.storage,
          'The data could not be saved on this device. Nothing was changed.');
    }
    switch (r) {
      case CommandOk(:final events):
        final s = events.single.payload;
        return RestoredInto(
          added: s['added'] as int,
          updated: s['updated'] as int,
          removed: s['removed'] as int,
          undoAvailable: !undo,
        );
      case CommandFailure(:final kind, :final reason):
        if (reason == 'restore-hierarchy-conflict') {
          // The data changed between the preview and the write.
          return const RestoreRejected(RestoreRejection.notApplicable,
              'The profile changed while restoring. Nothing was changed; try again.');
        }
        return RestoreRejected(
            kind == CommandFailureKind.versionConflict
                ? RestoreRejection.notApplicable
                : RestoreRejection.storage,
            'The restore could not be applied${reason == null ? '' : ' ($reason)'}. '
            'Nothing was changed.');
    }
  }

  Future<RestoreOutcome> _restoreAsNew(ParsedExport parsed) async {
    try {
      final entry = await directory.restoreFromExport(parsed);
      return Restored(profileViewOf(entry, active: false),
          taskCount: parsed.taskCount);
    } on StoreUnavailable catch (e) {
      return RestoreRejected(RestoreRejection.storage, e.reason);
    } catch (_) {
      return const RestoreRejected(RestoreRejection.storage,
          'The data could not be saved on this device. Nothing was changed.');
    }
  }

  /// A file-name-safe label from the profile name (ASCII only).
  static String _slug(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'profile' : (s.length > 24 ? s.substring(0, 24) : s);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum _Target { newProfile, active, other }
