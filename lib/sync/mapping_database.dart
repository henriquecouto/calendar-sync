import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

class MappingDatabase {
  static const _tableName = 'sync_mappings';
  static const _columnId = 'id';
  static const _columnProfileId = 'profile_id';
  static const _columnSourceCalendarId = 'source_calendar_id';
  static const _columnSourceEventId = 'source_event_id';
  static const _columnTargetCalendarId = 'target_calendar_id';
  static const _columnTargetEventId = 'target_event_id';
  static const _columnSyncedAt = 'synced_at';

  static const _statusTable = 'sync_status';
  static const _statusId = 'id';
  static const _statusProfileId = 'profile_id';
  static const _statusTimestamp = 'timestamp';
  static const _statusSynced = 'synced';
  static const _statusDeleted = 'deleted';
  static const _statusSkipped = 'skipped';
  static const _statusErrors = 'errors';
  static const _statusUpdated = 'updated';

  static const _createdEventsTable = 'sync_created_events';
  static const _ceCalendarId = 'calendar_id';
  static const _ceEventId = 'event_id';

  final DatabaseProvider _dbProvider;

  MappingDatabase() : _dbProvider = DatabaseProvider();

  Future<Database> get database => _dbProvider.database;

  Future<bool> isEventSynced(
    String profileId,
    String sourceCalendarId,
    String sourceEventId,
  ) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where:
          '$_columnProfileId = ? AND $_columnSourceCalendarId = ? AND $_columnSourceEventId = ?',
      whereArgs: [profileId, sourceCalendarId, sourceEventId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertMapping({
    required String profileId,
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
        _columnProfileId: profileId,
        _columnSourceCalendarId: sourceCalendarId,
        _columnSourceEventId: sourceEventId,
        _columnTargetCalendarId: targetCalendarId,
        _columnTargetEventId: targetEventId,
        _columnSyncedAt: syncedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listMappingsForCalendar(
    String profileId,
    String sourceCalendarId,
  ) async {
    final db = await database;
    return db.query(
      _tableName,
      where:
          '$_columnProfileId = ? AND $_columnSourceCalendarId = ?',
      whereArgs: [profileId, sourceCalendarId],
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
    required String profileId,
    required String timestamp,
    required int synced,
    required int deleted,
    required int skipped,
    required int updated,
    required int errors,
  }) async {
    final db = await database;
    await db.insert(_statusTable, {
      _statusProfileId: profileId,
      _statusTimestamp: timestamp,
      _statusSynced: synced,
      _statusDeleted: deleted,
      _statusSkipped: skipped,
      _statusUpdated: updated,
      _statusErrors: errors,
    });
    final count = (await db.rawQuery(
            'SELECT COUNT(*) AS cnt FROM $_statusTable WHERE $_statusProfileId = ?',
            [profileId]))
        .first['cnt'] as int;
    if (count > 20) {
      final oldest = await db.query(
        _statusTable,
        columns: [_statusId],
        where: '$_statusProfileId = ?',
        whereArgs: [profileId],
        orderBy: '$_statusId ASC',
        limit: count - 20,
      );
      for (final row in oldest) {
        await db.delete(
          _statusTable,
          where: '$_statusId = ?',
          whereArgs: [row[_statusId]],
        );
      }
    }
  }

  Future<List<Map<String, Object?>>> getStatusHistory({
    int limit = 20,
    String? profileId,
  }) async {
    final db = await database;
    if (profileId != null) {
      return db.query(
        _statusTable,
        where: '$_statusProfileId = ?',
        whereArgs: [profileId],
        orderBy: '$_statusId DESC',
        limit: limit,
      );
    }
    return db.query(
      _statusTable,
      orderBy: '$_statusId DESC',
      limit: limit,
    );
  }

  Future<bool> isEventCreatedBySync(
    String calendarId,
    String eventId,
  ) async {
    final db = await database;
    final result = await db.query(
      _createdEventsTable,
      where: '$_ceCalendarId = ? AND $_ceEventId = ?',
      whereArgs: [calendarId, eventId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertCreatedEvent(
    String calendarId,
    String eventId,
  ) async {
    final db = await database;
    await db.insert(
      _createdEventsTable,
      {
        _ceCalendarId: calendarId,
        _ceEventId: eventId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteCreatedEvent(
    String calendarId,
    String eventId,
  ) async {
    final db = await database;
    await db.delete(
      _createdEventsTable,
      where: '$_ceCalendarId = ? AND $_ceEventId = ?',
      whereArgs: [calendarId, eventId],
    );
  }

  Future<List<Map<String, Object?>>> listMappingsForProfile(
    String profileId,
  ) async {
    final db = await database;
    return db.query(
      _tableName,
      where: '$_columnProfileId = ?',
      whereArgs: [profileId],
    );
  }
}
