import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

import '../calendar/calendar_service.dart';
import '../settings/settings_service.dart';
import 'mapping_database.dart';
import 'sync_engine.dart';

class DryRunScreen extends StatefulWidget {
  const DryRunScreen({super.key});

  @override
  State<DryRunScreen> createState() => _DryRunScreenState();
}

class _DryRunScreenState extends State<DryRunScreen> {
  final _settings = SettingsService();
  final _calendarService = CalendarService();
  final _mappingDb = MappingDatabase();

  SyncPlan? _plan;
  bool _loading = false;
  String? _timestamp;
  String? _error;

  Future<void> _runDryRun() async {
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
      _timestamp = null;
    });

    final sourceId = await _settings.sourceCalendarId;
    final targetId = await _settings.targetCalendarId;
    final syncName = await _settings.syncEventName;

    if (sourceId == null || targetId == null) {
      setState(() {
        _loading = false;
        _error = 'Select both calendars on the home page first.';
      });
      return;
    }

    final engine = SyncEngine(_calendarService, _mappingDb);
    final plan = await engine.runDryRun(
      sourceCalendarId: sourceId,
      targetCalendarId: targetId,
      syncEventName: syncName,
    );

    setState(() {
      _plan = plan;
      _loading = false;
      _timestamp = _formatTimestamp(DateTime.now());
    });
  }

  String _formatTimestamp(DateTime dt) {
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
        title: const Text('Dry Run'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run Dry Run',
            onPressed: _loading ? null : _runDryRun,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildEmpty(_error!)
              : _buildResults(),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_plan == null) {
      return _buildEmpty('Tap the play button to run a dry run.\n\n'
          'This previews what a sync would do without\n'
          'modifying any calendar data.');
    }

    final plan = _plan!;
    final total = plan.toCreate.length +
        plan.toUpdate.length +
        plan.toSkip.length +
        plan.toDelete.length;

    if (total == 0 && plan.errors.isEmpty) {
      return _buildEmpty('No changes detected. Everything is in sync.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_timestamp != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Ran at $_timestamp',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        if (plan.errors.isNotEmpty) ...[
          _SectionHeader(
            title: 'Errors',
            count: plan.errors.length,
            color: Colors.red,
          ),
          ...plan.errors.map((e) => _ErrorTile(error: e)),
          const SizedBox(height: 16),
        ],
        if (plan.toCreate.isNotEmpty) ...[
          _SectionHeader(
            title: 'Would Sync',
            count: plan.toCreate.length,
            color: Colors.green,
          ),
          ...plan.toCreate.map((entry) => _CreateTile(entry: entry)),
          const SizedBox(height: 16),
        ],
        if (plan.toUpdate.isNotEmpty) ...[
          _SectionHeader(
            title: 'Would Update',
            count: plan.toUpdate.length,
            color: Colors.orange,
          ),
          ...plan.toUpdate.map((entry) => _UpdateTile(entry: entry)),
          const SizedBox(height: 16),
        ],
        if (plan.toSkip.isNotEmpty) ...[
          _SectionHeader(
            title: 'Would Skip',
            count: plan.toSkip.length,
            color: Colors.grey,
          ),
          ...plan.toSkip.map((event) => _SkipTile(event: event)),
          const SizedBox(height: 16),
        ],
        if (plan.toDelete.isNotEmpty) ...[
          _SectionHeader(
            title: 'Would Delete',
            count: plan.toDelete.length,
            color: Colors.red,
          ),
          ...plan.toDelete.map((entry) => _DeleteTile(mapping: entry)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final ToCreateEntry entry;

  const _CreateTile({required this.entry});

  String _formatTime(TZDateTime tzDt) {
    final h = tzDt.hour.toString().padLeft(2, '0');
    final m = tzDt.minute.toString().padLeft(2, '0');
    final d = tzDt.day.toString().padLeft(2, '0');
    final mo = tzDt.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final source = entry.sourceEvent;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.title ?? '(no title)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(entry.projectedStart)} → ${_formatTime(entry.projectedEnd)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(),
            Text(
              'Target event: "${entry.projectedTitle}"',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (entry.projectedDescription.isNotEmpty)
              Text(
                'Description: ${entry.projectedDescription}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final ToUpdateEntry entry;

  const _UpdateTile({required this.entry});

  String _formatTime(TZDateTime? tzDt) {
    if (tzDt == null) return '?';
    final h = tzDt.hour.toString().padLeft(2, '0');
    final m = tzDt.minute.toString().padLeft(2, '0');
    final d = tzDt.day.toString().padLeft(2, '0');
    final mo = tzDt.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final source = entry.sourceEvent;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.title ?? '(no title)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(source.start)} → ${_formatTime(source.end)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(),
            const Text(
              'Target event would be replaced',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipTile extends StatelessWidget {
  final Event event;

  const _SkipTile({required this.event});

  String _formatTime(TZDateTime? tzDt) {
    if (tzDt == null) return '?';
    final h = tzDt.hour.toString().padLeft(2, '0');
    final m = tzDt.minute.toString().padLeft(2, '0');
    final d = tzDt.day.toString().padLeft(2, '0');
    final mo = tzDt.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title ?? '(no title)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(event.start)} → ${_formatTime(event.end)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteTile extends StatelessWidget {
  final Map<String, Object?> mapping;

  const _DeleteTile({required this.mapping});

  @override
  Widget build(BuildContext context) {
    final sourceEventId = mapping['source_event_id'] as String? ?? '?';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Source event removed',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Source ID: $sourceEventId',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(),
            const Text(
              'Target event would be deleted',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String error;

  const _ErrorTile({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          error,
          style: const TextStyle(fontSize: 13, color: Colors.red),
        ),
      ),
    );
  }
}
