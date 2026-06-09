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

  static const _statusTable = 'sync_status';
  static const _statusId = 'id';
  static const _statusTimestamp = 'timestamp';
  static const _statusSynced = 'synced';
  static const _statusDeleted = 'deleted';
  static const _statusSkipped = 'skipped';
  static const _statusErrors = 'errors';

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
      version: 2,
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
        await db.execute('''
          CREATE TABLE $_statusTable (
            $_statusId INTEGER PRIMARY KEY AUTOINCREMENT,
            $_statusTimestamp TEXT NOT NULL,
            $_statusSynced INTEGER NOT NULL,
            $_statusDeleted INTEGER NOT NULL,
            $_statusSkipped INTEGER NOT NULL,
            $_statusErrors INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $_statusTable (
              $_statusId INTEGER PRIMARY KEY AUTOINCREMENT,
              $_statusTimestamp TEXT NOT NULL,
              $_statusSynced INTEGER NOT NULL,
              $_statusDeleted INTEGER NOT NULL,
              $_statusSkipped INTEGER NOT NULL,
              $_statusErrors INTEGER NOT NULL
            )
          ''');
        }
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

  Future<void> insertStatus({
    required String timestamp,
    required int synced,
    required int deleted,
    required int skipped,
    required int errors,
  }) async {
    final db = await database;
    await db.insert(_statusTable, {
      _statusTimestamp: timestamp,
      _statusSynced: synced,
      _statusDeleted: deleted,
      _statusSkipped: skipped,
      _statusErrors: errors,
    });
    final count = (await db.rawQuery('SELECT COUNT(*) AS cnt FROM $_statusTable')).first['cnt'] as int;
    if (count > 20) {
      final oldest = await db.query(
        _statusTable,
        columns: [_statusId],
        orderBy: '$_statusId ASC',
        limit: count - 20,
      );
      for (final row in oldest) {
        await db.delete(_statusTable, where: '$_statusId = ?', whereArgs: [row[_statusId]]);
      }
    }
  }

  Future<List<Map<String, Object?>>> getStatusHistory({int limit = 20}) async {
    final db = await database;
    return db.query(
      _statusTable,
      orderBy: '$_statusId DESC',
      limit: limit,
    );
  }
}
