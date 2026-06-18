import 'package:flutter/material.dart';

import '../settings/profile_service.dart';

class ProfileCard extends StatelessWidget {
  final SyncProfile profile;
  final String? sourceCalendarName;
  final String? targetCalendarName;
  final String? lastSyncText;
  final bool hasMissingCalendar;
  final VoidCallback? onSync;
  final VoidCallback? onConfigure;
  final ValueChanged<bool>? onToggleEnabled;

  const ProfileCard({
    super.key,
    required this.profile,
    this.sourceCalendarName,
    this.targetCalendarName,
    this.lastSyncText,
    this.hasMissingCalendar = false,
    this.onSync,
    this.onConfigure,
    this.onToggleEnabled,
  });

  String get _intervalLabel {
    final interval = profile.intervalMinutes;
    if (interval <= 0) return 'Manual only';
    if (interval < 60) return 'Every ${interval}m';
    if (interval == 60) return 'Every 1h';
    return 'Every ${interval ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile =
        profile.sourceCalendarId != null && profile.targetCalendarId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (hasMissingCalendar)
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: Colors.orange),
                const SizedBox(width: 4),
                Switch(
                  value: profile.enabled,
                  onChanged: onToggleEnabled,
                ),
                if (onSync != null && profile.enabled)
                  IconButton(
                    icon: Icon(Icons.sync, color: colorScheme.primary),
                    tooltip: 'Sync now',
                    onPressed: onSync,
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            if (hasProfile && sourceCalendarName != null && targetCalendarName != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sourceCalendarName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward,
                        size: 14, color: colorScheme.outline),
                  ),
                  Expanded(
                    child: Text(
                      targetCalendarName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.outline,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                hasMissingCalendar ? 'Calendar not found' : 'Not configured',
                style: TextStyle(
                  fontSize: 13,
                  color: hasMissingCalendar ? Colors.orange : colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '"${profile.eventName}" · $_intervalLabel',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            if (lastSyncText != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last sync · $lastSyncText',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onConfigure,
                icon: const Icon(Icons.settings, size: 18),
                label: Text(hasProfile ? 'Configure' : 'Set up profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
