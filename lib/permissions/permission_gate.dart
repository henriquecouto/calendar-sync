import 'package:flutter/material.dart';
import 'permission_service.dart';

class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  final _service = PermissionService();
  bool _loading = true;
  bool _granted = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await _service.areCalendarPermissionsGranted;
      final permDenied =
          await _service.areCalendarPermissionsPermanentlyDenied;
      setState(() {
        _granted = granted;
        _permanentlyDenied = permDenied;
        _loading = false;
      });
      if (granted) {
        _requestNotificationIfNeeded();
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await _service.requestCalendarPermissions();
      if (granted) {
        setState(() {
          _granted = true;
          _permanentlyDenied = false;
        });
        _requestNotificationIfNeeded();
      } else {
        final permDenied =
            await _service.areCalendarPermissionsPermanentlyDenied;
        setState(() => _permanentlyDenied = permDenied);
      }
    } catch (_) {
      setState(() => _granted = false);
    }
  }

  Future<void> _requestNotificationIfNeeded() async {
    try {
      final alreadyGranted = await _service.areNotificationPermissionsGranted;
      if (!alreadyGranted) {
        await _service.requestNotificationPermission();
      }
    } catch (_) {}
  }

  Future<void> _openSettings() async {
    await _service.openAppSettings();
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_granted) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, size: 64, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Calendar permissions are required to sync events.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              if (_permanentlyDenied)
                Column(
                  children: [
                    Text(
                      'Permissions are permanently denied. '
                      'Please enable them in system Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _openSettings,
                      child: const Text('Open Settings'),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: _requestPermissions,
                  child: const Text('Grant Permissions'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
