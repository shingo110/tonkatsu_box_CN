import 'package:sqflite_common/sqlite_api.dart';

import '../schema.dart';
import 'migration.dart';

/// Adds `tracked_releases`, keyed by `(external_id, source, media_type)`. Dates
/// still come from `tv_episodes_cache`, so nothing else changes.
class MigrationV45 extends Migration {
  @override
  int get version => 45;

  @override
  String get description => 'Release tracking: tracked_releases table';

  @override
  Future<void> migrate(Database db) async {
    if (!await Migration.tableExists(db, 'tracked_releases')) {
      await DatabaseSchema.createTrackedReleasesTable(db);
    }
  }
}
