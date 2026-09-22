import 'package:sqflite_common/sqlite_api.dart';

abstract class Migration {
  int get version;
  String get description;
  Future<void> migrate(Database db);

  /// SQLite has no `ADD COLUMN IF NOT EXISTS`. A big-jump upgrade can run a
  /// create that already has the column, then the historical ALTER — this guards it.
  static Future<void> addColumnIfAbsent(
    Database db,
    String table,
    String column,
    String columnDef,
  ) async {
    final List<Map<String, Object?>> columns =
        await db.rawQuery('PRAGMA table_info($table)');
    final bool exists = columns.any(
      (Map<String, Object?> c) => c['name'] == column,
    );
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    }
  }

  /// Counterpart to [addColumnIfAbsent] for whole tables: a rewound or wiped
  /// `user_version` replays a migration whose CREATE has already run.
  static Future<bool> tableExists(Database db, String table) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      <Object?>[table],
    );
    return rows.isNotEmpty;
  }
}
