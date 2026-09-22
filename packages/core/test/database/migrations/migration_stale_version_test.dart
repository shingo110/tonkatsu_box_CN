import 'dart:io';

import 'package:core/database/database_opener.dart';
import 'package:core/database/migrations/migration_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

/// A database whose schema already reached the latest version but whose
/// `user_version` lagged behind (an upgrade interrupted by a crash or a
/// restored file) must still open: the opener replays v57..v64, and both v63
/// and v64 used to abort on the tables v64 had already created. The replay must
/// also keep the user's listened-track history rather than re-dropping it.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory scratch;
  late String path;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('tonkatsu_migration_');
    path = '${scratch.path}/tonkatsu_box.db';
  });

  tearDown(() async {
    if (scratch.existsSync()) {
      await scratch.delete(recursive: true);
    }
  });

  test(
      'replays v57..v64 when the schema is current but user_version is stale',
      () async {
    final Database built = await openAppDatabase(
      factory: databaseFactory,
      path: path,
    );
    expect(await built.getVersion(), MigrationRegistry.latestVersion);

    // Seed a listened-track row so the replay can be checked for data loss.
    await built.insert('collections', <String, Object?>{
      'id': 1,
      'name': 'C1',
      'author': 'tester',
      'created_at': 1700000000,
    });
    await built.insert('listened_tracks', <String, Object?>{
      'collection_id': 1,
      'audio_id': 7,
      'source': 'musicBrainz',
      'disc_number': 1,
      'track_number': 1,
      'listened_at': 1700000000,
    });

    // Wind the recorded version back without touching the schema, mimicking a
    // database left behind by an interrupted upgrade.
    await built.execute('PRAGMA user_version = 56');
    expect(await built.getVersion(), 56);
    await built.close();

    final Database reopened = await openAppDatabase(
      factory: databaseFactory,
      path: path,
    );
    expect(await reopened.getVersion(), MigrationRegistry.latestVersion);

    final List<Map<String, Object?>> tables = await reopened.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('audio_cache', 'audio_tracks_cache', 'listened_tracks')",
    );
    expect(tables.length, 3);

    final List<Map<String, Object?>> kept = await reopened.rawQuery(
      'SELECT COUNT(*) AS n FROM listened_tracks',
    );
    expect(kept.single['n'], 1);

    await reopened.close();
  });
}
