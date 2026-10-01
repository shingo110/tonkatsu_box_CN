import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// SQLite has no `ALTER COLUMN`, so dropping `NOT NULL` on `collection_id`
/// needs a full table rebuild plus rebuilt unique indexes.
class MigrationV17 extends Migration {
  @override
  int get version => 17;

  @override
  String get description =>
      'Recreate collection_items with nullable collection_id';

  @override
  Future<void> migrate(Database db) async {
    // A rewound or wiped `user_version` replays this migration when the
    // rebuild has already landed. `collection_items_new` is the marker of the
    // finished state — skipping keeps the replay from crashing on
    // `DROP TABLE collection_items` of an already-renamed table.
    if (await Migration.tableExists(db, 'collection_items_new')) {
      return;
    }

    await db.execute('''
      CREATE TABLE collection_items_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER,
        media_type TEXT NOT NULL DEFAULT 'game',
        external_id INTEGER NOT NULL,
        platform_id INTEGER,
        current_season INTEGER DEFAULT 0,
        current_episode INTEGER DEFAULT 0,
        status TEXT DEFAULT 'not_started',
        author_comment TEXT,
        user_comment TEXT,
        added_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER,
        completed_at INTEGER,
        last_activity_at INTEGER,
        user_rating INTEGER,
        FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
      )
    ''');

    // Copy with an explicit column list so a future re-order or added column
    // in `collection_items` can't silently map into the wrong column.
    await db.execute('''
      INSERT INTO collection_items_new (
        id, collection_id, media_type, external_id, platform_id,
        current_season, current_episode, status, author_comment,
        user_comment, added_at, sort_order, started_at, completed_at,
        last_activity_at, user_rating
      )
      SELECT
        id, collection_id, media_type, external_id, platform_id,
        current_season, current_episode, status, author_comment,
        user_comment, added_at, sort_order, started_at, completed_at,
        last_activity_at, user_rating
      FROM collection_items
    ''');

    await db.execute('DROP TABLE collection_items');
    await db.execute(
      'ALTER TABLE collection_items_new RENAME TO collection_items',
    );

    // Split by collection vs uncategorised (collection_id IS NULL);
    // COALESCE(platform_id, -1) buckets NULL so multi-platform rows stay distinct.
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_coll
      ON collection_items(
        collection_id, media_type, external_id, COALESCE(platform_id, -1)
      )
      WHERE collection_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_uncat
      ON collection_items(media_type, external_id, COALESCE(platform_id, -1))
      WHERE collection_id IS NULL
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_collection_items_collection
      ON collection_items(collection_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_collection_items_type
      ON collection_items(media_type)
    ''');
  }
}
