import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/dashboard_screen.dart';
import 'permissions/permission_gate.dart';
import 'settings/profile_service.dart';
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

  final targetId = prefs.getString('target_calendar_id');
  final eventName = prefs.getString('sync_event_name') ?? '';
  final interval = prefs.getInt('sync_interval_minutes') ?? 60;
  final enabled = prefs.getBool('sync_enabled') ?? false;

  final profileService = ProfileService();
  final profile = await profileService.createProfile(
    name: 'Default',
    sourceCalendarId: sourceId,
    targetCalendarId: targetId,
    eventName: eventName,
    intervalMinutes: interval,
    enabled: enabled,
  );

  final db = await profileService.database;
  await db.update(
    'sync_mappings',
    {'profile_id': profile.id},
    where: "profile_id = ''",
  );
  await db.update(
    'sync_status',
    {'profile_id': profile.id},
    where: "profile_id = ''",
  );
  final mappings = await db.query('sync_mappings',
      columns: ['target_calendar_id', 'target_event_id'],
      where: 'profile_id = ?',
      whereArgs: [profile.id]);
  for (final m in mappings) {
    await db.insert(
      'sync_created_events',
      {
        'calendar_id': m['target_calendar_id'],
        'event_id': m['target_event_id'],
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
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
