import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'permissions/permission_gate.dart';
import 'settings/settings_service.dart';
import 'calendar/calendar_service.dart';
import 'sync/mapping_database.dart';
import 'sync/sync_engine.dart';
import 'background/sync_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);

  const channel = MethodChannel('dev.henriquecouto.calsync/calendar_observer');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onCalendarChanged') {
      final settings = SettingsService();
      final interval = await settings.syncIntervalMinutes;
      if (interval == 0) return;

      await Workmanager().registerOneOffTask(
        'calendar_sync_reactive',
        'syncTask',
        initialDelay: const Duration(seconds: 5),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  });

  runApp(const CalendarSyncApp());
}

class CalendarSyncApp extends StatelessWidget {
  const CalendarSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PermissionGate(
      child: _SyncedApp(),
    );
  }
}

class _SyncedApp extends StatelessWidget {
  const _SyncedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _settings = SettingsService();
  final _calendarService = CalendarService();
  final _mappingDb = MappingDatabase();

  String? _sourceCalendarId;
  String? _targetCalendarId;
  int _intervalMinutes = 60;
  final _syncNameController = TextEditingController();

  List<_CalendarItem> _calendars = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sourceId = await _settings.sourceCalendarId;
    final targetId = await _settings.targetCalendarId;
    final syncName = await _settings.syncEventName;
    final interval = await _settings.syncIntervalMinutes;
    _syncNameController.text = syncName;

    final calendars = await _calendarService.listCalendars();

    setState(() {
      _sourceCalendarId = sourceId;
      _targetCalendarId = targetId;
      _intervalMinutes = interval;
      _calendars = calendars
          .map((c) => _CalendarItem(c.id ?? '', c.name ?? 'Unknown'))
          .toList();
      _loading = false;
    });

    await _registerPeriodicTask(interval);
  }

  Future<void> _registerPeriodicTask(int intervalMinutes) async {
    if (intervalMinutes > 0) {
      await Workmanager().registerPeriodicTask(
        'calendar_sync_periodic',
        'syncTask',
        frequency: Duration(minutes: intervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().cancelAll();
    }
  }

  Future<void> _saveSource(String id) async {
    await _settings.setSourceCalendarId(id);
    setState(() => _sourceCalendarId = id);
  }

  Future<void> _saveTarget(String id) async {
    await _settings.setTargetCalendarId(id);
    setState(() => _targetCalendarId = id);
  }

  Future<void> _saveSyncName() async {
    await _settings.setSyncEventName(_syncNameController.text);
  }

  Future<void> _saveInterval(int minutes) async {
    await _settings.setSyncIntervalMinutes(minutes);
    setState(() => _intervalMinutes = minutes);
    await _registerPeriodicTask(minutes);
  }

  Future<void> _sync() async {
    if (_sourceCalendarId == null || _targetCalendarId == null) {
      setState(() => _status = 'Select both calendars first.');
      return;
    }

    final syncName = _syncNameController.text.trim();
    if (syncName.isEmpty) {
      setState(() => _status = 'Enter a sync event name.');
      return;
    }

    await _saveSyncName();

    setState(() => _status = 'Syncing...');

    final engine = SyncEngine(_calendarService, _mappingDb);
    final result = await engine.runSync(
      sourceCalendarId: _sourceCalendarId!,
      targetCalendarId: _targetCalendarId!,
      syncEventName: syncName,
    );

    setState(() {
      _status =
          'Synced: ${result.synced.length}, '
          'Deleted: ${result.deleted.length}, '
          'Skipped: ${result.skipped.length}, '
          'Errors: ${result.errors.length}';
    });
  }

  @override
  void dispose() {
    _syncNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CalSync'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownMenu<String>(
                    initialSelection: _sourceCalendarId,
                    label: const Text('Source Calendar'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _calendars.map((c) {
                      return DropdownMenuEntry(value: c.id, label: c.name);
                    }).toList(),
                    onSelected: (val) {
                      if (val != null) _saveSource(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<String>(
                    initialSelection: _targetCalendarId,
                    label: const Text('Target Calendar'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _calendars.map((c) {
                      return DropdownMenuEntry(value: c.id, label: c.name);
                    }).toList(),
                    onSelected: (val) {
                      if (val != null) _saveTarget(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _syncNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sync Event Name',
                      hintText: 'e.g. Busy',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _saveSyncName(),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<int>(
                    initialSelection: _intervalMinutes,
                    label: const Text('Fallback Interval'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 0, label: 'Off (manual only)'),
                      DropdownMenuEntry(value: 15, label: '15 minutes'),
                      DropdownMenuEntry(value: 30, label: '30 minutes'),
                      DropdownMenuEntry(value: 60, label: '1 hour'),
                      DropdownMenuEntry(value: 120, label: '2 hours'),
                      DropdownMenuEntry(value: 360, label: '6 hours'),
                    ],
                    onSelected: (val) {
                      if (val != null) _saveInterval(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Changes are detected within seconds. '
                    'The interval above is a fallback only.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sync,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(_status, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
    );
  }
}

class _CalendarItem {
  final String id;
  final String name;

  const _CalendarItem(this.id, this.name);
}
