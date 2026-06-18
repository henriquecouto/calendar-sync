import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import 'calendar/calendar_service.dart';
import 'screens/dashboard_screen.dart';
import 'permissions/permission_gate.dart';
import 'background/sync_task.dart';

Future<void> _migrateIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final migrated = prefs.getBool('profile_migration_done') ?? false;
  if (migrated) return;

  final sourceId = prefs.getString('source_calendar_id');
  if (sourceId == null) {
    await prefs.setBool('profile_migration_done', true);
    return;
  }

  final dbPath = await getDatabasesPath();
  final dbFile = File(join(dbPath, 'calendar_sync.db'));

  if (await dbFile.exists()) {
    try {
      final oldDb = await openDatabase(dbFile.path, readOnly: true);
      final mappings = await oldDb.query('sync_mappings',
          columns: ['target_calendar_id', 'target_event_id']);
      await oldDb.close();

      final calendarService = CalendarService();
      for (final m in mappings) {
        await calendarService.deleteEvent(m['target_event_id'] as String);
      }
    } catch (_) {}

    await dbFile.delete();
    final walFile = File(join(dbPath, 'calendar_sync.db-wal'));
    if (await walFile.exists()) await walFile.delete();
    final shmFile = File(join(dbPath, 'calendar_sync.db-shm'));
    if (await shmFile.exists()) await shmFile.delete();
  }

  await prefs.remove('source_calendar_id');
  await prefs.remove('target_calendar_id');
  await prefs.remove('sync_event_name');
  await prefs.remove('sync_interval_minutes');
  await prefs.remove('sync_enabled');
  await prefs.setBool('profile_migration_done', true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  await _migrateIfNeeded();
  runApp(const CalendarSyncApp());
}

class CalendarSyncApp extends StatelessWidget {
  const CalendarSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        );
        final darkScheme = darkDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        );

        final lightTheme = ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
        );

        final darkTheme = ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
        );

        return MaterialApp(
          title: 'CalSync',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          home: const _SyncedGate(),
        );
      },
    );
  }
}

class _SyncedGate extends StatelessWidget {
  const _SyncedGate();

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      child: Builder(
        builder: (context) {
          return const DashboardScreen();
        },
      ),
    );
  }
}
