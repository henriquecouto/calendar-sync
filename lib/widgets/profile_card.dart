import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final String? sourceCalendarName;
  final String? targetCalendarName;
  final String eventName;
  final int intervalMinutes;
  final bool isEnabled;
  final String? lastSyncText;
  final VoidCallback? onSync;
  final VoidCallback? onConfigure;

  const ProfileCard({
    super.key,
    this.sourceCalendarName,
    this.targetCalendarName,
    required this.eventName,
    required this.intervalMinutes,
    required this.isEnabled,
    this.lastSyncText,
    this.onSync,
    this.onConfigure,
  });

  String get _intervalLabel {
    if (intervalMinutes <= 0) return 'Manual only';
    if (intervalMinutes < 60) return 'Every ${intervalMinutes}m';
    if (intervalMinutes == 60) return 'Every 1h';
    return 'Every ${intervalMinutes ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile = sourceCalendarName != null && targetCalendarName != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEnabled ? 'Active' : 'Paused',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
                const Spacer(),
                if (onSync != null && isEnabled)
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
            if (hasProfile) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sourceCalendarName!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16, color: colorScheme.outline),
                  ),
                  Expanded(
                    child: Text(
                      targetCalendarName!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '"$eventName" · $_intervalLabel',
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Not configured',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
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
