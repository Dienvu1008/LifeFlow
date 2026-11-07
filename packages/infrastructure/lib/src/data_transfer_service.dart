// P01 T7: export / restore for the UI (UC-20a, ADR-0025).
import 'package:application/application.dart';

import 'account_service.dart' show profileViewOf;
import 'app_database.dart';
import 'local_store.dart' show StoreUnavailable;
import 'profile_directory.dart';
import 'profile_export.dart';
import 'profile_store.dart';

class DriftDataTransferService implements DataTransferService {
  /// [db] is the ACTIVE profile's store.
  DriftDataTransferService(this.db, this.directory, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final ProfileDirectory directory;
  final DateTime Function() _clock;

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

  @override
  Future<RestoreOutcome> restore(String text) async {
    final ParsedExport parsed;
    try {
      parsed = ProfileExport.parse(text, currentSchemaVersion: db.schemaVersion);
    } on ExportRejected catch (e) {
      return RestoreRejected(e.kind, e.message);
    }
    try {
      final r = await directory.restoreFromExport(parsed);
      return Restored(profileViewOf(r.entry, active: false),
          asCopy: r.asCopy, taskCount: parsed.taskCount);
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
