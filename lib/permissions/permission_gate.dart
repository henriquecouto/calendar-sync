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
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await _service.areCalendarPermissionsGranted;
    final permDenied =
        await _service.areCalendarPermissionsPermanentlyDenied;
    setState(() {
      _granted = granted;
      _permanentlyDenied = permDenied;
      _loading = false;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await _service.requestCalendarPermissions();
    if (granted) {
      setState(() {
        _granted = true;
        _permanentlyDenied = false;
      });
    } else {
      final permDenied =
          await _service.areCalendarPermissionsPermanentlyDenied;
      setState(() => _permanentlyDenied = permDenied);
    }
  }

  Future<void> _openSettings() async {
    await _service.openAppSettings();
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_granted) {
      return widget.child;
    }

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Calendar permissions are required to sync events.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (_permanentlyDenied)
                  Column(
                    children: [
                      const Text(
                        'Permissions are permanently denied. '
                        'Please enable them in system Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
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
      ),
    );
  }
}
