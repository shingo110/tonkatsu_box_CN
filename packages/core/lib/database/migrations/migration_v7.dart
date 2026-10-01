import 'package:sqflite_common/sqlite_api.dart';

import '../schema.dart';
import 'migration.dart';

class MigrationV7 extends Migration {
  @override
  int get version => 7;

  @override
  String get description =>
      'Create movies_cache, tv_shows_cache, tv_seasons_cache tables';

  @override
  Future<void> migrate(Database db) async {
    if (!await Migration.tableExists(db, 'movies_cache')) {
      await DatabaseSchema.createMoviesCacheTable(db);
    }
    if (!await Migration.tableExists(db, 'tv_shows_cache')) {
      await DatabaseSchema.createTvShowsCacheTable(db);
    }
    if (!await Migration.tableExists(db, 'tv_seasons_cache')) {
      await DatabaseSchema.createTvSeasonsCacheTable(db);
    }
  }
}
