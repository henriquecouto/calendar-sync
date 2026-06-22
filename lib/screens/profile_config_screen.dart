import 'package:flutter/material.dart';

import '../settings/profile_service.dart';
import '../calendar/calendar_service.dart';
import '../background/sync_scheduler.dart';
import '../widgets/empty_state.dart';

class ProfileConfigScreen extends StatefulWidget {
  final String? profileId;

  const ProfileConfigScreen({super.key, this.profileId});

  @override
  State<ProfileConfigScreen> createState() => _ProfileConfigScreenState();
}

class _CalendarItem {
  final String id;
  final String name;

  const _CalendarItem(this.id, this.name);
}

class _ProfileConfigScreenState extends State<ProfileConfigScreen> {
  final _profileService = ProfileService();
  final _calendarService = CalendarService();
  final _nameController = TextEditingController();
  final _syncNameController = TextEditingController();

  String? _sourceCalendarId;
  String? _targetCalendarId;
  int _intervalMinutes = 60;
  bool _syncEnabled = true;
  String? _profileId;

  List<_CalendarItem> _calendars = [];
  bool _loading = true;
  bool _isCreateMode = true;
  String? _nameError;
  String? _pairingError;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId;
    _load();
  }

  bool get _isEditing => _profileId != null;

  Future<void> _load() async {
    final calendars = await _calendarService.listCalendars();

    if (_isEditing) {
      final profile = await _profileService.getProfile(_profileId!);
      if (profile != null) {
        _sourceCalendarId = profile.sourceCalendarId;
        _targetCalendarId = profile.targetCalendarId;
        _syncNameController.text = profile.eventName;
        _intervalMinutes = profile.intervalMinutes;
        _syncEnabled = profile.enabled;
        _nameController.text = profile.name;
      }
    }

    setState(() {
      _isCreateMode = !_isEditing;
      _calendars = calendars
          .map((c) => _CalendarItem(
                c.id,
                c.name.isNotEmpty ? c.name : (c.accountName ?? 'Unknown'),
              ))
          .toList();
      _loading = false;
    });
  }

  String? _validate() {
    final name = _nameController.text.trim();
    if (name.isEmpty && _sourceCalendarId != null && _targetCalendarId != null) {
      final srcName = _calendars
          .where((c) => c.id == _sourceCalendarId)
          .map((c) => c.name)
          .firstOrNull ??
          _sourceCalendarId;
      final tgtName = _calendars
          .where((c) => c.id == _targetCalendarId)
          .map((c) => c.name)
          .firstOrNull ??
          _targetCalendarId;
      _nameController.text = '$srcName → $tgtName';
      return null;
    }
    if (name.isEmpty) return 'Profile name is required';
    return null;
  }

  Future<String?> _validateAsync() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Profile name is required';

    final nameTaken = await _profileService.isNameTaken(
      name,
      excludeId: _profileId,
    );
    if (nameTaken) return 'A profile with this name already exists';

    if (_sourceCalendarId != null && _targetCalendarId != null) {
      final pairTaken = await _profileService.isSourceTargetPairTaken(
        _sourceCalendarId!,
        _targetCalendarId!,
        excludeId: _profileId,
      );
      if (pairTaken) return 'A profile with this source and target already exists';
    }

    return null;
  }

  Future<void> _save() async {
    final syncError = _validate();
    if (syncError != null) {
      setState(() => _nameError = syncError);
      return;
    }

    final asyncError = await _validateAsync();
    if (asyncError != null) {
      if (asyncError.contains('source and target')) {
        setState(() => _pairingError = asyncError);
      } else {
        setState(() => _nameError = asyncError);
      }
      return;
    }

    final eventName = _syncNameController.text.trim();

    if (_sourceCalendarId != null &&
        _targetCalendarId != null &&
        _sourceCalendarId == _targetCalendarId) {
      setState(() => _pairingError = 'Source and target calendars must be different');
      return;
    }

    if (_isEditing) {
      final existing = await _profileService.getProfile(_profileId!);
      if (existing != null) {
        await _profileService.updateProfile(existing.copyWith(
          name: _nameController.text.trim(),
          sourceCalendarId: _sourceCalendarId,
          targetCalendarId: _targetCalendarId,
          eventName: eventName,
          intervalMinutes: _intervalMinutes,
          enabled: _syncEnabled,
        ));
      }
    } else {
      await _profileService.createProfile(
        name: _nameController.text.trim(),
        sourceCalendarId: _sourceCalendarId,
        targetCalendarId: _targetCalendarId,
        eventName: eventName,
        intervalMinutes: _intervalMinutes,
        enabled: _syncEnabled,
      );
    }

    await SyncScheduler.updatePeriodicTask();

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (_profileId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile'),
        content: const Text(
          'This will delete the profile and all its sync history and mappings. Target events already created will remain in the calendar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _profileService.deleteProfile(_profileId!);
      await SyncScheduler.updatePeriodicTask();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _syncNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _isCreateMode ? null : true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Profile' : 'Create Profile'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Profile Name',
                              hintText: 'e.g. Work Sync',
                              border: const OutlineInputBorder(),
                              errorText: _nameError,
                            ),
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
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
                            'Calendar Pairing',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_calendars.isEmpty)
                            const EmptyState(
                              icon: Icons.calendar_month,
                              title: 'No calendars found',
                            )
                          else ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownMenu<String>(
                                  initialSelection: _sourceCalendarId,
                                  label: const Text('Source Calendar'),
                                  errorText: _pairingError,
                                  expandedInsets: EdgeInsets.zero,
                                  dropdownMenuEntries: _calendars.map((c) {
                                    return DropdownMenuEntry(
                                        value: c.id, label: c.name);
                                  }).toList(),
                                  onSelected: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _sourceCalendarId = val;
                                        _pairingError = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownMenu<String>(
                                  initialSelection: _targetCalendarId,
                                  label: const Text('Target Calendar'),
                                  errorText: _pairingError,
                                  expandedInsets: EdgeInsets.zero,
                                  dropdownMenuEntries: _calendars.map((c) {
                                    return DropdownMenuEntry(
                                        value: c.id, label: c.name);
                                  }).toList(),
                                  onSelected: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _targetCalendarId = val;
                                        _pairingError = null;
                                      });
                                    }
                                  },
                                ),
                              ],
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
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Leave empty to keep original event titles.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
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
                              DropdownMenuEntry(
                                  value: 15, label: '15 minutes'),
                              DropdownMenuEntry(
                                  value: 30, label: '30 minutes'),
                              DropdownMenuEntry(value: 60, label: '1 hour'),
                              DropdownMenuEntry(value: 120, label: '2 hours'),
                              DropdownMenuEntry(value: 360, label: '6 hours'),
                            ],
                            onSelected: (val) {
                              if (val != null) {
                                setState(() => _intervalMinutes = val);
                              }
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
                            onChanged: (val) {
                              setState(() => _syncEnabled = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text(_isEditing ? 'Save Changes' : 'Create Profile'),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
