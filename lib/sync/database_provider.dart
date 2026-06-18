import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseProvider {
  static DatabaseProvider? _instance;
  factory DatabaseProvider() => _instance ??= DatabaseProvider._();
  DatabaseProvider._();

  Database? _db;
  static String? _testPath;

  static void setTestPath(String path) {
    _testPath = path;
    _instance = null;
  }

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final name = _testPath ?? 'calendar_sync.db';
    final path = join(dbPath, name);
    final db = await openDatabase(
      path,
      version: 5,
      singleInstance: false,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_mappings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id TEXT NOT NULL DEFAULT '',
            source_calendar_id TEXT NOT NULL,
            source_event_id TEXT NOT NULL,
            target_calendar_id TEXT NOT NULL,
            target_event_id TEXT NOT NULL,
            synced_at TEXT NOT NULL,
            canonical_time TEXT,
            UNIQUE(profile_id, source_calendar_id, source_event_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_status (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id TEXT NOT NULL DEFAULT '',
            timestamp TEXT NOT NULL,
            synced INTEGER NOT NULL,
            deleted INTEGER NOT NULL,
            skipped INTEGER NOT NULL,
            updated INTEGER NOT NULL,
            errors INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            source_calendar_id TEXT,
            target_calendar_id TEXT,
            event_name TEXT NOT NULL DEFAULT '',
            interval_minutes INTEGER NOT NULL DEFAULT 60,
            enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_created_events (
            calendar_id TEXT NOT NULL,
            event_id TEXT NOT NULL,
            UNIQUE(calendar_id, event_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE sync_status (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id TEXT NOT NULL DEFAULT '',
              timestamp TEXT NOT NULL,
              synced INTEGER NOT NULL,
              deleted INTEGER NOT NULL,
              skipped INTEGER NOT NULL,
              errors INTEGER NOT NULL,
              updated INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE sync_status ADD COLUMN updated INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE sync_mappings ADD COLUMN profile_id TEXT NOT NULL DEFAULT \'\'');
          await db.execute('ALTER TABLE sync_status ADD COLUMN profile_id TEXT NOT NULL DEFAULT \'\'');
          await db.execute('''
            CREATE TABLE sync_mappings_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id TEXT NOT NULL DEFAULT '',
              source_calendar_id TEXT NOT NULL,
              source_event_id TEXT NOT NULL,
              target_calendar_id TEXT NOT NULL,
              target_event_id TEXT NOT NULL,
              synced_at TEXT NOT NULL,
              UNIQUE(profile_id, source_calendar_id, source_event_id)
            )
          ''');
          await db.execute('INSERT INTO sync_mappings_new SELECT * FROM sync_mappings');
          await db.execute('DROP TABLE sync_mappings');
          await db.execute('ALTER TABLE sync_mappings_new RENAME TO sync_mappings');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_profiles (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL UNIQUE,
              source_calendar_id TEXT,
              target_calendar_id TEXT,
              event_name TEXT NOT NULL DEFAULT '',
              interval_minutes INTEGER NOT NULL DEFAULT 60,
              enabled INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_created_events (
              calendar_id TEXT NOT NULL,
              event_id TEXT NOT NULL,
              UNIQUE(calendar_id, event_id)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE sync_mappings ADD COLUMN canonical_time TEXT');
        }
      },
    );
    return db;
  }
}
