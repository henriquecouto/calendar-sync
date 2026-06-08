import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MappingDatabase {
  static const _tableName = 'sync_mappings';
  static const _columnId = 'id';
  static const _columnSourceCalendarId = 'source_calendar_id';
  static const _columnSourceEventId = 'source_event_id';
  static const _columnTargetCalendarId = 'target_calendar_id';
  static const _columnTargetEventId = 'target_event_id';
  static const _columnSyncedAt = 'synced_at';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'calendar_sync.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            $_columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $_columnSourceCalendarId TEXT NOT NULL,
            $_columnSourceEventId TEXT NOT NULL,
            $_columnTargetCalendarId TEXT NOT NULL,
            $_columnTargetEventId TEXT NOT NULL,
            $_columnSyncedAt TEXT NOT NULL,
            UNIQUE($_columnSourceCalendarId, $_columnSourceEventId)
          )
        ''');
      },
    );
  }

  Future<bool> isEventSynced(
    String sourceCalendarId,
    String sourceEventId,
  ) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: '$_columnSourceCalendarId = ? AND $_columnSourceEventId = ?',
      whereArgs: [sourceCalendarId, sourceEventId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertMapping({
    required String sourceCalendarId,
    required String sourceEventId,
    required String targetCalendarId,
    required String targetEventId,
    required String syncedAt,
  }) async {
    final db = await database;
    await db.insert(
      _tableName,
      {
        _columnSourceCalendarId: sourceCalendarId,
        _columnSourceEventId: sourceEventId,
        _columnTargetCalendarId: targetCalendarId,
        _columnTargetEventId: targetEventId,
        _columnSyncedAt: syncedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> listMappingsForCalendar(
    String sourceCalendarId,
  ) async {
    final db = await database;
    return db.query(
      _tableName,
      where: '$_columnSourceCalendarId = ?',
      whereArgs: [sourceCalendarId],
    );
  }

  Future<void> deleteMapping(int id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: '$_columnId = ?',
      whereArgs: [id],
    );
  }
}
