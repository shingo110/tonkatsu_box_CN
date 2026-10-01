import 'package:sqflite_common/sqlite_api.dart';

import '../schema.dart';
import 'migration.dart';

class MigrationV5 extends Migration {
  @override
  int get version => 5;

  @override
  String get description => 'Create canvas_items and canvas_viewport tables';

  @override
  Future<void> migrate(Database db) async {
    if (!await Migration.tableExists(db, 'canvas_items')) {
      await DatabaseSchema.createCanvasItemsTable(db);
    }
    if (!await Migration.tableExists(db, 'canvas_viewport')) {
      await DatabaseSchema.createCanvasViewportTable(db);
    }
  }
}
