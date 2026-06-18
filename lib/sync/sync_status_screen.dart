import 'package:flutter/material.dart';

import '../settings/profile_service.dart';
import '../widgets/empty_state.dart';
import 'mapping_database.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final _mappingDb = MappingDatabase();
  final _profileService = ProfileService();

  List<Map<String, Object?>> _history = [];
  List<SyncProfile> _profiles = [];
  String? _selectedProfileId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await _mappingDb.getStatusHistory(
      profileId: _selectedProfileId,
    );
    final profiles = await _profileService.listProfiles();
    setState(() {
      _history = history;
      _profiles = profiles;
      _loading = false;
    });
  }

  String _profileName(String? profileId) {
    if (profileId == null || profileId.isEmpty) return 'Unknown profile';
    final profile =
        _profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile != null) return profile.name;
    return 'Unknown profile';
  }

  String _formatCounts(Map<String, Object?> entry) {
    final synced = entry['synced'] as int;
    final deleted = entry['deleted'] as int;
    final updated = entry['updated'] as int;
    final skipped = entry['skipped'] as int;
    final errors = entry['errors'] as int;
    final parts = <String>[];
    if (synced > 0) parts.add('$synced synced');
    if (updated > 0) parts.add('$updated updated');
    if (deleted > 0) parts.add('$deleted deleted');
    if (skipped > 0) parts.add('$skipped skipped');
    if (errors > 0) parts.add('$errors errors');
    if (parts.isEmpty) return 'No changes';
    return parts.join(', ');
  }

  String _formatTimestamp(String ts) {
    final dt = DateTime.tryParse(ts);
    if (dt == null) return ts;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const EmptyState(
                  icon: Icons.schedule,
                  title: 'No sync history yet',
                  subtitle: 'Run your first sync to see\nresults here',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownMenu<String>(
                          initialSelection: _selectedProfileId,
                          label: const Text('Filter by profile'),
                          expandedInsets: EdgeInsets.zero,
                          dropdownMenuEntries: [
                            const DropdownMenuEntry<String>(
                              value: '',
                              label: 'All profiles',
                            ),
                            ..._profiles.map(
                              (p) => DropdownMenuEntry<String>(
                                value: p.id,
                                label: p.name,
                              ),
                            ),
                          ],
                          onSelected: (val) {
                            setState(() => _selectedProfileId = val == '' ? null : val);
                            _load();
                          },
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _history.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = _history[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                _formatCounts(entry),
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                '${_profileName(entry['profile_id'] as String?)} · ${_formatTimestamp(entry['timestamp'] as String)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
