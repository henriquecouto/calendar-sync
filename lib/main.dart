import 'package:flutter/material.dart';
import 'permissions/permission_gate.dart';
import 'settings/settings_service.dart';
import 'calendar/calendar_service.dart';
import 'sync/mapping_database.dart';
import 'sync/sync_engine.dart';

void main() {
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
      title: 'Calendar Sync',
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
    _syncNameController.text = syncName;

    final calendars = await _calendarService.listCalendars();

    setState(() {
      _sourceCalendarId = sourceId;
      _targetCalendarId = targetId;
      _calendars = calendars
          .map((c) => _CalendarItem(c.id ?? '', c.name ?? 'Unknown'))
          .toList();
      _loading = false;
    });
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
      appBar: AppBar(title: const Text('Calendar Sync'), centerTitle: true),
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
                  const SizedBox(height: 24),
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
