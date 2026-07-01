import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../sync/database_provider.dart';

class SyncProfile {
  final String id;
  final String name;
  final String? sourceCalendarId;
  final String? targetCalendarId;
  final String eventName;
  final int intervalMinutes;
  final bool enabled;
  final bool copyDescription;
  final bool copyLocation;

  const SyncProfile({
    required this.id,
    required this.name,
    this.sourceCalendarId,
    this.targetCalendarId,
    required this.eventName,
    required this.intervalMinutes,
    required this.enabled,
    this.copyDescription = false,
    this.copyLocation = false,
  });

  SyncProfile copyWith({
    String? name,
    String? sourceCalendarId,
    String? targetCalendarId,
    String? eventName,
    int? intervalMinutes,
    bool? enabled,
    bool? copyDescription,
    bool? copyLocation,
  }) {
    return SyncProfile(
      id: id,
      name: name ?? this.name,
      sourceCalendarId: sourceCalendarId ?? this.sourceCalendarId,
      targetCalendarId: targetCalendarId ?? this.targetCalendarId,
      eventName: eventName ?? this.eventName,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      copyDescription: copyDescription ?? this.copyDescription,
      copyLocation: copyLocation ?? this.copyLocation,
    );
  }
}

class ProfileService {
  static const _tableName = 'sync_profiles';
  static const _columnId = 'id';
  static const _columnName = 'name';
  static const _columnSourceCalendarId = 'source_calendar_id';
  static const _columnTargetCalendarId = 'target_calendar_id';
  static const _columnEventName = 'event_name';
  static const _columnIntervalMinutes = 'interval_minutes';
  static const _columnEnabled = 'enabled';
  static const _columnCopyDescription = 'copy_description';
  static const _columnCopyLocation = 'copy_location';

  final DatabaseProvider _dbProvider;

  ProfileService() : _dbProvider = DatabaseProvider();

  Future<Database> get database => _dbProvider.database;

  Future<SyncProfile> createProfile({
    required String name,
    String? sourceCalendarId,
    String? targetCalendarId,
    required String eventName,
    required int intervalMinutes,
    required bool enabled,
    bool copyDescription = false,
    bool copyLocation = false,
  }) async {
    final db = await database;
    final id = const Uuid().v4();
    await db.insert(_tableName, {
      _columnId: id,
      _columnName: name,
      _columnSourceCalendarId: sourceCalendarId,
      _columnTargetCalendarId: targetCalendarId,
      _columnEventName: eventName,
      _columnIntervalMinutes: intervalMinutes,
      _columnEnabled: enabled ? 1 : 0,
      _columnCopyDescription: copyDescription ? 1 : 0,
      _columnCopyLocation: copyLocation ? 1 : 0,
    });
    return SyncProfile(
      id: id,
      name: name,
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      eventName: eventName,
      intervalMinutes: intervalMinutes,
      enabled: enabled,
      copyDescription: copyDescription,
      copyLocation: copyLocation,
    );
  }

  Future<void> updateProfile(SyncProfile profile) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        _columnName: profile.name,
        _columnSourceCalendarId: profile.sourceCalendarId,
        _columnTargetCalendarId: profile.targetCalendarId,
        _columnEventName: profile.eventName,
        _columnIntervalMinutes: profile.intervalMinutes,
        _columnEnabled: profile.enabled ? 1 : 0,
        _columnCopyDescription: profile.copyDescription ? 1 : 0,
        _columnCopyLocation: profile.copyLocation ? 1 : 0,
      },
      where: '$_columnId = ?',
      whereArgs: [profile.id],
    );
  }

  Future<void> deleteProfile(String id) async {
    final db = await database;
    final mappings = await db.query(
      'sync_mappings',
      columns: ['target_calendar_id', 'target_event_id'],
      where: 'profile_id = ?',
      whereArgs: [id],
    );
    for (final m in mappings) {
      await db.delete(
        'sync_created_events',
        where: 'calendar_id = ? AND event_id = ?',
        whereArgs: [m['target_calendar_id'], m['target_event_id']],
      );
    }
    await db.delete(
      'sync_mappings',
      where: 'profile_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'sync_status',
      where: 'profile_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      _tableName,
      where: '$_columnId = ?',
      whereArgs: [id],
    );
  }

  Future<SyncProfile?> getProfile(String id) async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: '$_columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return _rowToProfile(results.first);
  }

  Future<List<SyncProfile>> listProfiles() async {
    final db = await database;
    final results = await db.query(_tableName, orderBy: '$_columnName ASC');
    return results.map(_rowToProfile).toList();
  }

  Future<bool> isNameTaken(String name, {String? excludeId}) async {
    final db = await database;
    String where = '$_columnName = ?';
    List<Object?> whereArgs = [name];
    if (excludeId != null) {
      where += ' AND $_columnId != ?';
      whereArgs.add(excludeId);
    }
    final results = await db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> isSourceTargetPairTaken(
    String sourceCalendarId,
    String targetCalendarId, {
    String? excludeId,
  }) async {
    final db = await database;
    String where =
        '$_columnSourceCalendarId = ? AND $_columnTargetCalendarId = ?';
    List<Object?> whereArgs = [sourceCalendarId, targetCalendarId];
    if (excludeId != null) {
      where += ' AND $_columnId != ?';
      whereArgs.add(excludeId);
    }
    final results = await db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<List<SyncProfile>> listEnabledProfiles() async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: '$_columnEnabled = 1',
      orderBy: '$_columnName ASC',
    );
    return results.map(_rowToProfile).toList();
  }

  SyncProfile _rowToProfile(Map<String, Object?> row) {
    return SyncProfile(
      id: row[_columnId] as String,
      name: row[_columnName] as String,
      sourceCalendarId: row[_columnSourceCalendarId] as String?,
      targetCalendarId: row[_columnTargetCalendarId] as String?,
      eventName: (row[_columnEventName] as String?) ?? '',
      intervalMinutes: (row[_columnIntervalMinutes] as int?) ?? 60,
      enabled: (row[_columnEnabled] as int?) == 1,
      copyDescription: (row[_columnCopyDescription] as int?) == 1,
      copyLocation: (row[_columnCopyLocation] as int?) == 1,
    );
  }
}
