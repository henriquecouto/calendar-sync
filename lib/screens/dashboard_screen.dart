import 'package:flutter/material.dart';

import '../settings/profile_service.dart';
import '../calendar/calendar_service.dart';
import '../sync/mapping_database.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_status_screen.dart';
import '../sync/dry_run_screen.dart';
import '../background/sync_scheduler.dart';
import '../widgets/empty_state.dart';
import 'profile_config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileService = ProfileService();
  final _calendarService = CalendarService();
  final _mappingDb = MappingDatabase();

  List<SyncProfile> _profiles = [];
  Map<String, String> _calendarNames = {};
  List<Map<String, Object?>> _recentHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _profileService.listProfiles();
    final calendars = await _calendarService.listCalendars();

    final calendarNames = <String, String>{};
    for (final cal in calendars) {
      calendarNames[cal.id] =
          cal.name.isNotEmpty ? cal.name : (cal.accountName ?? 'Unknown');
    }

    final history = await _mappingDb.getStatusHistory(limit: 3);

    setState(() {
      _profiles = profiles;
      _calendarNames = calendarNames;
      _recentHistory = history;
      _loading = false;
    });
  }

  String? _getCalendarName(String? calendarId) {
    if (calendarId == null) return null;
    if (_calendarNames.containsKey(calendarId)) return _calendarNames[calendarId];
    return null;
  }

  bool _calendarExists(String? calendarId) {
    if (calendarId == null) return false;
    return _calendarNames.containsKey(calendarId);
  }

  Future<void> _syncProfile(SyncProfile profile) async {
    if (!profile.enabled) return;
    final sourceId = profile.sourceCalendarId;
    final targetId = profile.targetCalendarId;
    final syncName = profile.eventName.trim();

    if (sourceId == null || targetId == null) return;

    if (!_calendarExists(sourceId) || !_calendarExists(targetId)) return;

    final engine = SyncEngine(_calendarService, _mappingDb);
    final result = await engine.runSync(
      profileId: profile.id,
      sourceCalendarId: sourceId,
      targetCalendarId: targetId,
      syncEventName: syncName,
    );


    await _mappingDb.insertStatus(
      profileId: profile.id,
      timestamp: DateTime.now().toIso8601String(),
      synced: result.synced.length,
      deleted: result.deleted.length,
      skipped: result.skipped.length,
      updated: result.updated.length,
      errors: result.errors.length,
    );

    _load();
  }

  Future<void> _syncAll() async {
    for (final profile in _profiles) {
      if (profile.enabled) {
        await _syncProfile(profile);
      }
    }
  }

  Future<void> _toggleEnabled(SyncProfile profile, bool enabled) async {
    await _profileService.updateProfile(profile.copyWith(enabled: enabled));
    await SyncScheduler.updatePeriodicTask();
    _load();
  }

  Future<void> _navigateToConfig({String? profileId}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileConfigScreen(profileId: profileId),
      ),
    );
    if (result == true) _load();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToConfig(),
        tooltip: 'Add profile',
        child: const Icon(Icons.add),
      ),
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
                          onPressed:
                              _profiles.isNotEmpty ? _syncAll : null,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _profiles.isNotEmpty
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
          const SizedBox(height: 16),
          if (_profiles.isEmpty)
            EmptyState(
              icon: Icons.calendar_month,
              title: 'No sync profiles yet',
              subtitle:
                  'Set up a profile to start syncing\nevents between calendars',
              action: FilledButton.icon(
                onPressed: () => _navigateToConfig(),
                icon: const Icon(Icons.add),
                label: const Text('Create Profile'),
              ),
            )
          else
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Profiles',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ..._profiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final profile = entry.value;
                    final sourceName = _getCalendarName(profile.sourceCalendarId);
                    final targetName = _getCalendarName(profile.targetCalendarId);
                    final hasMissing =
                        (profile.sourceCalendarId != null && sourceName == null) ||
                            (profile.targetCalendarId != null && targetName == null);
                    final hasPair = profile.sourceCalendarId != null && profile.targetCalendarId != null;
                    final isLast = index == _profiles.length - 1;

                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            profile.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: hasPair
                              ? Text('$sourceName → $targetName')
                              : Text(hasMissing ? 'Calendar not found' : 'Not configured',
                                  style: const TextStyle(color: Colors.orange)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasMissing)
                                const Icon(Icons.warning_amber_rounded,
                                    size: 20, color: Colors.orange),
                              if (profile.enabled)
                                IconButton(
                                  icon: Icon(Icons.sync,
                                      color: Theme.of(context).colorScheme.primary),
                                  tooltip: 'Sync now',
                                  onPressed: () => _syncProfile(profile),
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(36, 36),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              Switch(
                                value: profile.enabled,
                                onChanged: (val) => _toggleEnabled(profile, val),
                              ),
                            ],
                          ),
                          onTap: () => _navigateToConfig(profileId: profile.id),
                        ),
                        if (!isLast)
                          Divider(height: 1, indent: 16, endIndent: 16,
                              color: Theme.of(context).colorScheme.outlineVariant),
                      ],
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
