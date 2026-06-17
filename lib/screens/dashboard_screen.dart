import 'package:flutter/material.dart';

import '../settings/settings_service.dart';
import '../calendar/calendar_service.dart';
import '../sync/mapping_database.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_status_screen.dart';
import '../sync/dry_run_screen.dart';
import '../widgets/profile_card.dart';
import '../widgets/empty_state.dart';
import 'profile_config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _settings = SettingsService();
  final _calendarService = CalendarService();
  final _mappingDb = MappingDatabase();

  String? _sourceCalendarId;
  String? _targetCalendarId;
  String _eventName = '';
  int _intervalMinutes = 60;
  bool _syncEnabled = false;

  String? _sourceCalendarName;
  String? _targetCalendarName;
  String? _lastSyncText;

  List<Map<String, Object?>> _recentHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sourceId = await _settings.sourceCalendarId;
    final targetId = await _settings.targetCalendarId;
    final eventName = await _settings.syncEventName;
    final interval = await _settings.syncIntervalMinutes;
    final syncEnabled = await _settings.syncEnabled;

    String? sourceName;
    String? targetName;
    String? lastSyncText;

    final calendars = await _calendarService.listCalendars();
    if (sourceId != null) {
      sourceName = calendars
          .where((c) => c.id == sourceId)
          .map((c) => c.name.isNotEmpty ? c.name : (c.accountName ?? 'Unknown'))
          .firstOrNull;
    }
    if (targetId != null) {
      targetName = calendars
          .where((c) => c.id == targetId)
          .map((c) => c.name.isNotEmpty ? c.name : (c.accountName ?? 'Unknown'))
          .firstOrNull;
    }

    final history = await _mappingDb.getStatusHistory(limit: 3);
    if (history.isNotEmpty) {
      final last = history.first;
      final ts = last['timestamp'] as String?;
      if (ts != null) {
        lastSyncText = _formatLastSync(ts);
      }
    }

    setState(() {
      _sourceCalendarId = sourceId;
      _targetCalendarId = targetId;
      _eventName = eventName;
      _intervalMinutes = interval;
      _syncEnabled = syncEnabled;
      _sourceCalendarName = sourceName;
      _targetCalendarName = targetName;
      _lastSyncText = lastSyncText;
      _recentHistory = history;
      _loading = false;
    });
  }

  String _formatLastSync(String ts) {
    final dt = DateTime.tryParse(ts);
    if (dt == null) return ts;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get _hasProfile =>
      _sourceCalendarId != null && _targetCalendarId != null;

  Future<void> _syncAll() async {
    if (!_hasProfile || !_syncEnabled) return;

    final syncName = _eventName.trim();
    if (syncName.isEmpty) return;

    setState(() => _lastSyncText = 'Syncing...');

    final engine = SyncEngine(_calendarService, _mappingDb);
    final result = await engine.runSync(
      sourceCalendarId: _sourceCalendarId!,
      targetCalendarId: _targetCalendarId!,
      syncEventName: syncName,
    );

    await _mappingDb.insertStatus(
      timestamp: DateTime.now().toIso8601String(),
      synced: result.synced.length,
      deleted: result.deleted.length,
      skipped: result.skipped.length,
      updated: result.updated.length,
      errors: result.errors.length,
    );

    _load();
  }

  Future<void> _navigateToConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileConfigScreen(),
      ),
    );
    _load();
  }

  String _formatHistoryCounts(Map<String, Object?> entry) {
    final synced = entry['synced'] as int;
    final updated = entry['updated'] as int;
    final deleted = entry['deleted'] as int;
    final errors = entry['errors'] as int;
    final parts = <String>[];
    if (synced > 0) parts.add('$synced synced');
    if (updated > 0) parts.add('$updated updated');
    if (deleted > 0) parts.add('$deleted deleted');
    if (errors > 0) parts.add('$errors errors');
    if (parts.isEmpty) return 'No changes';
    return parts.join(', ');
  }

  String _formatHistoryTimestamp(String ts) {
    final dt = DateTime.tryParse(ts);
    if (dt == null) return ts;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalSync'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasProfile)
            ProfileCard(
              sourceCalendarName: _sourceCalendarName,
              targetCalendarName: _targetCalendarName,
              eventName: _eventName,
              intervalMinutes: _intervalMinutes,
              isEnabled: _syncEnabled,
              lastSyncText: _lastSyncText,
              onSync: _syncAll,
              onConfigure: _navigateToConfig,
            )
          else
            EmptyState(
              icon: Icons.calendar_month,
              title: 'No sync profiles yet',
              subtitle:
                  'Set up a profile to start syncing\nevents between calendars',
              action: FilledButton.icon(
                onPressed: _navigateToConfig,
                icon: const Icon(Icons.add),
                label: const Text('Create Profile'),
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
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _hasProfile ? _syncAll : null,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _hasProfile
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DryRunScreen(),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.preview),
                          label: const Text('Dry Run'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_recentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._recentHistory.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 8,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatHistoryCounts(entry),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                _formatHistoryTimestamp(
                                    entry['timestamp'] as String),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SyncStatusScreen(),
                            ),
                          );
                        },
                        child: const Text('View full history'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
