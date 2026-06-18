import 'package:flutter/material.dart';

import '../calendar/calendar_service.dart';
import '../settings/profile_service.dart';
import '../widgets/sync_plan_card.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';
import 'mapping_database.dart';
import 'sync_engine.dart';

class DryRunScreen extends StatefulWidget {
  final String? profileId;

  const DryRunScreen({super.key, this.profileId});

  @override
  State<DryRunScreen> createState() => _DryRunScreenState();
}

class _DryRunScreenState extends State<DryRunScreen> {
  final _calendarService = CalendarService();
  final _mappingDb = MappingDatabase();
  final _profileService = ProfileService();

  List<SyncProfile> _profiles = [];
  String? _selectedProfileId;
  SyncPlan? _plan;
  bool _loading = false;
  String? _timestamp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.profileId;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _profileService.listProfiles();
    setState(() => _profiles = profiles);
  }

  Future<void> _runDryRun() async {
    if (_selectedProfileId == null) {
      setState(() => _error = 'Select a profile first.');
      return;
    }

    final profile = await _profileService.getProfile(_selectedProfileId!);
    if (profile == null) {
      setState(() => _error = 'Profile not found.');
      return;
    }

    final sourceId = profile.sourceCalendarId;
    final targetId = profile.targetCalendarId;
    final syncName = profile.eventName;

    if (sourceId == null || targetId == null) {
      setState(() {
        _loading = false;
        _error = 'Select both calendars in the profile settings first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
      _timestamp = null;
    });

    final engine = SyncEngine(_calendarService, _mappingDb);
    final plan = await engine.runDryRun(
      profileId: profile.id,
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
    final colorScheme = Theme.of(context).colorScheme;

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
      body: Column(
        children: [
          if (widget.profileId == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownMenu<String>(
                initialSelection: _selectedProfileId,
                label: const Text('Select profile'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: _profiles.map((p) {
                  return DropdownMenuEntry(value: p.id, label: p.name);
                }).toList(),
                onSelected: (val) {
                  setState(() => _selectedProfileId = val);
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        icon: Icons.info_outline,
                        title: _error!,
                      )
                    : _buildResults(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colorScheme) {
    if (_plan == null) {
      return const EmptyState(
        icon: Icons.preview,
        title: 'Tap the play button to run a dry run',
        subtitle:
            'This previews what a sync would do without\nmodifying any calendar data',
      );
    }

    final plan = _plan!;
    final total = plan.toCreate.length +
        plan.toUpdate.length +
        plan.toSkip.length +
        plan.toDelete.length;

    if (total == 0 && plan.errors.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No changes detected',
        subtitle: 'Everything is in sync',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_timestamp != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Ran at $_timestamp',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ),
        if (plan.errors.isNotEmpty) ...[
          SectionHeader(
            title: 'Errors',
            count: plan.errors.length,
            color: colorScheme.error,
          ),
          ...plan.errors.map((e) => SyncPlanCard(
                type: SyncPlanEntryType.error,
                title: e,
              )),
          const SizedBox(height: 16),
        ],
        if (plan.toCreate.isNotEmpty) ...[
          SectionHeader(
            title: 'Would Sync',
            count: plan.toCreate.length,
            color: colorScheme.primary,
          ),
          ...plan.toCreate.map((entry) {
            final source = entry.sourceEvent;
            final timeStr =
                '${_formatTimestamp(entry.projectedStart)} → ${_formatTimestamp(entry.projectedEnd)}';
            return SyncPlanCard(
              type: SyncPlanEntryType.create,
              title: source.title,
              subtitle: timeStr,
              detail: entry.projectedTitle,
              detailLabel: 'Target event',
            );
          }),
          const SizedBox(height: 16),
        ],
        if (plan.toUpdate.isNotEmpty) ...[
          SectionHeader(
            title: 'Would Update',
            count: plan.toUpdate.length,
            color: colorScheme.tertiary,
          ),
          ...plan.toUpdate.map((entry) {
            final source = entry.sourceEvent;
            final timeStr =
                '${_formatTimestamp(source.startDate)} → ${_formatTimestamp(source.endDate)}';
            return SyncPlanCard(
              type: SyncPlanEntryType.update,
              title: source.title,
              subtitle: timeStr,
              detail: 'Target event would be replaced',
            );
          }),
          const SizedBox(height: 16),
        ],
        if (plan.toSkip.isNotEmpty) ...[
          SectionHeader(
            title: 'Would Skip',
            count: plan.toSkip.length,
            color: colorScheme.outline,
          ),
          ...plan.toSkip.map((event) {
            final timeStr =
                '${_formatTimestamp(event.startDate)} → ${_formatTimestamp(event.endDate)}';
            return SyncPlanCard(
              type: SyncPlanEntryType.skip,
              title: event.title,
              subtitle: timeStr,
            );
          }),
          const SizedBox(height: 16),
        ],
        if (plan.toDelete.isNotEmpty) ...[
          SectionHeader(
            title: 'Would Delete',
            count: plan.toDelete.length,
            color: colorScheme.error,
          ),
          ...plan.toDelete.map((mapping) {
            final sourceEventId =
                mapping['source_event_id'] as String? ?? '?';
            return SyncPlanCard(
              type: SyncPlanEntryType.delete,
              title: 'Source event removed',
              subtitle: 'Source ID: $sourceEventId',
              detail: 'Target event would be deleted',
            );
          }),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
