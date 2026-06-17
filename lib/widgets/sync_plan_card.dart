import 'package:flutter/material.dart';

enum SyncPlanEntryType { create, update, skip, delete, error }

class SyncPlanCard extends StatelessWidget {
  final SyncPlanEntryType type;
  final String title;
  final String? subtitle;
  final String? detail;
  final String? detailLabel;

  const SyncPlanCard({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.detail,
    this.detailLabel,
  });

  IconData get _icon {
    switch (type) {
      case SyncPlanEntryType.create:
        return Icons.add_circle_outline;
      case SyncPlanEntryType.update:
        return Icons.edit_outlined;
      case SyncPlanEntryType.skip:
        return Icons.check_circle_outline;
      case SyncPlanEntryType.delete:
        return Icons.delete_outline;
      case SyncPlanEntryType.error:
        return Icons.error_outline;
    }
  }

  Color _color(ColorScheme colorScheme) {
    switch (type) {
      case SyncPlanEntryType.create:
        return colorScheme.primary;
      case SyncPlanEntryType.update:
        return colorScheme.tertiary;
      case SyncPlanEntryType.skip:
        return colorScheme.outline;
      case SyncPlanEntryType.delete:
        return colorScheme.error;
      case SyncPlanEntryType.error:
        return colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _color(colorScheme);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
            ],
            if (detail != null) ...[
              const Divider(),
              Text(
                '${detailLabel ?? ""}${detailLabel != null ? ": " : ""}"$detail"',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: detailLabel == null ? FontWeight.w500 : null,
                  fontStyle: detailLabel != null ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
