import 'package:flutter/material.dart';

import '../settings/settings_service.dart';
import '../calendar/calendar_service.dart';
import '../widgets/empty_state.dart';
import 'package:workmanager/workmanager.dart';

class ProfileConfigScreen extends StatefulWidget {
  const ProfileConfigScreen({super.key});

  @override
  State<ProfileConfigScreen> createState() => _ProfileConfigScreenState();
}

class _CalendarItem {
  final String id;
  final String name;

  const _CalendarItem(this.id, this.name);
}

class _ProfileConfigScreenState extends State<ProfileConfigScreen> {
  final _settings = SettingsService();
  final _calendarService = CalendarService();

  String? _sourceCalendarId;
  String? _targetCalendarId;
  int _intervalMinutes = 60;
  bool _syncEnabled = false;
  final _syncNameController = TextEditingController();

  List<_CalendarItem> _calendars = [];
  bool _loadingCalendars = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sourceId = await _settings.sourceCalendarId;
    final targetId = await _settings.targetCalendarId;
    final syncName = await _settings.syncEventName;
    final interval = await _settings.syncIntervalMinutes;
    final syncEnabled = await _settings.syncEnabled;
    _syncNameController.text = syncName;

    final calendars = await _calendarService.listCalendars();

    setState(() {
      _sourceCalendarId = sourceId;
      _targetCalendarId = targetId;
      _intervalMinutes = interval;
      _syncEnabled = syncEnabled;
      _calendars = calendars
          .map((c) => _CalendarItem(
                c.id,
                c.name.isNotEmpty ? c.name : (c.accountName ?? 'Unknown'),
              ))
          .toList();
      _loadingCalendars = false;
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

  Future<void> _saveInterval(int minutes) async {
    await _settings.setSyncIntervalMinutes(minutes);
    setState(() => _intervalMinutes = minutes);
    await _registerPeriodicTask(minutes);
  }

  @override
  void dispose() {
    _syncNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendar Pairing',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingCalendars)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_calendars.isEmpty)
                    const EmptyState(
                      icon: Icons.calendar_month,
                      title: 'No calendars found',
                    )
                  else ...[
                    DropdownMenu<String>(
                      initialSelection: _sourceCalendarId,
                      label: const Text('Source Calendar'),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: _calendars.map((c) {
                        return DropdownMenuEntry(
                            value: c.id, label: c.name);
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
                        return DropdownMenuEntry(
                            value: c.id, label: c.name);
                      }).toList(),
                      onSelected: (val) {
                        if (val != null) _saveTarget(val);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Naming',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<int>(
                    initialSelection: _intervalMinutes,
                    label: const Text('Fallback Interval'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(
                          value: 0, label: 'Off (manual only)'),
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
                  Text(
                    'Changes are detected within seconds. '
                    'The interval above is a fallback only.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sync enabled'),
                    value: _syncEnabled,
                    onChanged: (val) async {
                      await _settings.setSyncEnabled(val);
                      setState(() => _syncEnabled = val);
                    },
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}
