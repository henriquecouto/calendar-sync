import 'package:flutter/material.dart';
import 'mapping_database.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final _mappingDb = MappingDatabase();
  List<Map<String, Object?>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await _mappingDb.getStatusHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  String _formatCounts(Map<String, Object?> entry) {
    final synced = entry['synced'] as int;
    final deleted = entry['deleted'] as int;
    final updated = entry['updated'] as int;
    final skipped = entry['skipped'] as int;
    final errors = entry['errors'] as int;
    final parts = <String>[];
    if (synced > 0) parts.add('Synced: $synced');
    if (updated > 0) parts.add('Updated: $updated');
    if (deleted > 0) parts.add('Deleted: $deleted');
    if (skipped > 0) parts.add('Skipped: $skipped');
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
              ? const Center(
                  child: Text(
                    'No sync history yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        _formatCounts(entry),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _formatTimestamp(entry['timestamp'] as String),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
    );
  }
}
